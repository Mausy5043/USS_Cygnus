#!/usr/bin/env bash

HOSTNAME=$(hostname)

if [[ ! -f "${HOME}/.config/cygnus/branch" ]]; then
  echo "${HOME}/.config/cygnus/branch not set!"
  exit 1
else
  BRANCH=$( cat "${HOME}/.config/cygnus/branch" )
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${DIR}/bin/include"

pushd "${DIR}" || exit 1
  # shellcheck disable=SC1091
  git fetch origin
  # Check which files have changed
  DIFFLIST=$(git --no-pager diff --name-only "$BRANCH..origin/$BRANCH")
  git pull
  git fetch origin
  git checkout "$BRANCH"
  git reset --hard "origin/$BRANCH" && git clean -f -d
popd
