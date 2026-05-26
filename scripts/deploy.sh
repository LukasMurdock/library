#!/usr/bin/env bash

set -euo pipefail

# check if perl is installed
if ! [ -x "$(command -v perl)" ]; then
  echo 'Error: perl is not installed. Please install perl (https://www.perl.org/).' >&2
  exit 1
fi

# check if local wrangler is installed
if ! [ -x "./node_modules/.bin/wrangler" ]; then
  echo 'Error: local wrangler is not installed. Run: pnpm install' >&2
  exit 1
fi

# Build site
perl scripts/build.pl

# Deploy site
pnpm exec wrangler pages deploy
