#!/bin/bash

set -ex -o pipefail

# Check pre-conditions

if ! [ -f .bumpversion.cfg ]; then
  echo "No bumpversion config found, not releasing."
  exit 0
fi

if [[ -n "$TRAVIS_PULL_REQUEST" && "$TRAVIS_PULL_REQUEST" != false ]]; then
  echo "In a pull request build, not releasing"
  exit 0
fi

if [[ -n "$TRAVIS_TAG" ]]; then
  echo "In a tag build, not releasing"
  exit 0
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN not set"
  exit 1
fi

if git show --name-only --pretty='format:' HEAD | grep -qF .bumpversion.cfg; then
  echo "Version manually bumped, not releasing"
  exit 0
fi

if [ -z "$BUMPVERSION_DEV_PART" ]; then
  bumpversion_dev_part="dev"
  echo "Using bumpversion_dev_part default = $bumpversion_dev_part"
else
  bumpversion_dev_part=$BUMPVERSION_DEV_PART
fi

if [ -z "$BUMPVERSION_PATCH_PART" ]; then
  bumpversion_patch_part="patch"
  echo "Using bumpversion_patch_part default = $bumpversion_patch_part"
else
  bumpversion_patch_part=$BUMPVERSION_PATCH_PART
fi

if [ -z "$BUMPVERSION_RELEASE" ]; then
  bumpversion_release_part="release"
  echo "Using bumpversion_release_part default = $bumpversion_release_part"
else
  bumpversion_release_part=$BUMPVERSION_RELEASE_PART
fi

# Configure git for pushing

# Install Deps
[ -x venv ] || virtualenv venv
source venv/bin/activate
pip install "git+https://github.com/peritus/bumpversion.git" githubrelease semver

# Fetch tags so bumpversion fails in case of duplicates
git fetch --tags

new_version=$(bumpversion -n --list $bumpversion_master_part \
  | grep new_version \
  | sed -E 's/current_version\s*=\s*//')

new_tag="v${new_version}"

# If in master bump release and set dev to the next non-production version
dev_push=
if [[ "$TRAVIS_BRANCH" != dev ]] && git fetch origin dev:dev; then
    bumpversion $bumpversion_release_part \
      --commit --tag --tag-name='v{new_version}' \
      --message 'Release {new_version} [ci skip]'

    git checkout dev
    git merge --ff-only "$TRAVIS_BRANCH"
    bumpversion $bumpversion_patch_part \
        --commit --no-tag \
        --message 'Start dev version {new_version} [ci skip]'
    git checkout -

    dev_push=dev
else
    bumpversion $bumpversion_dev_part \
      --commit --tag --tag-name='v{new_version}' \
      --message 'Increase dev version {new_version} [ci skip]'
fi

echo git push --atomic origin "$TRAVIS_BRANCH" "$new_tag" $dev_push

# Make the Github releases
gen_release_notes() {
    local last_tag=$(git describe --tags --abbrev=0 "${new_tag}^" | head -n1)
    local start_date=$(git log -1 --format='%ai' "$last_tag")
    local merges=$(git log --merges "${last_tag}..${new_tag}^" --format=$'  - %b' | sed -E '/^\s*$/d')
    if [ -n "$merges" ]; then
        echo "Merges since $start_date:"
        echo
        echo "$merges"
    else
        local shortlog=$(git shortlog "${last_tag}..${new_tag}^")
        echo "Changes since $start_date:"
        echo "<pre>"
        echo "$shortlog"
        echo "</pre>"
    fi
}

echo githubrelease release "$TRAVIS_REPO_SLUG" create "$new_tag"
echo githubrelease release "$TRAVIS_REPO_SLUG" edit "$new_tag" --body "$(gen_release_notes)"
echo githubrelease release "$TRAVIS_REPO_SLUG" publish "$new_tag"
