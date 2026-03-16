# GNAT-LLVM GCC 15 Notes

This document covers the compiler-side changes that belong in the
`gnat-llvm` repository.

## Scope

These are the `gnat-llvm` changes needed for the current GCC 15 and
WebAssembly work:

- `gcc_wrapper.adb`
  Respect user-supplied `-target` / `--target=...` instead of always forcing
  the default target triple during Clang invocation.
- `gnat_llvm.gpr`
  Make the Clang C++ link library configurable through `Clang_Link_Lib`,
  keeping `clangBasic` as the default and allowing distro-specific overrides
  such as `clang-cpp` on Arch Linux.
- `Makefile`
  Pass `Clang_Link_Lib` from `make` into `gprbuild`.
  Also pass `-DGXX_EH_INTEROP=0` into native runtime C builds so the
  `raise-gcc.c` runtime uses the supported non-C++-interop path under
  `gnat-llvm`, without requiring GCC source changes.
- `check_for_llvm_apis.sh`
  Handle an unset `LD_LIBRARY_PATH` correctly under `set -u`.
- `llvm_wrapper2.cc`
  LLVM API/header updates for current LLVM releases.
- `get_targ.adb`
  Look up `target.atp` from the selected runtime before falling back to the
  compiler executable directory. See `SEPARATE-RUNTIMES.md`.
- `patches/gcc-15-repinfo-accessors.patch`
  Small GCC-side `Repinfo` accessor patch required by
  `gnatllvm-records-debug.adb` when building against upstream GCC 15.
- `gnatllvm-blocks.adb`
  WebAssembly-target conditional activation-record parameter fix for
  `__finalizer`.
- `gnatllvm-instructions.adb`
  WebAssembly-target conditional `nest` handling changes at call sites.
- `gnatllvm-subprograms.adb`
  WebAssembly-target conditional `nest` handling changes on function
  definitions and explicit activation-record ABI shaping.
  `Get_Param_Kind` now uses `Foreign_By_Ref` (pointer) for
  `C_Pass_By_Copy` record parameters on wasm32 instead of `In_Value`,
  fixing the wasm32 C ABI mismatch where Ada was expanding the struct
  to individual fields instead of passing a pointer.
  Record return values (`Get_Return_Kind`) do not need a wasm32 fix:
  LLVM's wasm32 backend maps `{i32, i32}` return type to multivalue
  return, which matches what Clang generates for the same C struct.
