export interface Wasm {
  memory: WebAssembly.Memory;
  sizeOfParticle(): number;
  sizeOfNode(): number;
  init(scale: number, gravitationalConstant: number, theta: number): void;
  deinit(): void;
  insert(x: number, y: number, vx: number, vy: number, mass: number): void;
  step(dt: number): void;
}

export async function setupWasm(
  returnError: (ptr: number) => void,
  returnOk: (
    particlesPtr: number,
    particlesLen: number,
    nodesPtr: number,
    nodesLen: number,
  ) => void,
): Promise<Wasm> {
  const request = fetch("gravity.wasm");
  const imports = { env: { returnError, returnOk } };
  const instance = await WebAssembly.instantiateStreaming(request, imports);
  return instance.instance.exports as unknown as Wasm;
}
