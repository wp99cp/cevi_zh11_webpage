#!/bin/bash

# Abort on the first failing command. Without this a crashing Jekyll build is
# silently followed by minify + deploy, which publishes a half-empty _site while
# CI still reports success.
set -euo pipefail

build_started=$SECONDS

if [ "$MODE" == "production" ]; then
  echo "Use Production Backend"
  CONFIG_FILE="_config.yml"
else
  echo "Use Development Backend"
  CONFIG_FILE="_config.yml,_development.config.yml"
fi

# build page: some pages need two build passes (e.g. the sitemap to including auto generated pages)
JEKYLL_ENV=$MODE bundler exec jekyll build --incremental --profile --trace --config $CONFIG_FILE
JEKYLL_ENV=$MODE bundler exec jekyll build --incremental --profile --trace --config $CONFIG_FILE

# Drop generated images the finished site no longer links to, so that photos
# deleted in Google Drive stop being published and the build cache stays bounded.
# Runs here, after both passes, because --incremental skips unchanged pages and
# the plugins therefore cannot tell on their own which images are still in use.
ruby bin/prune-unused-images.rb ./_site

# Copy folder with documents to destination directory ./_site
mkdir -p ./_site/docs
if [ -d "./docs" ]; then
  cp -r ./docs ./_site
fi

# Minify the HTML, css, js, svg and json files
# See https://github.com/tdewolff/minify/tree/master/cmd/minify
minify --recursive --output "./_site" "./_site/" --verbose

# Report how much of the build was image work, and how much of that the caches
# managed to avoid. CI copies this into the job summary.
ruby bin/report-build-stats.rb "$((SECONDS - build_started))"

# We run jekyll again to server the website locally and enable livereload.
if [ "$MODE" != "production" ]; then
  JEKYLL_ENV=$MODE bundler exec jekyll serve --livereload --incremental --profile --trace --host=frontend --config $CONFIG_FILE
fi
