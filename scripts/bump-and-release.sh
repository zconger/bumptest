#!/usr/bin/env bash

# Declare variables
declare -a BUMP_ARGS
VERSION_PART="patch"
PUSH=true
TAG=true
RELEASE=true
BUMP_CMD=""
PUSH_CMD=""
GH_CMD=""
USAGE_SUMMARY="$(basename "${0}") [VERSION_PART] [--no-commit] [--no-tag] [--no-push] [--dry-run] [--no-release] [--help]"

function synopsis() {
  if [[ -n "${ERROR}" ]]; then
    >&2 echo "${ERROR}"
  fi
  cat <<EOF
Usage:    ${USAGE_SUMMARY}
For help: $(basename "${0}") --help
EOF
}

function help() {
  if [[ -n "${ERROR}" ]]; then
    >&2 echo "ERROR: ${ERROR}"
  fi
  cat <<EOF
Usage: ${USAGE_SUMMARY}
  VERSION_PART      Which part of the version to bump. Must be one of major, minor, or patch. [Default: patch]
  -nc | --no-commit   Do not commit after bumping the version. Implies '--no-tag' and '--no-push'.
  -nt | --no-tag      Do not tag after bumping.
  -np | --no-push     Do not push after bumping the version and committing the change.
  -nr | --no-release  Do not cut a GitHub release
  -d | --dry-run      Explain what will be done, but make no changes to the version, do not commit, and do not push.
  -h | --help         Print this usage guide.

$(basename "${0}") prepares this repository for a version release. It performs the following tasks:
 - Checks to make sure the repo is clean and up to date with the origin
 - Checks to make sure the repo is clean
 - Checks that 'bump2version' is installed
 - Checks that 'gh' is installed
 - Runs 'npm run all' to make sure this Action is tested and packaged
 - Runs 'bump2version' with appropriate options
 - Cuts a GitHub release, unless '--dry-run', '--no-push', '--no-commit', or '--no-tag' were specified

To release the new version of this GitHub Action to the GitHub Marketplace, visit the releases web page
page for this repo and follow the instructions there.
EOF
}

function parse_args() {
  while [[ ${#} -gt 0 ]]; do
    key="${1}"
    case ${key} in
      major|minor|patch)
        if [[ -z "${VERSION_PART}" ]]; then
          VERSION_PART=${1}
        else
          ERROR="One version part at a time, please. You tried '${VERSION_PART}' and '${1}'."
          synopsis
          exit 1
        fi
        shift
        ;;
      -nc|--no-commit)
        BUMP_ARGS+=("--no-commit")
        BUMP_ARGS+=("--no-tag")
        TAG=false
        PUSH=false
        RELEASE=false
        shift
        ;;
      -nt|--no-tag)
        BUMP_ARGS+=("--no-tag")
        TAG=false
        RELEASE=false
        shift
        ;;
      -d|--dry-run)
        BUMP_ARGS+=("--dry-run")
        shift
        ;;
      -np|--no-push)
        PUSH=false
        RELEASE=false
        shift
        ;;
      -nr|--no-release)
        RELEASE=false
        shift
        ;;
      -h|--help)
        help
        exit 0
        ;;
      *)
        ERROR="Unknown option: '${1}'."
        synopsis
        exit 1
        ;;
    esac
  done
}

function summarize_plan() {
  echo "Congratulations. This script is about to run the following commands:"
  echo "Check the plan above. Hit return to continue, or <ctrl>-c to bail."
  pause
}

function check_deps() {
  echo "Checking dependencies..."
  for prereq in gh bump2version; do
    if ! command -v "${prereq}" > /dev/null; then
      >&2 echo "ERROR: Prerequisite '${prereq}' not found."
      exit 1
    fi
  done
}

function git_pull() {
  echo "Running 'git pull'..."
  if ! git pull ; then
    >&2 echo "ERROR: 'git pull' failed."
    exit 1
  fi
}

function package_prep() {
  echo "Running 'npm run all'..."
  if ! npm run all ; then
    >&2 echo "ERROR: 'npm run all' failed."
    exit 1
  fi
}

function bump_version() {
  echo "Running 'bump2version'..."
  bump_cmd="bump2version ${VERSION_PART} ${BUMP_ARGS[*]}"
  echo "${bump_cmd}"
}

function git_push() {
  if [[ $PUSH == "true" ]]; then
    echo "git push"
    if [[ $TAG == "true" ]]; then
      echo "git push --tags"
    fi
  fi
}

function pause() {
  read -r
}

function main() {
  parse_args "$@"
  check_deps
  git_pull
  summarize_plan
  package_prep
  bump_version
  git_push
}

# Do the things
main "$@"
