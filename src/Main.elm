port module Main exposing (main)

import Cli.Option as Option
import Cli.OptionsParser as OptionsParser exposing (with, withDoc, withOptionalPositionalArg)
import Cli.Program as Program
import Json.Decode as JD
import Json.Encode as JE
import Regex exposing (Regex)



-- PORTS


port print : String -> Cmd msg


port printAndExitFailure : String -> Cmd msg


port printAndExitSuccess : String -> Cmd msg


port onStdinLine : (String -> msg) -> Sub msg


port onStdinClosed : (() -> msg) -> Sub msg


port os : OSCommand -> Cmd msg


port osResult : (OSResult -> msg) -> Sub msg


type alias OSCommand =
    { commandType : String
    , args : JE.Value
    }


type alias OSResult =
    { commandType : String
    , args : JE.Value
    }


type alias ReadResult =
    { filename : String
    , text : String
    }



-- MODEL


type alias Flags =
    Program.FlagsIncludingArgv RevFlag


type alias Model =
    Maybe String


type alias CliOptions =
    { regex : String
    , commitMsgFile : String
    , commitSource : Maybe String
    }


type alias RevFlag =
    { rev : String
    }



-- Args


program : Program.Config CliOptions
program =
    Program.config
        |> Program.add
            (OptionsParser.build CliOptions
                |> with (Option.requiredPositionalArg "ticket-regex")
                |> with (Option.requiredPositionalArg "commit-message-file")
                |> withOptionalPositionalArg (Option.optionalPositionalArg "commit-source?")
                |> withDoc "Preappend commit message with a ticket ID."
            )



-- UPDATE


type Msg
    = FromOS OSResult


update : CliOptions -> Msg -> Model -> ( Model, Cmd Msg )
update cliOptions msg model =
    case msg of
        FromOS res ->
            case res.commandType of
                "readFile" ->
                    let
                        result =
                            JD.decodeValue
                                (JD.map2 ReadResult
                                    (JD.field "filename" JD.string)
                                    (JD.field "text" JD.string)
                                )
                                res.args
                    in
                    case result of
                        Ok { filename, text } ->
                            case model of
                                Just ticketId ->
                                    ( model, writeFile ticketId filename text )

                                Nothing ->
                                    ( model, printAndExitFailure (errorString "No Ticket ID") )

                        Err e ->
                            ( model, printAndExitFailure (errorString "Internal script error") )

                "writeFile" ->
                    ( model, printAndExitSuccess "" )

                _ ->
                    ( model, printAndExitFailure (errorString "Unhandled OS result") )


init : Flags -> CliOptions -> ( Model, Cmd Msg )
init { rev } { regex, commitMsgFile, commitSource } =
    case commitSource of
        Just _ ->
            ( Nothing, print "Commit Source present, omitting" )

        Nothing ->
            "^.*("
                ++ regex
                ++ "+).*"
                |> Regex.fromString
                |> Maybe.map (findAndWrite commitMsgFile rev)
                |> Maybe.withDefault ( Nothing, printAndExitFailure (errorString "Invalid regex.") )


findAndWrite : String -> String -> Regex -> ( Model, Cmd Msg )
findAndWrite commitMsgFile rev regex =
    case Regex.findAtMost 1 regex rev of
        [] ->
            ( Nothing, print "Branch name did not match regex, omitting." )

        match :: _ ->
            List.head match.submatches
                |> Maybe.andThen identity
                |> Maybe.map (\t -> ( Just t, readFile commitMsgFile ))
                |> Maybe.withDefault ( Nothing, printAndExitSuccess "Branch name did not match regex, omitting." )


readFile : String -> Cmd Msg
readFile filename =
    os
        { commandType = "readFile"
        , args =
            JE.object
                [ ( "filename", JE.string filename ) ]
        }


writeFile : String -> String -> String -> Cmd Msg
writeFile ticketId filename text =
    os
        { commandType = "writeFile"
        , args =
            JE.object
                [ ( "filename", JE.string filename )
                , ( "text", JE.string <| ticketId ++ ":" ++ text )
                ]
        }


errorString : String -> String
errorString message =
    "\u{001B}[31m" ++ message ++ "\u{001B}[0m"


successString : String -> String
successString message =
    "\u{001B}[32m" ++ message ++ "\u{001B}[0m"


main : Program.StatefulProgram Model Msg CliOptions RevFlag
main =
    Program.stateful
        { printAndExitFailure = printAndExitFailure
        , printAndExitSuccess = printAndExitSuccess
        , init = init
        , config = program
        , update = update
        , subscriptions = \_ -> osResult FromOS
        }
