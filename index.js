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

  program.ports.toJS.subscribe(({ commandType, args }) => {
    switch (commandType) {
      case "readFile": {
        const { filename } = args;
        program.ports.fromJS.send({
          commandType: "readFile",
          args: {
            text: fs.readFileSync(filename).toString(),
            filename: filename,
          },
        });
        return;
      }
      case "writeFile": {
        const { filename, text } = args;
        fs.writeFileSync(filename, text);
        program.ports.fromJS.send({
          commandType: "writeFile",
          args: {},
        });
        return;
      }
      case "exitFailure": {
        const { message } = args;
        console.error(message);
        process.exit(1);
      }
      case "exitSuccess": {
        const { message } = args;
        console.log(message);
        process.exit(0);
      }
      case "print": {
        const { message } = args;
        console.log(message);
        return;
      }
    }
  });
});
