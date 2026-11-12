//  Run bin/hello.wasm under node (standalone rts-wasm-eh imports)
import { readFileSync } from 'node:fs';
const bytes = readFileSync(new URL('./bin/hello.wasm', import.meta.url));
let instance;
const dec = new TextDecoder();
const str = (a, n) =>
  dec.decode(new Uint8Array(instance.exports.memory.buffer, a, n));
const env = {
  __gnat_grow: (size) => instance.exports.memory.grow(size),
  __gnat_fill_arg: () => {},
  __gnat_len_arg: () => 0,
  __gnat_get_executable_load_address: () => 0,
  fputc: (c) => { process.stderr.write(String.fromCharCode(c)); return c; },
  __gnat_put_char:   (c)    => process.stdout.write(String.fromCharCode(c)),
  __gnat_put_string: (a, n) => process.stdout.write(str(a, n)),
  __gnat_put_int:    (i)    => process.stdout.write(String(i)),
};
({ instance } = await WebAssembly.instantiate(bytes, { env }));
instance.exports.__gnat_initialize(0);
instance.exports.adainit();
instance.exports._ada_hello();
