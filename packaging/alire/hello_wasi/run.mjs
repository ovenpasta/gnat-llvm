//  Run a WASI program under node:wasi with the current directory preopened:
//    node run.mjs bin/hello_wasi.wasm [args...]
import { readFileSync } from 'node:fs';
import { WASI } from 'node:wasi';

const [file, ...args] = process.argv.slice(2);
const wasi = new WASI({
  version: 'preview1',
  args: [file, ...args],
  env: process.env,
  preopens: { '.': '.' },
  returnOnExit: true,
});
const { instance } = await WebAssembly.instantiate(
  readFileSync(file), wasi.getImportObject());
process.exitCode = wasi.start(instance);
