# GNAT-LLVM GCC 15 Notes

This document covers the compiler-side changes that belong in the
`gnat-llvm` repository.

## Scope

These are the `gnat-llvm` changes needed for the current GCC 15 and WASM work:

- `gcc_wrapper.adb`
  Respect user-supplied `-target` / `--target=...` instead of always forcing
  the default target triple during Clang invocation.
- `gnat_llvm.gpr`
  Make the Clang C++ link library configurable through `Clang_Link_Lib`,
  keeping `clangBasic` as the default and allowing distro-specific overrides
  such as `clang-cpp` on Arch Linux.
- `Makefile`
  Pass `Clang_Link_Lib` from `make` into `gprbuild`.
- `check_for_llvm_apis.sh`
  Handle an unset `LD_LIBRARY_PATH` correctly under `set -u`.
- `llvm_wrapper2.cc`
  LLVM API/header updates for current LLVM releases.
- `get_targ.adb`
  Look up `target.atp` from the selected runtime before falling back to the
  compiler executable directory.
- `gnatllvm-blocks.adb`
  WASM-specific activation-record parameter fix for `__finalizer`.
- `gnatllvm-instructions.adb`
  WASM-specific `nest` handling changes at call sites.
- `gnatllvm-subprograms.adb`
  WASM-specific `nest` handling changes on function definitions.

## Arch Linux

Some Arch Linux LLVM/Clang packages require the monolithic `clang-cpp`
library. Use:

```bash
make build CLANG_LINK_LIB=clang-cpp
```

If LLVM shared libraries are not found at runtime, add `LD_LIBRARY_PATH`:

```bash
LD_LIBRARY_PATH=/usr/lib make build CLANG_LINK_LIB=clang-cpp
```

## Runtime Separation

The compiler-side runtime-separation support is documented in
`SEPARATE-RUNTIMES.md`.
