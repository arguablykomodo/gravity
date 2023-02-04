import { setupControls, viewMatrix } from "./controls.ts";
import { createPipeline, Pipeline, renderPipeline } from "./gl.ts";
import { multiply, scaling } from "./matrix.ts";
import { setupWasm, Wasm } from "./wasm.ts";

const canvas = document.getElementById("canvas") as HTMLCanvasElement;
const gl = canvas.getContext("webgl2")!;
if (gl === null) throw new Error("Browser does not support WebGL");

let wasm: Wasm;
let sizeOfParticle: number;
let sizeOfNode: number;

let particlesPipeline: Pipeline;
let nodesPipeline: Pipeline;

function returnError(ptr: number) {
  const errorBuffer = new Uint8Array(wasm.memory.buffer, ptr);
  let i = 0;
  while (errorBuffer[i] !== 0) i += 1;
  const error = new TextDecoder().decode(errorBuffer.slice(0, i));
  console.log(error);
  alert(error);
}

function returnOk(
  particlesPtr: number,
  particlesLen: number,
  nodesPtr: number,
  nodesLen: number,
) {
  const particles = new DataView(
    wasm.memory.buffer,
    particlesPtr,
    particlesLen * sizeOfParticle,
  );
  gl.bindBuffer(gl.ARRAY_BUFFER, particlesPipeline.buffers.particles);
  gl.bufferData(gl.ARRAY_BUFFER, particles, gl.DYNAMIC_DRAW);
  const nodes = new DataView(
    wasm.memory.buffer,
    nodesPtr,
    nodesLen * sizeOfNode,
  );
  gl.bindBuffer(gl.ARRAY_BUFFER, nodesPipeline.buffers.nodes);
  gl.bufferData(gl.ARRAY_BUFFER, nodes, gl.DYNAMIC_DRAW);

  if (
    canvas.width !== canvas.clientWidth ||
    canvas.height !== canvas.clientHeight
  ) {
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;
    gl.viewport(0, 0, canvas.width, canvas.height);
  }

  const finalMatrix = multiply(
    viewMatrix,
    scaling(canvas.height / canvas.width, 1),
  );

  gl.clear(gl.COLOR_BUFFER_BIT);
  renderPipeline(gl, particlesPipeline, particlesLen, finalMatrix);
  renderPipeline(gl, nodesPipeline, nodesLen, finalMatrix);
  requestAnimationFrame(() => wasm.step(1.0 / 60.0));
}

setupWasm(returnError, returnOk).then(async (w) => {
  wasm = w;
  sizeOfParticle = wasm.sizeOfParticle();
  sizeOfNode = wasm.sizeOfNode();

  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.enable(gl.BLEND);
  gl.clearColor(0.05, 0.05, 0.08, 0);

  const [particleVertex, particleFragment, nodeVertex, nodeFragment] =
    await Promise.all(
      ["particle.vert", "particle.frag", "node.vert", "node.frag"].map((s) =>
        fetch(s).then((r) => r.text())
      ),
    );

  particlesPipeline = createPipeline(
    gl,
    particleVertex,
    particleFragment,
    gl.TRIANGLES,
    6,
    {
      vertices: {
        size: Float32Array.BYTES_PER_ELEMENT * 2,
        divisor: 0,
        attributes: [{ name: "vertex", type: gl.FLOAT, size: 2 }],
      },
      particles: {
        size: sizeOfParticle,
        divisor: 1,
        attributes: [
          { name: "position", type: gl.FLOAT, size: 2 },
          { name: "velocity", type: gl.FLOAT, size: 2 },
          { name: "acceleration", type: gl.FLOAT, size: 2 },
          { name: "mass", type: gl.FLOAT, size: 1 },
        ],
      },
    },
    ["view"],
  );

  gl.bindBuffer(gl.ARRAY_BUFFER, particlesPipeline.buffers.vertices);
  gl.bufferData(
    gl.ARRAY_BUFFER,
    // deno-fmt-ignore
    new Float32Array([
      -1.0, -1.0,
      -1.0, +1.0,
      +1.0, -1.0,
      +1.0, -1.0,
      -1.0, +1.0,
      +1.0, +1.0,
    ]),
    gl.STATIC_DRAW,
  );

  nodesPipeline = createPipeline(
    gl,
    nodeVertex,
    nodeFragment,
    gl.LINE_LOOP,
    4,
    {
      vertices: {
        size: Float32Array.BYTES_PER_ELEMENT * 2,
        divisor: 0,
        attributes: [{ name: "vertex", type: gl.FLOAT, size: 2 }],
      },
      nodes: {
        size: sizeOfNode,
        divisor: 1,
        attributes: [
          { name: "position", type: gl.INT, size: 2 },
          { name: "depth", type: gl.UNSIGNED_INT, size: 1 },
        ],
      },
    },
    ["view", "quadtreeLimits"],
  );
  gl.useProgram(nodesPipeline.program);
  gl.uniform1f(nodesPipeline.uniforms.quadtreeLimits, wasm.quadtreeLimits());

  gl.bindBuffer(gl.ARRAY_BUFFER, nodesPipeline.buffers.vertices);
  gl.bufferData(
    gl.ARRAY_BUFFER,
    // deno-fmt-ignore
    new Float32Array([
      -1.0, -1.0,
      +1.0, -1.0,
      +1.0, +1.0,
      -1.0, +1.0,
    ]),
    gl.STATIC_DRAW,
  );

  setupControls(canvas);

  wasm.init(BigInt(Math.random() * 2 ** 64));
  wasm.step(1.0 / 60.0);
});
