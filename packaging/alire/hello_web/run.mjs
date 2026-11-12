//  Node smoke test: load main.wasm with the real adawebpack.mjs glue and
//  call the exported Square_Root (the DOM part needs a browser).
//  Run as: alr exec -- node run.mjs
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

//  Minimal DOM stand-in for the demo's elaboration (Initialize_Demo).
class HTMLButtonElement {
  hidden = false; disabled = true;
  addEventListener(type, cb) {}
}
const element = new HTMLButtonElement();
globalThis.window = { HTMLButtonElement,
                      document: { getElementById: (id) => element } };

const AdaWebPack = await import(pathToFileURL(
  process.env.ADAWEBPACK_ALIRE_PREFIX + '/source/adawebpack.mjs'));
const bytes = readFileSync(new URL('./main.wasm', import.meta.url));
const { instance } =
  await WebAssembly.instantiate(bytes, { env: AdaWebPack.imports });
AdaWebPack.initialize(instance);
console.log('sqrt(25) =', instance.exports.Square_Root(25));
console.log('sqrt(-1) =', instance.exports.Square_Root(-1));
console.log('button enabled by Ada:', element.disabled === false);
