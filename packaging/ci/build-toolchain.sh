#!/bin/sh
#  Build GNAT-LLVM from a fresh gnat-llvm checkout, linked statically
#  against the LLVM from build-llvm.sh, plus its runtimes.
#
#  Usage: build-toolchain.sh STEP...    (run from the gnat-llvm checkout root)
#
#  Steps:
#    sources   fetch GCC (+ local patches), llvm-bindings, adawebpack and
#              bb-runtimes, and create the symlinks llvm-interface expects
#    compiler  build llvm-gnat1 / llvm-gcc / tools and the native runtime
#    wasm      build all wasm32 runtimes (needs EMCC, WASI_SYSROOT)
#
#  Environment:
#    LLVM_PREFIX          static LLVM install (required for compiler, wasm)
#    GCC_TAG              default releases/gcc-16.1.0
#    ADAWEBPACK_REPO/REF  default ovenpasta/adawebpack master
#    BB_RUNTIMES_REPO/REF default ovenpasta/bb-runtimes gnat-fsf-15
#    EMCC                 emcc driver (wasm step)
#    WASI_SYSROOT         wasi-libc sysroot (wasm step)
#    JOBS                 parallel jobs

set -eu

ROOT=$PWD
LI=$ROOT/llvm-interface
GCC_TAG=${GCC_TAG:-releases/gcc-16.1.0}
ADAWEBPACK_REPO=${ADAWEBPACK_REPO:-https://github.com/ovenpasta/adawebpack.git}
ADAWEBPACK_REF=${ADAWEBPACK_REF:-master}
BB_RUNTIMES_REPO=${BB_RUNTIMES_REPO:-https://github.com/ovenpasta/bb-runtimes.git}
BB_RUNTIMES_REF=${BB_RUNTIMES_REF:-gnat-fsf-15}
JOBS=${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}

clone () {   # clone REPO REF DIR
   if [ ! -d "$3" ]; then
      git clone --depth 1 --branch "$2" "$1" "$3"
   fi
}

step_sources () {
   clone https://github.com/gcc-mirror/gcc.git "$GCC_TAG" "$LI/gcc"
   for p in gcc-16-repinfo-accessors gcc-16-allow-reraise-no-propagation \
            gcc-16-wasm-eh-raise-gcc; do
      git -C "$LI/gcc" apply "$LI/patches/$p.patch"
   done
   ln -sfn gcc/gcc/ada "$LI/gnat_src"

   clone https://github.com/AdaCore/llvm-bindings.git llvm-21 \
     "$ROOT/llvm-bindings"

   clone "$ADAWEBPACK_REPO" "$ADAWEBPACK_REF" "$LI/adawebpack_src"
   ln -sfn adawebpack_src/source/rtl/Makefile.target "$LI/Makefile.target"

   clone "$BB_RUNTIMES_REPO" "$BB_RUNTIMES_REF" "$LI/bb-runtimes"
   ln -sfn bb-runtimes/gnat_rts_sources/include/rts-sources "$LI/rts-sources"
}

llvm_make () {
   #  LDFLAGS replaces the Makefile's shared-LLVM default: link LLVM and
   #  clangBasic statically, libstdc++/libgcc too (see gnat_llvm.gpr).
   LLVM_CONFIG=$LLVM_PREFIX/bin/llvm-config
   PATH=$LLVM_PREFIX/bin:$PATH make -C "$LI" PROCS="$JOBS" \
     LLVM_CONFIG="$LLVM_CONFIG" CLANG_LINK_LIB=clangBasic \
     LDFLAGS="$($LLVM_CONFIG --link-static --ldflags --libs all --system-libs)" \
     "$@"
}

step_compiler () {
   #  gnatlib-automated = build-opt (Production compiler) + native runtime
   #  with copied (not symlinked) sources.
   llvm_make gnatlib-automated
   #  The default target triple is baked in from "clang -dumpmachine".
   if grep -q '""' "$LI/obj/options-target.ads"; then
      echo "error: empty default target triple" >&2
      exit 1
   fi
}

step_wasm () {
   : "${EMCC:?}" "${WASI_SYSROOT:?}"
   for enc in legacy exnref; do
      GNAT_WASM_EH=$enc llvm_make -o build -o setup \
        EMCC="$EMCC" \
        WASM_CC="$LLVM_PREFIX/bin/clang" \
        WASM_CC_SYSROOT="$(dirname "$(command -v "$EMCC")")/cache/sysroot" \
        WASI_CC="$LLVM_PREFIX/bin/clang" WASI_SYSROOT="$WASI_SYSROOT" \
        LLVM_RANLIB="$LLVM_PREFIX/bin/llvm-ranlib" \
        wasm-eh wasm-emcc-eh wasm-wasi-eh
   done
   llvm_make -o build -o setup EMCC="$EMCC" \
     LLVM_RANLIB="$LLVM_PREFIX/bin/llvm-ranlib" \
     wasm wasm-emcc
}

for s in "$@"; do
   "step_$s"
done
