#!/usr/bin/env bash
#
# Prints a single hash describing the contents of the cached build directories.
#
# The CI workflow takes one of these before the build and one after, and only
# uploads a new cache entry when they differ. See the save step in
# .github/workflows/deploy.yml for why that matters.
#
# Paths and sizes are enough to recognise every change that can realistically
# happen here - an image added, removed, or re-encoded - without spending time
# reading well over a gigabyte of image data. Modification times are deliberately
# left out: they change on a fresh checkout and would make every run look dirty,
# which is the same mistake the image cache itself used to make.

set -euo pipefail

CACHED_PATHS=(imgs google_drive_cache docs)

existing=()
for path in "${CACHED_PATHS[@]}"; do
  [ -d "$path" ] && existing+=("$path")
done

if [ ${#existing[@]} -eq 0 ]; then
  echo "empty"
  exit 0
fi

# LC_ALL=C keeps the ordering independent of the runner's locale.
find "${existing[@]}" -type f -printf '%p %s\n' |
  LC_ALL=C sort |
  sha256sum |
  cut -d' ' -f1
