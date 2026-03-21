# Building GNAT-LLVM for WebAssembly

Complete instructions for building the GNAT-LLVM compiler and the WASM
runtime library, then compiling Ada programs targeting WebAssembly.

The compiler-side WebAssembly backend handling is target-conditional. The
runtime build documented here is specifically for the current `wasm32`
runtime package.

## Prerequisites

- **GCC 16** with GNAT (Ada compiler) - used to build the GNAT-LLVM compiler
  itself and provides the `gnat_src` Ada frontend sources
- **LLVM 21 / Clang 21** development libraries and headers (21.1.x required;
  other LLVM versions are **not supported**)
- **gprbuild** - Ada project build tool
- **gprconfig** - gprbuild toolchain configuration tool
- **llvm-ranlib** - LLVM archiver (part of the LLVM toolchain)
- **wasm-ld** - WebAssembly linker (part of the LLVM toolchain)
- Standard build tools: `make`, `gcc`, `g++`

Ensure `llvm-config`, `clang`, and the GNAT tools (`gcc`, `gnatmake`,
`gprbuild`) are all on your `PATH`.

## Toolchain Selection

By default, GNAT-LLVM links against `clangBasic`:

```bash
make build
make wasm
```

If your distro packages Clang as a single `clang-cpp` library instead of the
older split libraries, use:

```bash
make build CLANG_LINK_LIB=clang-cpp
make wasm CLANG_LINK_LIB=clang-cpp
```

That form follows the default `clang` / `llvm-config` on your `PATH`.

For a pinned LLVM install, prefer the explicit versioned tools. On Arch Linux,
the verified setup is LLVM 21 with:

```bash
export PATH=/usr/lib/llvm21/bin:$PATH
```

and explicit `make` overrides:

```bash
make build LLVM_CONFIG=llvm-config-21 CLANG_LINK_LIB=':libclang-cpp.so.21.1'
make wasm LLVM_CONFIG=llvm-config-21 CLANG_LINK_LIB=':libclang-cpp.so.21.1'
```

If the built tools cannot find the LLVM shared libraries at runtime, set
`LD_LIBRARY_PATH` explicitly. For the pinned Arch LLVM 21 setup:

```bash
export LD_LIBRARY_PATH=/usr/lib/llvm21/lib
```

## Directory Layout

```
gnat-llvm/
  llvm-interface/           # Main working directory
    gcc/                    # GCC 16 source tree (contains gcc/ada = GNAT frontend)
    gnat_src -> gcc/gcc/ada # Symlink to GNAT frontend sources
    rts-sources/            # Additional RTS sources (math, memory, etc.)
    bb-runtimes/            # Bare-board runtimes (math sources originate here)
    Makefile                # Main Makefile (compiler + native RTS)
    Makefile.target         # Tracked stub replaced for the AdaWebPack WASM flow
    bin/                    # Built compiler tools (llvm-gcc, llvm-gnat, etc.)
    lib/gnat-llvm/wasm32/
      rts-wasm/        # TLSF runtime - standalone WASM (make wasm)
      rts-wasm-emcc/   # Emscripten runtime (make wasm-emcc)
      target.atp            # Target parameters consumed through --RTS=
      ada_source_path       # Default RTS source path file
      ada_object_path       # Default RTS object path file
      adainclude/           # RTS Ada sources
      adalib/               # Compiled .ali files and libgnat.a
```

## Step 1: Set Up GCC Sources

The GNAT-LLVM compiler uses the GCC 16 Ada frontend sources. Clone or
extract the GCC 16 source tree and create the required symlink:

```bash
cd gnat-llvm/llvm-interface
# If not already present:
# git clone https://gcc.gnu.org/git/gcc.git gcc
git -C gcc apply ../patches/gcc-16-repinfo-accessors.patch
ln -sf gcc/gcc/ada gnat_src
```

The patch adds a small `Repinfo` accessor API used by
`gnatllvm-records-debug.adb`. It is currently required when building
GNAT-LLVM against upstream GCC 16 sources.

## Step 2: Build the GNAT-LLVM Compiler

This builds the `llvm-gcc`, `llvm-gnat1`, `llvm-gnatbind`, and other tools
into the `bin/` directory:

```bash
cd gnat-llvm/llvm-interface
make build
```

Or for an optimized build:

```bash
make build-opt
```

### Arch Linux

The LLVM 21 selection described in `Toolchain Selection` was verified from a
fresh copy of the tree on Arch after installing the full LLVM 21 tool set,
including `llvm-config-21`.

## Step 3: Replace `Makefile.target` for the AdaWebPack WASM Runtime

The `gnat-llvm` tree ships a tracked `Makefile.target` stub for other build
flows. For the AdaWebPack WASM runtime workflow, replace it with the runtime
fragment from `adawebpack_src`:

```bash
cd gnat-llvm/llvm-interface
mv Makefile.target Makefile.target.orig
ln -s adawebpack_src/source/rtl/Makefile.target Makefile.target
```

The build compiles the Ada frontend (from `gnat_src`) against the LLVM
backend. It produces:

- `bin/llvm-gcc` - the main compiler driver
- `bin/llvm-gnat1` - the Ada-to-LLVM code generator
- `bin/llvm-gnatbind` - the Ada binder
- Other tools (`llvm-gnatmake`, `llvm-gnatlink`, etc.)

**Note:** If you modify compiler source files (`gnatllvm-*.adb`/`.ads`),
rebuild with:

```bash
gprbuild -f -Pgnat_llvm -j0 -largs $(llvm-config --libs all --ldflags --system-libs) -cargs:c++ $(llvm-config --cxxflags) -I.
```

The `-f` flag forces a full rebuild, which is sometimes needed when gprbuild
does not detect changes in deeply-nested dependencies.

## Step 3: Build the WASM Runtime (RTS)

This is the core step that builds `libgnat.a` for the current `wasm32`
runtime target:

```bash
cd gnat-llvm/llvm-interface
make wasm
```

If the built tools cannot find the LLVM shared libraries at runtime, set
`LD_LIBRARY_PATH` explicitly when invoking `make`:

```bash
LD_LIBRARY_PATH=/usr/lib make wasm
```

For the pinned Arch LLVM 21 setup, use the same `PATH`, `LLVM_CONFIG`, and
`CLANG_LINK_LIB` selection described in `Toolchain Selection`.

### What `make wasm` does

1. **Copies sources** - Assembles RTS sources into
   `lib/gnat-llvm/wasm32/rts-wasm/adainclude/`
   from three locations:
   - `gnat_src/libgnat/` - upstream GNAT runtime sources
   - the WASM runtime override source tree referenced by `Makefile.target`
   - `rts-sources/` - math library, memory operations, light runtime pieces

2. **Compiles spec-only files** - Certain `.ads` files need to be compiled
   first (the `COMPILABLE_WASM_SPECS` list in `Makefile.target`)

3. **Compiles all bodies** - All `.adb` files in `adainclude/` are compiled
   with `--target=wasm32`

4. **Archives** - All `.o` files are collected into
   `lib/gnat-llvm/wasm32/rts-wasm/adalib/libgnat.a`

5. **Installs runtime metadata** - Places:
   - `lib/gnat-llvm/wasm32/rts-wasm/target.atp`
   - `lib/gnat-llvm/wasm32/rts-wasm/ada_source_path`
   - `lib/gnat-llvm/wasm32/rts-wasm/ada_object_path`

   This lets `--RTS=$(pwd)/lib/gnat-llvm/wasm32/rts-wasm` carry both the
   runtime files and the backend target parameters, so the compiler no longer
   has to rely on `bin/target.atp`.

### Build output

```
lib/gnat-llvm/wasm32/rts-wasm/
  target.atp     # target parameters for the runtime
  ada_source_path
  ada_object_path
  adainclude/    # ~150 Ada source files
  adalib/
    libgnat.a    # Static WASM library (~466 KB)
    *.ali         # Ada Library Information files
```

## Step 4: Use the Packaged Runtime

Consumer projects should use the packaged runtime root directly:

```bash
cd gnat-llvm/llvm-interface
PATH=$(pwd)/bin:$PATH \
  gprbuild --target=llvm \
    --RTS=$(pwd)/lib/gnat-llvm/wasm32/rts-wasm \
    -P your_project.gpr
```

The `--target=llvm` flag tells gprbuild to auto-discover the `llvm-gcc`
compiler on `PATH`. The `--RTS=` flag points to the packaged WASM runtime,
so the binder can find both the `.ali` files in `adalib/` and the
runtime-specific `target.atp`.

This `--RTS=` is currently required for non-host targets such as `wasm32`.
The host native runtime can be used without `--RTS` when installed in the
default structured location under `lib/gnat-llvm/<host-target>/rts-native`.
Automatic target-based runtime selection for non-host targets is not currently
implemented.

**Note:** Using `--config=<file>.cgpr` instead of auto-configuration does
not work for this flow, because gprbuild does not pass the runtime adalib
path to the binder in that mode. Use `--target=llvm --RTS=<path>`.

## Troubleshooting

### `LD_LIBRARY_PATH` errors

If `llvm-gnat1` fails with shared library errors, ensure LLVM libraries are
findable. You can pass `LD_LIBRARY_PATH` directly to the build command:

```bash
LD_LIBRARY_PATH=/usr/lib make build
LD_LIBRARY_PATH=/usr/lib make wasm
```

or export it in the shell:

```bash
export LD_LIBRARY_PATH=/usr/lib  # or wherever libLLVM.so lives
```

### gprbuild says "up to date" after source changes

Force a full rebuild:

```bash
gprbuild -f -Pgnat_llvm -j0 ...
```

### `Assert_Failure sem_ch12.adb:18668`

This is a known GNAT-LLVM compiler bug triggered by `Big_Integers_Ghost`
ghost generics. The affected files have been removed from the WASM RTS build.
See `PORTING-GCC16.md` for details.

### `WebAssembly hasn't implemented nest arguments`

This error occurs if the `nest` attribute fix has not been applied to
`gnatllvm-instructions.adb` and `gnatllvm-subprograms.adb`. The LLVM `nest`
attribute requires trampoline support, which WASM lacks. The fix skips the
attribute when explicit activation-record parameter handling is in use for
the active WebAssembly target. See `PORTING-GCC16.md` for the specific
changes.

### `Incorrect number of arguments passed to called function` for `__finalizer`

This error occurs if the `Push_Block` fix has not been applied to
`gnatllvm-blocks.adb`. On WASM, every non-foreign function gets an activation
record parameter, but `Push_Block` was not passing one for `__finalizer`
procedures without uplevel references. See `PORTING-GCC16.md` for details.

### Style errors (`-gnatyz`) in math sources

Math sources from `rts-sources/math/` use `abs (X)` which triggers redundant
parentheses warnings under `-gnatyz`. The local copies have been fixed to
`abs X`. If you update from upstream, reapply these fixes.

## References

- `PORTING-GCC16.md` - GNAT-LLVM compiler-side GCC 16 porting notes
- `SEPARATE-RUNTIMES.md` - Separate runtime packaging and `--RTS=` support
- `Makefile.target` - WASM RTS build rules and file lists
