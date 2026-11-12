#!/bin/sh
#  Build an Alire index holding the gnat_llvm manifest, from the template
#  plus one origin block per platform (as written by make-dist.sh).
#
#  Usage: make-manifest.sh INDEX_DIR ORIGIN.toml...

set -eu

VERSION=${VERSION:-16.1.0}
HERE=$(cd "$(dirname "$0")" && pwd)
IDX=$1
shift

CRATE_DIR=$IDX/gn/gnat_llvm
rm -rf "$IDX"
mkdir -p "$CRATE_DIR"
echo 'version = "1.4.0"' > "$IDX/index.toml"

sed -e "s|@VERSION@|$VERSION|g" "$HERE/gnat_llvm.toml.in" \
  > "$CRATE_DIR/gnat_llvm-$VERSION.toml"
cat "$@" >> "$CRATE_DIR/gnat_llvm-$VERSION.toml"
