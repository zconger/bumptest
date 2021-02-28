#!/usr/bin/env bash


function bd_double_bump {
  version_bump=$1
  bd_cut_validate $version_bump
  validated=$?
  if [[ ${validated} -ne 0 ]]; then
    echo "bd_double_bump could not validate"
    return 1
  fi
  echo "About to cut and double bump this $version_bump release"
  bd_cut_pull_release $version_bump "master"
  current_branch=$(bd_current_branch)
  git checkout develop
  git pull origin $current_branch
  bd_cut_pull_release "patch" "develop"
  return 0
}

function bd_cut_validate {
  # prevent anticipated failures
  version_bump=$1
  current_version=$(cat VERSION)
  bumps=('major' 'minor' 'patch')
  bd_in_list ${version_bump} "${bumps[*]}"
  valid_bump=$?
  if [[ ${valid_bump} -ne 0 ]]; then
    echo "expecting arg1 version bump \"$version_bump\" to be either: ${bumps[@]} "
    return 1
  fi
  if ! bd_release_ready ; then
    echo "not release ready..."
    return 1
  fi
  updated_version=$(bd_bp_dryrun_version_bump ${version_bump})
  updated_status=$?
  if [[ ${updated_status} -ne 0 ]]; then
    echo "VERSION BUMP EXPECTED TO FAIL, get out now!"
    return 1
  fi
  if [[ "$updated_version" = "$current_version" ]] ; then
    echo "updated_version expected to match current_version. exiting early..."
    return 1
  fi
  return 0
}

function bd_cut_pull_release {
  version_bump=$1
  base_branch=$2
  current_version=$(cat VERSION)
  current_workdir=$(pwd)
  pr_output_file='./pr.txt'
  repo_name=$(basename $current_workdir)
  echo "currently in the $repo_name project, about to cut a $version_bump release to PR against $base_branch."
  echo "❗ You can ctrl+c here to go back first..."
  bd_pause_for_stdin "Press [Enter] key to continue..."
  # cut that release baby!
  bd_cut_release $version_bump
  cut=$?
  if [[ ${cut} -ne 0 ]]; then
    echo "the ($base_branch) release did not cut!"
    return 1
  fi
  current_branch=$(bd_current_branch)
  updated_version=$(cat VERSION)
  git push origin "$current_branch" --tags
  echo "Pushed branch $current_branch to $repo_name with tags"
  message="💎 *$repo_name* v$updated_version -> $base_branch"
  hub pull-request -p -m "$message" -b "$base_branch" | tee $pr_output_file
  echo "☝️ Boom theres the release PR to $base_branch"
  hub_pr_output=$(cat $pr_output_file)
  rm $pr_output_file
  bd_kaakaww_slack_message "$message\n$hub_pr_output"
  return 0
}

function bd_in_list {
  for item in $( echo "${2}" ); do
    if [[ ${item} == ${1} ]]; then
      return 0
    fi
  done
  return 1
}

# Echo the current git branch
function bd_current_branch {
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  echo "$CURRENT_BRANCH"
  return 0
}

function bd_release_ready {
  current_version=$(cat VERSION)
  if [[ ! "$current_version" ]]; then
    echo "no VERSION file found. This repo likely hasn't been configured for this release process. Exiting for safety..."
    return 1
  fi
  bd_has_dep "bumpversion"
  bumpversion_installed=$?
  if [[ ${bumpversion_installed} -ne 0 ]]; then
    echo "bumpversion is not on your path; please install bumpversion https://pypi.org/project/bumpversion/"
    return 1
  fi
  bd_has_dep "hub"
  hub_installed=$?
  if [[ ${hub_installed} -ne 0 ]]; then
    echo "hub is not on your path; please install hub with 'brew install hub'"
    return 1
  fi
  bd_clean_working_dir
  clean_working_dir=$?
  if [[ ${clean_working_dir} -ne 0 ]]; then
    echo "The working directory is not clean. You must commit any changes before running a release..."
    return 1
  fi
  bd_current_branch_is_develop
  on_develop_branch=$?
  if [[ ${on_develop_branch} -ne 0 ]]; then
    echo "The current git branch is set to \"$CURRENT_BRANCH\"; to make a release you must be on the \"$DEVELOP_BRANCH\" branch to make a release. Try again..."
    return 1
  fi
  return 0
}

function bd_bp_dryrun_version_bump() {
  version_bump=$1
  UPDATED_VERSION=$(bumpversion --dry-run --list "$version_bump" | grep new_version | sed s,"^.*=",,)
  UPDATED_STATUS=$?
  if [[ ${UPDATED_STATUS} -ne 0 ]]; then
    return 1
  fi
  echo ${UPDATED_VERSION}
  return 0
}

function bd_pause_for_stdin {
  echo "$1"
  read -r
  return 0
}

function bd_cut_release {
  # prevent anticipated failures
  version_bump=$1
  bd_cut_validate $version_bump
  validated=$?
  if [[ ${validated} -ne 0 ]]; then
    echo "cut_release could not validate"
    return 1
  fi
  # prepare to cut the release
  bd_cut_prepare
  prepared=$?
  if [[ ${prepared} -ne 0 ]]; then
    echo "cut_release could not prepare"
    return 1
  fi
  # cut the release
  current_version=$(cat VERSION)
  updated_version=$(bd_bp_dryrun_version_bump $version_bump)
  updated_branch="release/$updated_version"
  echo "Current version: $current_version"
  echo "Version Bump: $version_bump"
  echo "The next release version will be: $updated_version"
  echo "❗ This is your last chance to ctrl+c"
  bd_pause_for_stdin "Press [Enter] key to continue..."
  git checkout -b "$updated_branch"
  bd_update_changelog "$updated_version"
  bumpversion "$version_bump" --current-version "$current_version" --commit --tag
  echo "💎 release $updated_version has been made. Remember to run \"git push origin $updated_branch --tags\""
  return 0
}