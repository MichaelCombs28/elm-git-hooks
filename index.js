const fs = require("fs");
const { Elm } = require("./src/Main.elm");
const { exec } = require("child_process");

exec("git rev-parse --abbrev-ref HEAD", (error, stdout) => {
  const rev = error ? "" : stdout;
  const program = Elm.Main.init({
    flags: {
      argv: process.argv,
      versionMessage: "1.2.3",
      rev,
    },
  });

  program.ports.print?.subscribe((message) => {
    console.log(message);
  });

  program.ports.printAndExitFailure.subscribe((message) => {
    console.error(message);
    process.exit(1);
  });

  program.ports.printAndExitSuccess.subscribe((message) => {
    console.log(message);
    process.exit(0);
  });

  program.ports.os?.subscribe(({ commandType, args }) => {
    switch (commandType) {
      case "readFile":
        program.ports.osResult.send({
          commandType: "readFile",
          args: {
            text: fs.readFileSync(args.filename).toString(),
            filename: args.filename,
          },
        });
        break;
      case "writeFile":
        fs.writeFileSync(args.filename, args.text);
        program.ports.osResult.send({
          commandType: "writeFile",
          args: {},
        });
        break;
    }
  });
});
