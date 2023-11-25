# Build site
perl scripts/build.pl

# Deploy site
wrangler pages deploy output --project-name library
