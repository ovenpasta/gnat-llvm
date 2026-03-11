# Separate Runtime Build Support

This document describes the compiler-side support for keeping `gnat-llvm`
separate from the runtimes it consumes.

## Goal

The compiler package should not need target-specific runtime data in its own
`bin/` directory. Instead, each runtime should be self-contained and selected
through `--RTS=<runtime-root>`.

## Runtime Package Contract

Each runtime root should contain:

- `target.atp`
- `ada_source_path`
- `ada_object_path`
- `adainclude/`
- `adalib/`

Example layout:

```text
lib/gnat-llvm/wasm32/rts-wasm/
  target.atp
  ada_source_path
  ada_object_path
  adainclude/
  adalib/
```

## Compiler Behavior

`get_targ.adb` now resolves backend target parameters in this order:

1. `GNATLLVM_TARGET_ATP`
2. parent of `RTS_Lib_Path_Name`
3. parent of `RTS_Src_Path_Name`
4. executable-adjacent fallback

This allows `--RTS=<runtime-root>` to carry both the Ada runtime files and the
backend target metadata.

## Current Verified Runtime

The currently verified packaged runtime is:

```text
lib/gnat-llvm/wasm32/rts-wasm/
```

It has been validated with:

```bash
make wasm CLANG_LINK_LIB=clang-cpp

PATH=$PWD/bin:$PATH \
  make -C adawebpack_src build_examples \
    GPRBUILD_FLAGS="--target=llvm --RTS=$PWD/lib/gnat-llvm/wasm32/rts-wasm"
```

## Naming Model

The intended layout for multiple runtimes is:

```text
lib/gnat-llvm/<target>/<runtime-name>/
```

Examples:

- `lib/gnat-llvm/x86_64-linux/rts-native`
- `lib/gnat-llvm/wasm32/rts-wasm`
- `lib/gnat-llvm/riscv64-elf/rts-zfp`

This allows multiple targets and runtime variants to coexist under one compiler
installation.
