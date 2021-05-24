port module Main exposing (main)

import Cli.Option as Option
import Cli.OptionsParser as OptionsParser exposing (OptionsParser, with, withDoc, withOptionalPositionalArg)
import Cli.OptionsParser.BuilderState as BuilderState
import Cli.Program as Program
import Json.Decode as JD
import Json.Encode as JE
import Regex exposing (Regex)



-- PORTS


port toJS : ElmMessage -> Cmd msg


port fromJS : (JSMessage -> msg) -> Sub msg


type alias ElmMessage =
    { commandType : String
    , args : JE.Value
    }


type alias JSMessage =
    { commandType : String
    , args : JE.Value
    }


printAndExitFailure : String -> Cmd msg
printAndExitFailure message =
    toJS
        { commandType = "exitFailure"
        , args = JE.object [ ( "message", JE.string <| errorString message ) ]
        }


printAndExitSuccess : String -> Cmd msg
printAndExitSuccess message =
    toJS
        { commandType = "exitSuccess"
        , args = JE.object [ ( "message", JE.string <| successString message ) ]
        }


print : String -> Cmd msg
print message =
    toJS
        { commandType = "print"
        , args = JE.object [ ( "message", JE.string <| successString message ) ]
        }


readFile : String -> Cmd Msg
readFile filename =
    toJS
        { commandType = "readFile"
        , args =
            JE.object
                [ ( "filename", JE.string filename ) ]
        }


writeFile : String -> String -> String -> Cmd Msg
writeFile ticketId filename text =
    toJS
        { commandType = "writeFile"
        , args =
            JE.object
                [ ( "filename", JE.string filename )
                , ( "text", JE.string <| ticketId ++ ":" ++ text )
                ]
        }



-- MODEL


type alias Flags =
    Program.FlagsIncludingArgv RevFlag


type Model
    = Prep (Maybe String)


type alias PrepareOptions =
    { regex : String
    , commitMsgFile : String
    , commitSource : Maybe String
    }


type CliOptions
    = Prepare PrepareOptions


type alias RevFlag =
    { rev : String
    }



-- Args


program : Program.Config CliOptions
program =
    Program.config
        |> Program.add (OptionsParser.map Prepare prepareOptionsParser)


prepareOptionsParser : OptionsParser PrepareOptions BuilderState.NoBeginningOptions
prepareOptionsParser =
    OptionsParser.buildSubCommand "prepare-message" PrepareOptions
        |> with (Option.requiredPositionalArg "ticket-regex")
        |> with (Option.requiredPositionalArg "commit-message-file")
        |> withOptionalPositionalArg (Option.optionalPositionalArg "commit-source?")
        |> withDoc "Preappend commit message with a ticket ID."



-- UPDATE


type Msg
    = FromJS JSMessage


update : CliOptions -> Msg -> Model -> ( Model, Cmd Msg )
update cliOptions msg model =
    case msg of
        FromJS res ->
            case res.commandType of
                "readFile" ->
                    case model of
                        Prep ticket ->
                            ticket
                                |> Maybe.map
                                    (\ticketId ->
                                        JD.decodeValue
                                            (JD.map2 (writeFile ticketId)
                                                (JD.field "filename" JD.string)
                                                (JD.field "text" JD.string)
                                            )
                                            res.args
                                            |> Result.map (Tuple.pair model)
                                            |> Result.withDefault
                                                ( model
                                                , printAndExitFailure "Invalid value received from JS."
                                                )
                                    )
                                |> Maybe.withDefault
                                    ( model
                                    , printAndExitFailure "Internal script error, no ticket ID"
                                    )

                "writeFile" ->
                    ( model, printAndExitSuccess "" )

                _ ->
                    ( model
                    , "Unhandled message from JS"
                        ++ res.commandType
                        |> printAndExitFailure
                    )


init : Flags -> CliOptions -> ( Model, Cmd Msg )
init { rev } opts =
    case opts of
        Prepare { regex, commitMsgFile, commitSource } ->
            case commitSource of
                Just _ ->
                    ( Prep Nothing, print "Commit Source present, omitting" )

                Nothing ->
                    "^.*("
                        ++ regex
                        ++ ").*"
                        |> Regex.fromString
                        |> Maybe.map (prepareCommitMsg commitMsgFile rev)
                        |> Maybe.withDefault ( Prep Nothing, printAndExitFailure "Invalid regex." )


prepareCommitMsg : String -> String -> Regex -> ( Model, Cmd Msg )
prepareCommitMsg commitMsgFile rev regex =
    case Regex.findAtMost 1 regex rev of
        [] ->
            ( Prep Nothing, print "Branch name did not match regex, omitting." )

        match :: _ ->
            List.head match.submatches
                |> Maybe.andThen identity
                |> Maybe.map (\t -> ( Prep <| Just t, readFile commitMsgFile ))
                |> Maybe.withDefault ( Prep Nothing, printAndExitSuccess "Branch name did not match regex, omitting." )


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
        , subscriptions = \_ -> fromJS FromJS
        }
