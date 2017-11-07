#!/bin/bash

# git-release.sh
# Simple utility to create release based on git and git-flow.
#
# - generate version number based on Semantic Versioning (MAJOR.MINOR.PATCH, eg. 1.0.0)
# - list versions
# - list issues for release (based on name convetion on branches and headline commit message)

function _help () {
    echo "

    Usage examples:

        user@host ~ $ git-release.sh prepare # updates branches 'master' and 'develop' (with 'git pull')
        ...
        user@host ~ $ git-release.sh version # show the current version (last released) if exists
        user@host ~ $ git-release.sh create # create next release based on current version. When no current version, uses 0.0.0
        ...
        user@host ~ $ git-release.sh version # show the current version (last released) if exists
        0.0.0
        user@host ~ $ git-release.sh previous # show the last version (one before the last released) if exists
        user@host ~ $ git-release.sh next # calculates (no paramater change 'minor') and show the next release number
        0.1.0
        user@host ~ $ git-release.sh next minor# calculates (explicit 'minor') and show the next release number
        0.1.0
        user@host ~ $ git-release.sh next major # calculates ('major') and show the next release number
        1.0.0
        user@host ~ $ git-release.sh next patch # calculates ('patch') and show the next release number
        0.0.1
        user@host ~ $ git-release.sh version 5 # show the 5 versions last released versions if exist
        0.0.0
        user@host ~ $ git-release.sh create major # create next major release based on current version
        ...
        user@host ~ $ git-release.sh version # show the current version (last released) if exists
        1.0.0
        user@host ~ $ git-release.sh previous # show the last version (one before the last released) if exists
        0.0.0
        user@host ~ $ git-release.sh create # create next minor (implicit) release based on current version
        ...
        user@host ~ $ git-release.sh version # show the current version (last released) if exists
        1.1.0
        user@host ~ $ git-release.sh create minor # create next minor (explicit) release based on current version
        ...
        user@host ~ $ git-release.sh version # show the current version (last released) if exists
        1.2.0
        user@host ~ $ git-release.sh create patch # create next patch release based on current version
        ...
        user@host ~ $ git-release.sh version # show the current version (last released) if exists
        1.2.1
        user@host ~ $ git-release.sh version 5 # show the 5 versions last released versions if exist
        0.0.0
        1.0.0
        1.1.0
        1.2.0
        1.2.1
        user@host ~ $ git-release.sh prepare # updates branches 'master' and 'develop' (with 'git pull')
        ...
        user@host ~ $ git-release.sh send # push change on master and develop to origin remote
        ...


        user@host ~ $ git-release.sh deploy patch # shortcut to run 'prepare', then 'issues', then 'create patch'
        ...
        user@host ~ $ git-release.sh deploy --send # shortcut to run 'prepare', then 'issues', then 'create minor', then 'send'
        ...
        user@host ~ $ git-release.sh deploy major --send # shortcut to run 'prepare', then 'issues', then 'create major', then 'send'
        ...

    Syntax:

        git-release.sh <command>

    Commands:
      help: show this message.

      prepare: update branch develop and master.

      version [amount]: show released versions.
              amount (defaults to 1): the number of previous version to show.

      previous : show previous release version.

      next [kind]: generate next release version. It result depends on the kind.
          kind: the kind of release. As in Semantic Version (major.minor.patch) it may be.
              major: version when they make incompatible API changes.
              minor (default): version when they add functionality in a backwards-compatible manner.
              patch: version when they make backwards-compatible bug fixes.

      create [kind|version]: create the new release depending on kind or version.
          kind|version: are the same as those for 'next' command. When using 'version' instead, it's accepts any string, but if it is something
              different from Semant Versioning scheme, the other commands will not work properly. If no option is passed it uses 'kind'
              with its default value.

      issues [point_a] [point_b]: list the issues that the commits are supposed to solve. It depends on branch's names, commit's headline messages,
              and good practices/conventions. For now it's hardcoded to find string started with 'tkt[-_]?[0-9]+', but it will configurable. It uses
              two points to determine a range to find the issues, the order doens't matter. Those points can be a commit's hash, branch, or tag.
          point_a (defaults to branch 'develop'): point of the search range.
          point_b (defaults to the output of 'version' command): point of the search range.

      deploy [kind|version] [--send]: executes 'prepare', then 'issues', then 'create [kind|version]' and optionally 'send' after all.
          kind|version: options are the same as those for 'create'. Actually, it'll simple bypass for 'create' command.
          --send: use this flag to execute 'send' command after all to push thing to remote.

      send: push branches develop and master and git tags to remote repository. Not yet configurable, the remote is 'origin'.

      revert: revert the fresh release. Only work with the release was not send to remote.
        WARNING: if changes made on the local repository was not pushed to the remote BEFORE the release creation, those change will be lost.


    Others:

        - Run inside your repository
        - It depends on git flow initiated on local repository (git flow init)
        - Becareful with '--send'
        - Becareful with 'revert'"
}


function version () {
  AMOUNT=${1:-1}
  git log | less | grep -Eo "tag\: [0-9]+\.[0-9]+(\.[0-9]+)?" | head -n "$AMOUNT" | grep -Eo "[0-9]+\.[0-9]+(\.[0-9]+)?"
}

function previous () {
  BACKWARD=${1:-1}
  let BACKWARD="$BACKWARD"+1
  echo `version "$BACKWARD" | tail -n 1`
}

function next () {
  # Generate next release version number
  VERSION=`version`
  KIND=${1:-minor}
  if [ -z "$VERSION"  ]; then
    echo 0.0.0
    return 0
  fi

  # major, minor, patch
  IFS='.' read -r -a splitVersion <<< "$VERSION"
  version_length=${#splitVersion[@]} # array length

  if [ "$KIND" == "patch" ]; then
    if [ "$version_length" == 3 ]; then
      new_version="${splitVersion[0]}""."
      new_version="$new_version""${splitVersion[1]}""."
      v=${splitVersion[2]}
      let v="$v"+1
      new_version="$new_version""$v"
    else
      new_version="${splitVersion[0]}""."
      new_version="$new_version""${splitVersion[1]}""."
      new_version="$new_version""1"
    fi
  elif [ "$KIND" == "minor" ]; then
    new_version="${splitVersion[0]}""."
    v="${splitVersion[1]}"
    let v="$v"+1
    new_version="$new_version""$v""."
    new_version="$new_version""0"
  elif [ "$KIND" == "major" ]; then
    v="${splitVersion[0]}"
    let v="$v"+1
    new_version="$v""."
    new_version="$new_version""0""."
    new_version="$new_version""0"
  fi

  echo $new_version
}

function issues () {
  TAG=`version`
  POINT_A=${1:-develop}
  POINT_B=${2:-$TAG}

  if [ "$POINT_A" == "previous" ]; then
    BACKWARD=${2:-0}
    POINT_A=`previous "$BACKWARD"`
    let BACKWARD="$BACKWARD"+1
    POINT_B=`previous "$BACKWARD"`
  fi
  echo $POINT_A/$POINT_B
  echo

  git log "$POINT_B".."$POINT_A" --format=oneline | grep -Eio "tkt[-_]?[0-9]+" | tr '[:upper:]' '[:lower:]' | sort | uniq
}

function prepare () {
  MASTER=master
  DEVELOP=develop
  REMOTE=origin

  git checkout "$MASTER" && git pull "$REMOTE" "$MASTER"
  git checkout "$DEVELOP" && git pull "$REMOTE" "$DEVELOP"
  git pull "$REMOTE" --tags
}

function create () {
  VERSION=${1:-minor}

  if [ "$VERSION" == "patch" ] || [ "$VERSION" == "minor" ] || [ "$VERSION" == "major" ]; then
    VERSION=`next "$1"`
  fi

  echo "Create release version:" "$VERSION"
  git flow release start "$VERSION"
  git flow release finish "$VERSION"
}

function revert () {
  MASTER=master
  DEVELOP=develop
  REMOTE=origin
  VERSION=`version`

  git checkout "$DEVELOP" && git reset --hard origin/HEAD
  git checkout "$MASTER" && git reset --hard origin/HEAD
  git branch -D "release/$VERSION"
  git tag -d "$VERSION"
  prepare
}

function send () {
  MASTER=master
  DEVELOP=develop
  REMOTE=origin

  git checkout "$DEVELOP" && git pull "$REMOTE" "$DEVELOP" && git push "$REMOTE" "$DEVELOP"
  git checkout "$MASTER" && git pull "$REMOTE" "$MASTER" && git push "$REMOTE" "$MASTER" && git push "$REMOTE" --tags
  git checkout "$DEVELOP"
}

function deploy() {
  prepare
  issues
  VERSION=${1:-minor}
  SEND=$2
  if [ "$1" == "--send" ]; then
      VERSION="minor"
      SEND="--send"
  fi
  create "$VERSION"
  if [ "$SEND" == "--send" ]; then
      send
  fi
}

# Execute command + parameters
COMMAND=${1:-help}
if [ "$COMMAND" == "help" ]; then
  COMMAND="_help"
fi

$COMMAND $2 $3
