#!/bin/bash

set -ex -o pipefail

source venv/bin/activate

last_tag=$(git describe --tags --abbrev=0 HEAD | head -n1)
githubrelease asset "$TRAVIS_REPO_SLUG" upload "$last_tag" "$@"
