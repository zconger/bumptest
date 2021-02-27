#!/usr/bin/env bash

# Declare variables
declare -a BUMP_ARGS
PUSH=true
TAG=true
RELEASE=true
USAGE_SUMMARY="$(basename "${0}") [VERSION_PART] [--no-commit] [--no-tag] [--no-push] [--dry-run] [--no-release] [--help]"

function synopsis() {
  local error=$1
  if [[ -n "${error}" ]]; then
    echo >&2 "${error}"
  fi
  cat <<EOF
Usage:    ${USAGE_SUMMARY}
For help: $(basename "${0}") --help
EOF
}

function help() {
  local error=$1
  if [[ -n "${error}" ]]; then
    echo >&2 "ERROR: ${error}"
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

$(basename "${0}") without options performs a patch version release. It performs the following tasks:
 - Checks to make sure the repo is clean and up to date with the origin
 - Checks to make sure the repo is clean
 - Checks that 'bump2version' is installed
 - Checks that 'gh' is installed
 - Runs 'npm run all' to make sure this Action is tested and packaged
 - Runs 'bump2version patch'
 - Commits, tags, and pushes changes to GitHub
 - Cuts a GitHub release

To release the new version of this GitHub Action to the GitHub Marketplace, you will need to visit the releases web
page for this repo, and follow the instructions there.
EOF
}

function parse_args() {
  while [[ ${#} -gt 0 ]]; do
    key="${1}"
    case ${key} in
    major | minor | patch)
      if [[ -z "${VERSION_PART}" ]]; then
        VERSION_PART=${1}
      else
        ERROR="One version part at a time, please. You tried '${VERSION_PART}' and '${1}'."
        synopsis
        exit 1
      fi
      shift
      ;;
    -nc | --no-commit)
      BUMP_ARGS+=("--no-commit")
      BUMP_ARGS+=("--no-tag")
      TAG=false
      PUSH=false
      RELEASE=false
      shift
      ;;
    -nt | --no-tag)
      BUMP_ARGS+=("--no-tag")
      TAG=false
      RELEASE=false
      shift
      ;;
    -d | --dry-run)
      BUMP_ARGS+=("--dry-run")
      BUMP_ARGS+=("--verbose")
      shift
      ;;
    -np | --no-push)
      PUSH=false
      RELEASE=false
      shift
      ;;
    -nr | --no-release)
      RELEASE=false
      shift
      ;;
    -h | --help)
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

  if [[ -z "${VERSION_PART}" ]]; then
    VERSION_PART="patch"
  fi
}

function planner() {
  mode=${1}
  if [[ ${mode} == "plan" ]]; then
    echo
    echo "Congratulations! This script is about to run the following commands:"
  elif [[ ${mode} == "run" ]]; then
    echo "Here we go!"
  else
    echo >&2 "ERROR: This shouldn't happen"
    exit 1
  fi

  # Here's the plan:
  package_prep "${mode}"
  bump_version "${mode}"
  git_push "${mode}"
  gh_pr "${mode}"
#  gh_release "${mode}"

  if [[ ${mode} == "plan" ]]; then
    echo "Check the plan above. Hit return to continue, or <ctrl>-c to bail."
    read -r
  fi
}

function check_deps() {
  echo -n "Checking dependencies... "
  for prereq in gh bump2version; do
    if ! command -v "${prereq}" >/dev/null; then
      echo "OH NO!"
      echo >&2 "ERROR: Prerequisite '${prereq}' not found."
      exit 1
    fi
  done
  echo "OK"
}

function check_repo() {
  echo -n "Checking if repo is clean... "
  branch=$(git branch --show-current)
  if [[ ${branch} =~ ^(master|main|develop)$ ]]; then
    echo "OH NO!"
    echo " You tried to push to the master, main, or develop branches. Try this from a feature branch."
    exit 1
  fi
  if output=$(git status --untracked-files=no --porcelain) && [ -z "$output" ]; then
    # Working directory clean
    echo "OK!"
  else
    # Uncommitted changes
    echo "OH NO!"
    echo " There are uncommitted changes in this repo."
    echo " Please commit any staged changes before running this again:"
    echo "${output}"
    exit 1
  fi
}

function check_version() {
  echo "Checking version info"
  bump_list=$(bump_version run --dry-run --list)
  CURRENT_VERSION=$(echo "${bump_list}" | grep current_version | cut -d'=' -f2)
  NEW_VERSION=$(echo "${bump_list}" | grep new_version | cut -d'=' -f2)
  echo " Current version:  ${CURRENT_VERSION}"
  echo " Proposed version: ${NEW_VERSION}"
}

function git_pull() {
  echo "Pulling any remote commits..."
  cmd="git pull"
  run "${cmd}" run
}

function package_prep() {
  mode=${1}
  cmd="npm run all"
  run "${cmd}" "${mode}"
}

function bump_version() {
  mode=${1}
  shift
  cmd="bump2version ${*} ${BUMP_ARGS[*]} ${VERSION_PART}"
  run "${cmd}" "${mode}"
}

function git_push() {
  mode=${1}
  if [[ $PUSH == "true" ]]; then
    cmd="git push"
    run "${cmd}" "${mode}"
    if [[ $TAG == "true" ]]; then
      cmd="git push --tags"
      run "${cmd}" "${mode}"
    fi
  fi
}

# add --no-pr
function gh_pr() {
  mode=${1}
  cmd="gh pr create --web --base main --title \"Bump version: ${CURRENT_VERSION} → ${NEW_VERSION}\""
  run "${cmd}" "${mode}"
}

#function gh_release() {
#  mode=${1}
#  cmd="gh release create v${NEW_VERSION} --title \"HawkScan Action ${NEW_VERSION}\""
#  run "${cmd}" "${mode}"
#}

function run() {
  cmd=${1}
  mode=${2}
  echo "Run: '${cmd}'"
  if [[ ${mode} == "run" ]]; then
    if ! eval "${cmd}"; then
      echo >&2 "ERROR: '${cmd}' failed."
      exit 1
    fi
  fi
}

# The things
function main() {
  parse_args "$@"
  check_deps
  check_repo
  git_pull
  check_version
  planner plan
  planner run
}

# Do the things
main "$@"
