# Alire packaging for GNAT-LLVM

Users: add the index and see its README for usage,

    alr index --add git+https://github.com/ovenpasta/alire-index-gnat-llvm --name gnat_llvm

Two crates make GNAT-LLVM usable from Alire:

- `gnat_llvm` - binary toolchain crate (provides `gnat=16.1.0`): the
  compiler, the native and all wasm32 runtimes, and (in release builds) a
  bundled static `clang` / `wasm-ld`. Defined here.
- `adawebpack` - source crate with the Web API bindings; its manifest is
  `alire.toml` at the root of the adawebpack repository. It depends on
  `gnat_llvm` and selects the runtime.

## Files

- `make-dist.sh` - stage `llvm-interface/bin/llvm-*` and
  `llvm-interface/lib/gnat-llvm` (minus `obj-static`, symlinks
  dereferenced) into `out/gnat_llvm-<ver>-<arch>-<os>.tar.gz`, write the
  platform's manifest `[origin]` block, and generate an index in
  `out/index` (with a `file://` URL unless `URL_BASE` is set).
  `LLVM_PREFIX=...` also bundles clang, lld and llvm-ar.
- `make-manifest.sh` - merge the template and one origin block per
  platform into the crate manifest (used by the release workflow).
- `gnat_llvm.toml.in` - toolchain crate manifest template.
- `hello_wasm/` - crate depending on `gnat_llvm` only, standalone
  `rts-wasm-eh`; `node run.mjs` prints and raises/catches an exception.
- `hello_web/` - crate depending on `adawebpack` (path pin to the in-tree
  checkout); `alr exec -- node run.mjs` runs it with the real
  `adawebpack.mjs` glue and a minimal DOM stand-in.
- `../ci/build-llvm.sh`, `../ci/build-toolchain.sh` and
  `../../.github/workflows/release.yml` - release builds, see below.

## Selecting a runtime

With adawebpack, the application sets the scenario variable in its
`alire.toml`:

```toml
[gpr-set-externals]
ADAWEBPACK_RUNTIME = "wasm-eh"   # wasm, wasm-eh, wasm-emcc, wasm-emcc-eh,
                                 # wasm-wasi-eh, and *-exnref EH variants
```

and takes target, runtime, compiler and linker switches from
`adawebpack.gpr`:

```ada
with "adawebpack.gpr";
project App is
   for Target use AdaWebPack'Target;
   for Runtime ("Ada") use AdaWebPack'Runtime ("Ada");
   package Compiler renames AdaWebPack.Compiler;
   package Binder is
      for Switches ("Ada") use ("-z");
   end Binder;
   package Linker is
      for Switches ("Ada") use AdaWebPack.Linker_Switches;
   end Linker;
end App;
```

The `*-exnref` runtimes also need `GNAT_WASM_EH=exnref` for the compiler:

```toml
[environment]
GNAT_WASM_EH.set = "exnref"
```

Linker switches are only provided for the standalone runtimes; emcc and
WASI applications are linked by `emcc` / `wasm-ld` after `gprbuild -c -b`.

Without adawebpack, use the `GNAT_LLVM_PREFIX` variable the toolchain
crate exports:

```ada
for Target use "llvm";
for Runtime ("Ada") use
  external ("GNAT_LLVM_PREFIX") & "/lib/gnat-llvm/wasm32/rts-wasm-eh";
```

Selecting a runtime by bare name (`"rts-wasm-eh"`) does not work: gprconfig
does not search the toolchain's `lib/gnat-llvm/wasm32` directory.

## Local test

```sh
./make-dist.sh
alr index --add "$PWD/out/index" --name gnat_llvm_local
cd hello_wasm && alr build && node run.mjs
cd ../hello_web && alr build && alr exec -- node run.mjs
alr build -- -XADAWEBPACK_RUNTIME=wasm      # other runtimes
```

Alire installs a toolchain once per version, under a directory named after
the tarball hash. After regenerating the tarball with the same version,
delete `~/.local/share/alire/toolchains/gnat_llvm_<version>_*` and the
crate's `alire/` directory so `alr build` deploys the new one.

Remove the local index with `alr index --del gnat_llvm_local`.

The locally built tarball links the host's shared `libLLVM` /
`libclang-cpp` (and icu, libxml2, ...), so it only works on the build
machine.

## Release builds

`.github/workflows/release.yml` runs on a `v*` tag (or manually) on
`ubuntu-22.04` (x86_64) and `ubuntu-22.04-arm` (aarch64):

1. GNAT 15.2 and gprbuild from GNAT-FSF-builds (the binaries behind
   Alire's `gnat_native` / `gprbuild`; glibc 2.35 baseline, so the
   toolchain runs wherever Alire's own GNAT does).
2. `build-llvm.sh`: LLVM 21 + clang + lld, static, host + WebAssembly
   targets, no zlib/zstd/libxml2/terminfo; cached between runs.
3. `build-toolchain.sh sources compiler wasm`: GCC 16.1.0 + local patches,
   llvm-bindings, adawebpack and bb-runtimes; the Production compiler
   linked statically against LLVM; the native runtime; all wasm32 runtimes
   (legacy and exnref) with emsdk 5.0.2 and wasi-sysroot 34.
4. `make-dist.sh` with the bundled LLVM tools and the release URL, then a
   wasm32 and a native smoke test.
5. The release job merges the per-platform origin blocks into
   `gnat_llvm-16.1.0.toml` and creates a draft GitHub release with the
   tarballs and the manifest.

After publishing the draft release, add its `gnat_llvm-<version>.toml` to
https://github.com/ovenpasta/alire-index-gnat-llvm under
`index/gn/gnat_llvm/`. Bump `CRATE_VERSION` in the workflow for every new
toolchain build (the last digit counts builds of the same GCC release).

The runtimes are built from the pushed adawebpack branch, not the local
checkout: push local adawebpack changes before tagging.
