#!/bin/bash

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

# Copy folder with documents to destination directory ./_site
mkdir -p ./_site/docs
cp -r ./docs ./_site

# Minify the HTML, css, js, svg and json files
# See https://github.com/tdewolff/minify/tree/master/cmd/minify
minify --recursive --output "./_site" "./_site/" --verbose

# We run jekyll again to server the website locally and enable livereload.
if [ "$MODE" != "production" ]; then
  JEKYLL_ENV=$MODE bundler exec jekyll serve --livereload --incremental --profile --trace --host=frontend --config $CONFIG_FILE
fi
