#!/bin/bash

# build page
bundler install
JEKYLL_ENV=production bundler exec jekyll build --incremental --profile --trace

# Copy folder with documents to destination directory ./_site
mkdir -p ./_site/docs
cp -r ./docs ./_site

# Minify the HTML, css, js, svg and json files
# See https://github.com/tdewolff/minify/tree/master/cmd/minify
minify --recursive --output "./_site" "./_site/" --verbose

# execute command, if provided
echo -e $'\n'Run: "$@"
eval "$@"