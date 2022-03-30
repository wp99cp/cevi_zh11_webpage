#!/bin/bash

# build page
jekyll build --incremental

# Copy folder with documents to destination directory ./_site
mkdir -p ./_site/docs
cp -r ./docs ./_site

# execute command, if provided
echo -e $'\n'Run: "$@"
eval "$@"
