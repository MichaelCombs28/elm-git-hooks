# Elm Git Hooks

## Installation

```sh
npm install @talentry/elm-git-hooks
```

## Usage

```sh
elm-git-hooks <sub command>
```

This script is meant to be used with [Husky](https://typicode.github.io/husky/#/)

### prepare-message

Pre-append a commit message based on a provided regex string matching against git branch name.
It will match against the first group found in the string. If a match isn't found, a message is not
generated.

Any commit with a commit source eg. merging branches will also be omitted.

```sh
elm-git-hooks prepare-message 'JIRA-[0-9]{4}' commit-message-file commit-source?
```

**With Husky**

In `.husky/prepare-commit-msg` append the following line

```sh
elm-git-hooks prepare-message 'JIRA-[0-9]{4}' $1 $2
```

## Examples

This repository uses husky, you can see example usage here. Talentry uses [ClickUp](https://clickup.com/), so
out tickets IDs look like `CU-ASDF`

## LICENSE

MIT
