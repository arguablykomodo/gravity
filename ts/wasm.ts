export interface Wasm {
  memory: WebAssembly.Memory;
  sizeOfParticle: WebAssembly.Global;
  sizeOfNode: WebAssembly.Global;
  init(scale: number, bigG: number, theta: number): void;
  setParameters(bigG: number, theta: number): void;
  deinit(): void;
  insert(x: number, y: number, vx: number, vy: number, mass: number): void;
  step(dt: number): void;
  getParticles(): void;
  getNodes(): void;
}

export async function setupWasm(
  returnError: (ptr: number) => void,
  returnParticles: (ptr: number, len: number) => void,
  returnNodes: (ptr: number, len: number) => void,
): Promise<Wasm> {
  const request = fetch("gravity.wasm");
  const imports = { env: { returnError, returnParticles, returnNodes } };
  const instance = await WebAssembly.instantiateStreaming(request, imports);
  return instance.instance.exports as unknown as Wasm;
}
