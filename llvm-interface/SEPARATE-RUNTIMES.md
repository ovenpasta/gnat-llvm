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

On the frontend side, the current behavior is:

- the host native runtime is found automatically when installed in the default
  structured location
- alternate target runtimes still require an explicit `--RTS=<runtime-root>`

Automatic target-based runtime selection for non-host targets is not
implemented. Doing that would require GCC Ada frontend changes, because
`gnat-llvm` only follows the runtime the frontend has already selected.

The native runtime packaging and build changes described here are contained in
the `gnat-llvm` tree itself. They do not require local GCC source changes.

## Current Verified Runtime

The currently verified packaged runtimes are:

```text
lib/gnat-llvm/x86_64-pc-linux-gnu/rts-native/
lib/gnat-llvm/wasm32/rts-wasm/
```

The host native runtime has been validated without `--RTS`:

```bash
PATH=$PWD/bin:$PATH \
  llvm-gnatmake /tmp/gnatllvm-native-smoke/hello.adb
```

The packaged WebAssembly runtime has been validated with an explicit
`--RTS=`:

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
