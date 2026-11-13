#!/bin/sh
#  Package the built GNAT-LLVM toolchain (compiler + runtimes) as a binary
#  tarball usable as an Alire toolchain crate, and generate an Alire index
#  manifest pointing at it.
#
#  Usage: make-dist.sh [OUT_DIR]
#
#  OUT_DIR defaults to packaging/alire/out.  Produces:
#    OUT_DIR/gnat_llvm-<ver>-<arch>-<os>.tar.gz (+ .sha256)
#    OUT_DIR/gnat_llvm-<ver>-<arch>-<os>.origin.toml (manifest origin block)
#    OUT_DIR/index/...   Alire index with the gnat_llvm manifest
#
#  Environment:
#    VERSION         crate version (default 16.1.0)
#    LLVM_INTERFACE  built llvm-interface tree (default: this checkout's)
#    LLVM_PREFIX     LLVM install to bundle clang, lld and llvm-ar from
#                    (default: none, the host's clang/wasm-ld are used)
#    URL_BASE        where the tarball will be downloaded from
#                    (default: file://OUT_DIR, for a local index)
#    WASI_SYSROOT    wasi-sdk sysroot to bundle the wasm32-wasip1 libc from
#    WASI_BUILTINS   wasi-sdk libclang_rt directory (needs LLVM_PREFIX)

set -eu

VERSION=${VERSION:-16.1.0}
HERE=$(cd "$(dirname "$0")" && pwd)
LLVM_INTERFACE=${LLVM_INTERFACE:-$HERE/../../llvm-interface}
LLVM_INTERFACE=$(cd "$LLVM_INTERFACE" && pwd)
LLVM_PREFIX=${LLVM_PREFIX:-}
WASI_SYSROOT=${WASI_SYSROOT:-}
WASI_BUILTINS=${WASI_BUILTINS:-}
OUT=${1:-$HERE/out}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
URL_BASE=${URL_BASE:-file://$OUT}

ARCH=$(uname -m)
case $(uname -s) in
   Linux)  OS=linux ;;
   Darwin) OS=macos ;;
   *)      echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
NAME=gnat_llvm-$VERSION-$ARCH-$OS
STAGE=$OUT/stage/$NAME

rm -rf "$OUT/stage"
mkdir -p "$STAGE/bin" "$STAGE/lib"

#  Compiler driver and tools
cp -a "$LLVM_INTERFACE"/bin/llvm-* "$STAGE/bin/"
if [ -d "$LLVM_INTERFACE/libexec" ]; then
   cp -a "$LLVM_INTERFACE/libexec" "$STAGE/"
fi

#  Runtimes.  obj-static holds RTS build intermediates, not needed to use
#  the runtime.  Symlinks are dereferenced so the tree is relocatable; a
#  runtime whose sources are symlinks into a source tree that has since
#  moved cannot be shipped, so it is left out.
EXCLUDES=$STAGE.excludes
echo 'gnat-llvm/*/obj-static' > "$EXCLUDES"
echo 'gnat-llvm/*/*/obj-static' >> "$EXCLUDES"
for rts in $(cd "$LLVM_INTERFACE/lib" \
             && find gnat-llvm -maxdepth 3 -type d -name 'rts-*'); do
   if [ -n "$(find -L "$LLVM_INTERFACE/lib/$rts" -type l | head -1)" ]; then
      echo "warning: leaving out $rts (dangling symlinks)" >&2
      echo "$rts" >> "$EXCLUDES"
   fi
done
tar -C "$LLVM_INTERFACE/lib" -X "$EXCLUDES" -chf - gnat-llvm \
  | tar -C "$STAGE/lib" -xf -
rm "$EXCLUDES"

#  lib/rts-native -> gnat-llvm/<triple>/rts-native: where the gprconfig
#  knowledge base of FSF gprbuild looks for the GNAT_LLVM native runtime.
if [ -L "$LLVM_INTERFACE/lib/rts-native" ]; then
   LINK=$(readlink "$LLVM_INTERFACE/lib/rts-native")
   if [ -d "$STAGE/lib/$LINK" ]; then
      ln -s "$LINK" "$STAGE/lib/rts-native"
   fi
fi

#  Bundled LLVM tools: llvm-gcc links through clang, wasm32 through wasm-ld.
if [ -n "$LLVM_PREFIX" ]; then
   for t in clang lld llvm-ar; do
      cp "$LLVM_PREFIX/bin/$t" "$STAGE/bin/"
   done
   ln -s lld "$STAGE/bin/wasm-ld"
   ln -s lld "$STAGE/bin/ld.lld"
   ln -s llvm-ar "$STAGE/bin/llvm-ranlib"
   #  clang's resource directory (builtin headers)
   cp -a "$LLVM_PREFIX/lib/clang" "$STAGE/lib/"
fi

#  WASI: the wasm32-wasip1 C part of the wasi-sdk sysroot (wasi-libc) and
#  the matching compiler-rt builtins, placed in the bundled clang's resource
#  directory where its driver looks for them.  With both, llvm-gcc links WASI
#  programs given --target=wasm32-wasip1 --sysroot=<prefix>/share/wasi-sysroot.
if [ -n "$WASI_SYSROOT" ]; then
   D=$STAGE/share/wasi-sysroot
   mkdir -p "$D/lib/wasm32-wasip1" "$D/include"
   cp "$WASI_SYSROOT"/lib/wasm32-wasip1/*.a \
      "$WASI_SYSROOT"/lib/wasm32-wasip1/*.o "$D/lib/wasm32-wasip1/"
   #  eh/ and noeh/ hold the C++ (libc++) headers
   tar -C "$WASI_SYSROOT/include" \
       --exclude=wasm32-wasip1/eh --exclude=wasm32-wasip1/noeh \
       -cf - wasm32-wasip1 | tar -C "$D/include" -xf -
   cp "$WASI_SYSROOT/VERSION" "$D/"
   cat > "$D/NOTICE" <<EOF
wasi-libc for wasm32-wasip1, from the wasi-sdk sysroot
(https://github.com/WebAssembly/wasi-sdk). wasi-libc
(https://github.com/WebAssembly/wasi-libc) is licensed under
Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT, and includes code
from musl libc (MIT); see the LICENSE files in its repository.
EOF
fi
if [ -n "$WASI_BUILTINS" ]; then
   if [ ! -d "$STAGE/lib/clang" ]; then
      echo "WASI_BUILTINS needs LLVM_PREFIX (the bundled clang)" >&2
      exit 1
   fi
   for r in "$STAGE"/lib/clang/*; do
      mkdir -p "$r/lib/wasm32-unknown-wasip1"
      cp "$WASI_BUILTINS/wasm32-unknown-wasip1/libclang_rt.builtins.a" \
         "$r/lib/wasm32-unknown-wasip1/"
   done
fi

#  JS glue for the standalone (non-Emscripten) runtimes
mkdir -p "$STAGE/share/gnat-llvm"
cp "$LLVM_INTERFACE/adawebpack_src/source/adawebpack.mjs" \
   "$STAGE/share/gnat-llvm/"

cp "$LLVM_INTERFACE/../COPYING3" "$STAGE/"

tar -C "$OUT/stage" -czf "$OUT/$NAME.tar.gz" "$NAME"
SHA=$(sha256sum "$OUT/$NAME.tar.gz" 2>/dev/null \
      || shasum -a 256 "$OUT/$NAME.tar.gz")
SHA=${SHA%% *}
echo "$SHA  $NAME.tar.gz" > "$OUT/$NAME.tar.gz.sha256"

#  Origin block for this platform.  make-manifest.sh merges one block per
#  platform into the crate manifest.
ORIGIN=$OUT/$NAME.origin.toml
{
   echo
   echo "[origin.\"case(os)\".$OS.\"case(host-arch)\".$(echo "$ARCH" | tr _ -)]"
   echo "binary = true"
   echo "url = \"$URL_BASE/$NAME.tar.gz\""
   echo "hashes = [\"sha256:$SHA\"]"
} > "$ORIGIN"

VERSION=$VERSION "$HERE/make-manifest.sh" "$OUT/index" "$ORIGIN"

echo "tarball: $OUT/$NAME.tar.gz ($(du -h "$OUT/$NAME.tar.gz" | cut -f1))"
echo "index:   $OUT/index"
