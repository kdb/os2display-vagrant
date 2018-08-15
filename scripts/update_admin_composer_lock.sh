#!/usr/bin/env bash
# Uses an isolated docker container for performing a composer update of the admin-repositories lock-file.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $# -eq 0 ]] ; then
  if [[ -z "${GITHUB_TOKEN:-}" ]] ; then
    echo "Syntax: $0 <github-token> or the GITHUB_TOKEN environment variable must exist"
    exit 1
  else
    TOKEN=$GITHUB_TOKEN
  fi
else
  TOKEN=$1
fi

cd "${SCRIPT_DIR}/../htdocs/admin"

VERBOSE=
if [[ ! -z "${DEBUG:-}" ]] ; then
  VERBOSE="-vvvvv"
fi

# Default to updating all our forks and custom bundles.
UPDATE_TARGET="os2display/core-bundle os2display/admin-bundle kdb/os2display-kkbding2-bundle"
if [[ ! -z "${TARGET:-}" ]] ; then
  UPDATE_TARGET="${TARGET}"
fi

docker run \
  -v /app/vendor \
  -v $(pwd):/app:delegated \
  --entrypoint "/bin/bash" composer:1.6.5 \
  -c "apk --update add grep && composer config -g github-oauth.github.com ${TOKEN} && composer global require hirak/prestissimo && composer update ${VERBOSE} ${UPDATE_TARGET}"
