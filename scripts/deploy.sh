# !/bin/bash

# check if perl is installed
if ! [ -x "$(command -v perl)" ]; then
  echo 'Error: perl is not installed. Please install perl (https://www.perl.org/).' >&2
  exit 1
fi

# check if wrangler is installed
if ! [ -x "$(command -v wrangler)" ]; then
  echo 'Error: wrangler is not installed. Please install wrangler (https://developers.cloudflare.com/workers/cli-wrangler/install-update).' >&2
  exit 1
fi

# Build site
perl scripts/build.pl

# Deploy site
wrangler pages deploy output --project-name library
