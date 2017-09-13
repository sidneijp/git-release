#!/bin/bash

# git-release.sh
# Simple utility to create release based on git and git-flow.
#
# - generate version number based on Semantic Versioning (MAJOR.MINOR.PATCH, eg. 1.0.0)
# - list versions
# - list issues for release (based on name convetion on branches and headline commit message)

function _help () {
    echo "git-release.sh <command>"
    echo ""

    echo "Commands:"
    echo "  help: show this message."
    echo ""

    echo "  prepare: show this message."
    echo ""

    echo "  version: show actual release version."
    echo ""

    echo "  previous [amount]: show previous releases version."
    echo "          amount (defaults to:1): the number of previous version to show."
    echo ""

    echo "  next [kind]: generate next release version. It result depends on the kind."
    echo "      kind: the kind of release. As in Semantic Version (major.minor.patch) it may be."
    echo "          major: version when they make incompatible API changes. "
    echo "          minor (default): version when they add functionality in a backwards-compatible manner."
    echo "          patch: version when they make backwards-compatible bug fixes."
    echo ""

    echo "  create [kind|version]: create the new release depending on kind or version. Options for 'kind' are"
    echo "          the as fot 'next' command. When using 'version' instead, it's accepts any string, but if it is something"
    echo "          different from Semant Versioning scheme, the other commands will not work properly. If no option is passed"
    echo "          it uses 'kind' with its default value."
    echo ""

    echo "  issues [point_a] [point_b]: list the issues that the commits are supposed to solve. It depends on branch's names, commit's headline messages,"
    echo "          and good practices/conventions. For now it's hardcoded to find string started with 'tkt[^: -')]+', but it will configurable. It uses"
    echo "          two points to determine a range to find the issues, the order doens't matter. Those points can be a commit's hash, branch, or tag. "
    echo "      point_a (defaults to branch 'develop'): point of the search range."
    echo "      point_b (defaults to the output of 'version' command): point of the search range."
    echo ""

    echo "  send: push branches develop and master and git tags to remote repository. Not yet configurable, the remote is 'origin'."
    echo ""
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
  	echo "$POINT_B""/""$POINT_A"
  	echo
  fi

  git log $POINT_B..$POINT_A --format=oneline | grep -Eio "tkt[^: -')]+" | tr '[:upper:]' '[:lower:]' | sort | uniq
}

function version () {
	AMOUNT=${1:-1}
	git log | less | grep -Eo "tag\: [0-9]+\.[0-9]+(\.[0-9]+)?" | head -n $AMOUNT | grep -Eo "[0-9]+\.[0-9]+(\.[0-9]+)?"
}

function prepare () {
	MASTER=master
	DEVELOP=develop
	REMOTE=origin

	# Atualiza branches
	git checkout $MASTER && git pull $REMOTE $MASTER
	git checkout $DEVELOP && git pull $REMOTE $DEVELOP
}

function create () {
	VERSION=${1:-minor}

	if [ "$VERSION" == "patch" ] || [ "$VERSION" == "minor" ] || [ "$VERSION" == "major" ]; then
		VERSION=`next "$1"`
	fi

	echo "Create release version:" $VERSION
	git flow release start $VERSION
	git flow release finish $VERSION

  	echo "Review the release then execute:"
    echo "git-release send"
}

function send () {
	MASTER=master
	DEVELOP=develop
	REMOTE=origin

	git checkout $DEVELOP && git pull $REMOTE $DEVELOP && git push $REMOTE $DEVELOP
	git checkout $MASTER && git pull $REMOTE $MASTER && git push $REMOTE --tags && git push $REMOTE $MASTER
	git checkout $DEVELOP
}

# Execute command + parameters
COMMAND="$1"
if [ "$COMMAND" == "help" ]; then
    COMMAND="_help"
fi

$COMMAND $2 $3
