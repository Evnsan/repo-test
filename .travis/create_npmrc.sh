#! /bin/bash
set -x

if [ -z "$NPM_AUTH_TOKEN" ]; then
  echo "Error: NPM_AUTH_TOKEN not set"
  exit 1;
fi

if [ -z "$NPM_REGISTRY_URL" ]; then
  echo "Error: NPM_REGISTRY_URL not set"
  exit 1;
fi

if [ -z "$NPMRC" ]; then
  npmrc_path="$HOME/.npmrc"
else
  npmrc_path="$HOME/$NPMRC"
fi

auth_token=$NPM_AUTH_TOKEN
npm_registry_url=$NPM_REGISTRY_URL
registry="https://$npm_registry_url"

cat > $npmrc_path <<EOF
@cobli:registry=$registry
//$npm_registry_url:_authToken=$auth_token
always-auth=true
EOF

echo "$(npm whoami --registry https://npm.cobli.co)"
