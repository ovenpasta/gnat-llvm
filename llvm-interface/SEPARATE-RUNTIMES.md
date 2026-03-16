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

## Current Verified Runtimes

The currently verified packaged runtimes are:

```text
lib/gnat-llvm/x86_64-pc-linux-gnu/rts-native/
lib/gnat-llvm/wasm32/rts-wasm/
lib/gnat-llvm/wasm32/rts-wasm-emcc/
```

The host native runtime has been validated without `--RTS`:

```bash
PATH=$PWD/bin:$PATH \
  llvm-gnatmake /tmp/gnatllvm-native-smoke/hello.adb
```

Two WebAssembly runtimes are packaged:

- `rts-wasm` - standalone WASM with Ada's built-in TLSF allocator. Ada owns
  `malloc`/`free`/`realloc`. Good for targets without Emscripten.
- `rts-wasm-emcc` - delegates all allocation to Emscripten's dlmalloc.
  Ada does not export `malloc`/`free`. Required when linking with Emscripten
  to avoid WASM function-table index conflicts.

Both have been validated with:

```bash
make wasm
make -o build wasm-emcc

PATH=$PWD/bin:$PATH gprbuild --target=llvm \
  --RTS=$PWD/lib/gnat-llvm/wasm32/rts-wasm -P your_project.gpr

PATH=$PWD/bin:$PATH gprbuild --target=llvm \
  --RTS=$PWD/lib/gnat-llvm/wasm32/rts-wasm-emcc -P your_project.gpr
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
