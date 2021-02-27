#!/usr/bin/env bash

# Source common variables and functions
#. ./scripts/common.sh

# Declare variables
BASE=main
USAGE_SUMMARY="$(basename "${0}") [--bump PART] [--dry-run] [--help] [--base BRANCH] [--commit MSG]"

function help() {
  local error=$1
  if [[ -n "${error}" ]]; then
    echo >&2 "ERROR: ${error}"
  fi
  cat <<EOF
Usage: ${USAGE_SUMMARY}
  -b | --bump PART   Bump the version before creating a PR. PART must be one of 'major', 'minor', or 'patch'.
                     Do this if you plan to create a new version release and release to GitHub Marketplace!
  -B | --base BASE   Target the BASE branch instead of 'main'. [Default: main]
  -c | --commit MSG  Commit message. [Default: "prepare for pull request to BASE"]
  -d | --dry-run     Explain what will be done, but make no changes, do not commit, do not push, and do not create a PR.
  -h | --help        Print this usage guide.

This script will package up the GitHub Action in this repo and submit a PR for it.
 - Bumps the NPM version if specified. This is required before creating a new release for the GitHub Marketplace
 - Packages the Action and all dependencies and licenses to the ./dist directory
 - Commits and pushes changes to GitHub
 - Creates a PR

To release the new version of this GitHub Action to the GitHub Marketplace, you will need to visit the releases web
page for this repo, and follow the instructions there.
EOF
}

function parse_args() {
  while [[ ${#} -gt 0 ]]; do
    local key="${1}"
    case ${key} in
    -b | --bump)
      PART=${2}
      if [[ ! ${PART} =~ (major|minor|patch) ]]; then
        ERROR="The only valid options for --bump are major, minor, or patch"
        help "${ERROR}"
        exit 1
      fi
      shift 2;;
    -B | --base)
      BASE=${2}
      shift 2;;
    -c | --commit)
      MSG=${2}
      shift 2;;
    -d | --dry-run)
      DRY_RUN="true"
      shift;;
    -h | --help)
      help
      exit 0
      ;;
    *)
      ERROR="Unknown option: '${1}'."
      synopsis "${ERROR}"
      exit 1
      ;;
    esac
  done
  if [[ -z $MSG ]]; then
    MSG="prepare for pull request to ${BASE}"
  fi
}

function planner() {
  local mode=${1}
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
  bump_version "${mode}"
  package_prep "${mode}"
  git_commit "${mode}"
  git_push "${mode}"
  gh_pr "${mode}"

  if [[ ${mode} == "plan" ]]; then
    echo "Check the plan above. Hit return to continue, or <ctrl>-c to bail."
    read -r
  fi
}

function check_deps() {
  echo -n "Checking dependencies... "
  for prereq in gh bump2version jq; do
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
  local branch=$(git branch --show-current)
  if [[ ${branch} =~ ^(master|main|develop)$ ]]; then
    echo "OH NO!"
    echo " You can't push to the master, main, or develop branches. Try this from a feature branch."
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
  if [[ -n $PART ]]; then
    echo "Checking version info"
    bump_list=$(bump_version run --dry-run --list)
    CURRENT_VERSION=$(echo "${bump_list}" | grep current_version | cut -d'=' -f2)
    NEW_VERSION=$(echo "${bump_list}" | grep new_version | cut -d'=' -f2)
    echo " Current version:  ${CURRENT_VERSION}"
    echo " Proposed version: ${NEW_VERSION}"
  else
    version=$(jq .version -r < package.json)
    echo "INFO: Current version is ${version}. Version will not be updated."
  fi
}

function git_pull() {
  echo "Pulling any remote commits..."
  run "git pull" run
}

function package_prep() {
  local mode=${1}
  run "npm run all" "${mode}"
  run "git add dist" "${mode}"
}

function bump_version() {
  local mode=${1}
  shift
  if [[ -n $PART ]]; then
    cmd="bump2version ${*} ${PART}"
    run "${cmd}" "${mode}"
  fi
}

function git_commit() {
  local mode=${1}
  local cmd="git commit -m ${MSG}"
  run "${cmd}" "${mode}"
}

function git_push() {
  local mode=${1}
  run "git push" "${mode}"
}

# add --no-pr
function gh_pr() {
  local mode=${1}
  local cmd="gh pr create --web --base ${BASE} --title \"${MSG}\""
  run "${cmd}" "${mode}"
}

function run() {
  local cmd=${1}
  local mode=${2}
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

 - Bumps the NPM version if specified. This is required before creating a new GitHub release (and release to Marketplace)
 - Runs 'npm run all' to make sure this Action is tested and packaged
 - Commits and pushes changes to GitHub
 - Creates a PR