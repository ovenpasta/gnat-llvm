GNAT LLVM
=========

This is an Ada compiler based on LLVM, connecting the GNAT front-end to the
LLVM code generator to generate LLVM bitcode for Ada and to open the LLVM
ecosystem to Ada.

Note that we are not planning on replacing any existing GNAT port that's
based on GCC: this project is meant to provide additional, not replacement,
GNAT ports.

You are welcome to experiment with this technology and provide
feedback on successes, usages, limitations, pull requests, etc.

- For more information on LLVM, see [llvm.org](https://llvm.org).
- For more information on GNAT, see [adacore.com](https://www.adacore.com).

Building
--------

To build GNAT LLVM from sources, follow these steps:

- First do a checkout of this repository and go to this directory:

      git clone https://github.com/AdaCore/gnat-llvm.git
      cd gnat-llvm

- Then obtain a checkout of GCC under the llvm-interface directory:

      git clone https://github.com/gcc-mirror/gcc.git llvm-interface/gcc

  GNAT-LLVM currently needs a small GCC 15 `Repinfo` accessor patch. Apply:

      git -C llvm-interface/gcc apply ../patches/gcc-15-repinfo-accessors.patch

  then under non Windows systems:

      ln -s gcc/gcc/ada llvm-interface/gnat_src

  under Windows systems:

      mv llvm-interface/gcc/gcc/ada llvm-interface/gnat_src

- Obtain the Ada bindings for LLVM:

      git clone https://github.com/AdaCore/llvm-bindings.git

  Note that there's no need to regenerate the bindings unless you change LLVM.

- Install (and put in your PATH) a recent GNAT.

- Install **LLVM 21** and **Clang 21** (21.1.x recommended)

  GNAT-LLVM requires LLVM 21 specifically - other versions (19, 20, 22, etc.)
  are **not supported** and will fail to build.

  The recommended way to install is via your distribution's LLVM 21 packages
  (e.g. `llvm21`, `clang21` on Arch Linux, or `llvm-21-dev`, `libclang-21-dev`
  on Debian/Ubuntu) or `brew install llvm@21` on macOS. You can also build
  LLVM 21 yourself with the options that suit your needs. You may want to use
  the lightly patched version that we maintain at
  https://github.com/AdaCore/llvm-project. After installing/building, make
  sure the LLVM 21 bin directory containing `llvm-config` and `clang` is in
  your `PATH`.

  Alternatively, you can invoke make with an environment variable named 
  `LLVM_CONFIG` pointing to your `llvm-config` binary, this way the LLVM you
  intend to use does not need to be in your `PATH`.

      make LLVM_CONFIG=/some/path/to/llvm-config

  An alternative only suitable for core GNAT LLVM development on x86 native
  configurations is to use the following command, assuming you have CMake
  version >= 3.20 in your path:

      make llvm

  Note that there's currently a bug in LLVM's aliasing handling. We check for it
  and generate slightly pessimized code in that case, but a patch to be applied
  to LLVM's `lib/Analyze` directory is in the file
  `llvm/patches/LLVMStructTBAAPatch.diff`; our LLVM repository mentioned above
  already contains this patch.

- Finally build GNAT LLVM:

      make

  On systems where the Clang C++ API is packaged as `clang-cpp` rather than
  `clangBasic` (for example Arch Linux), use:

      make CLANG_LINK_LIB=clang-cpp

  If the built tools cannot locate LLVM shared libraries at runtime, pass
  `LD_LIBRARY_PATH` when invoking `make`:

      LD_LIBRARY_PATH=/usr/lib make

  If you build with an Alire-provided GNAT toolchain, remember that
  `llvm-interface/default.cgpr` can lock in whatever Ada/C/C++ drivers were
  detected when it was generated. If you need to switch toolchains, remove
  that file and rebuild.

  On some Linux distributions, Alire's linker selection may fail while
  linking against the LLVM/Clang static libraries. In that case, force `lld`
  instead of symlinking `ld`:

      rm -f llvm-interface/default.cgpr
      make CXXFLAGS=-fuse-ld=lld

  This creates a "ready to use" set of directories "bin" and "lib" under
  llvm-interface which you can put in your PATH:

    PATH=$PWD/llvm-interface/bin:$PATH

- If you want in addition to generate bitcode for the GNAT runtime, you can do:

      make gnatlib-bc

  This will generate `libgnat.bc` and `libgnarl.bc` in the `adalib` directory, along
  with `libgnat.a` and `libgnarl.a`.

Additional docs
---------------

- GCC 15 compiler migration notes: [llvm-interface/PORTING-GCC15.md](llvm-interface/PORTING-GCC15.md)
- Separate runtime packaging support: [llvm-interface/SEPARATE-RUNTIMES.md](llvm-interface/SEPARATE-RUNTIMES.md)
- WebAssembly runtime build workflow: [llvm-interface/BUILD-WASM.md](llvm-interface/BUILD-WASM.md)

Targets and Runtimes
--------------------

GNAT-LLVM supports several targets and runtime configurations.
All runtimes are installed under `llvm-interface/` after building.

| Target              | Make command                    | Output path                                  |
|---------------------|---------------------------------|----------------------------------------------|
| Native              | `make`                          | `lib/gnat-llvm/<triple>/rts-native/`         |
| ZFP                 | `make zfp`                      | `lib/gnat-llvm/<triple>/rts-zfp/`            |
| WASM standalone     | `make wasm`                     | `lib/gnat-llvm/wasm32/rts-wasm/`             |
| WASM Emscripten     | `make wasm-emcc`                | `lib/gnat-llvm/wasm32/rts-wasm-emcc/`        |
| CCG                 | `make ccg`                      | `lib/gnat-llvm/<triple>/rts-ccg/`            |
| LLVM bitcode        | `make gnatlib-bc`               | `.bc` files alongside native `adalib/`       |
| SymCC               | `make gnatlib-symcc-automated`  | `lib/gnat-llvm/<triple>/rts-native/`         |

**Native** is built by default and is auto-detected by the compiler.

**ZFP** (Zero Footprint Profile) targets bare-metal environments with no OS
support, tasking, or exceptions.

**WASM** builds require AdaWebPack (https://github.com/ovenpasta/adawebpack,
branch `gcc-15-wasm-rts`), a separate repository checked out as
`llvm-interface/adawebpack_src/`. Two runtimes are provided: standalone TLSF
(`rts-wasm`) and Emscripten-delegating (`rts-wasm-emcc`). Select a runtime
with `--RTS=`; see [llvm-interface/BUILD-WASM.md](llvm-interface/BUILD-WASM.md)
for details.

**CCG** (C Code Generator) translates Ada to C via LLVM IR. Activate with
the `CCG=1` environment variable, or name the compiler binary `c-*` (e.g.
`c-llvm-gnat1`). On success, produces a `.c` file instead of a `.o` file.
The `rts-ccg` runtime is a copy of `rts-native` compiled for CCG use.

**gnatlib-bc** builds the native runtime as LLVM bitcode, useful for
link-time optimization and program analysis.

**SymCC** builds the native runtime instrumented for symbolic execution.
Requires `libsymcc` from the SymCC project.

Usage
-----

- To run the compiler and produce a native object file:

      llvm-gcc -c file.adb

- To debug the compiler:

      gdb -args llvm-gnat1 -c file.adb

- To build a complete native executable:

      llvm-gnatmake main.adb

- To build a whole project:

      gprbuild -Pprj ...

- To generate LLVM bitcode (will generate a .bc file):

      llvm-gcc -c -emit-llvm file.adb

- To generate LLVM assembly (will generate a .ll file):

      llvm-gcc -c -S -emit-llvm file.adb

- To generate native assembly file (will generate a .s file):

      llvm-gcc -S file.adb

- To generate C code via CCG (will produce a .c file):

      CCG=1 llvm-gcc -c file.adb

License
-------

The GNAT LLVM tool is licensed under the GNU General Public License version 3
or later; see file `COPYING3` for details.
