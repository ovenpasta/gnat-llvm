#!/bin/sh
#  Build a static LLVM + clang + lld for linking GNAT-LLVM into
#  self-contained binaries, and for bundling clang / wasm-ld with it.
#
#  Usage: build-llvm.sh PREFIX
#
#  Environment:
#    LLVM_VERSION  release to build (default 21.1.8)
#    CC, CXX       host compilers (use GNAT's gcc/g++ so LLVM and the GNAT-LLVM
#                  C++ parts share one libstdc++)
#    JOBS          parallel jobs (default: nproc)

set -eu

PREFIX=$1
LLVM_VERSION=${LLVM_VERSION:-21.1.8}
JOBS=${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}
WORK=${WORK:-$PWD/llvm-work}

case $(uname -m) in
   x86_64)        HOST_TARGET=X86 ;;
   aarch64|arm64) HOST_TARGET=AArch64 ;;
   *)             echo "unsupported host: $(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$WORK"
cd "$WORK"

if [ ! -d llvm-project ]; then
   git clone --depth 1 --branch "llvmorg-$LLVM_VERSION" \
     https://github.com/llvm/llvm-project.git
fi

#  Static libraries only (BUILD_SHARED_LIBS / LLVM_BUILD_LLVM_DYLIB off),
#  and no optional host libraries, so the resulting binaries only need
#  libc.  libstdc++ and libgcc are linked statically.
cmake -G Ninja -S llvm-project/llvm -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_C_COMPILER="${CC:-gcc}" \
  -DCMAKE_CXX_COMPILER="${CXX:-g++}" \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="$HOST_TARGET;WebAssembly" \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DCLANG_ENABLE_ARCMT=OFF \
  -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
  -DCLANG_PLUGIN_SUPPORT=OFF \
  -DLLVM_PARALLEL_LINK_JOBS=2

ninja -C build -j "$JOBS" install
