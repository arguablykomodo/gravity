import { setupControls, viewMatrix } from "./controls.ts";
import { createPipeline, Pipeline, renderPipeline } from "./gl.ts";
import { multiply, scaling } from "./matrix.ts";
import { setupWasm, Wasm } from "./wasm.ts";

const canvas = document.getElementById("canvas") as HTMLCanvasElement;

const bigGInput = document.getElementById("bigG") as HTMLInputElement;
const thetaInput = document.getElementById("theta") as HTMLInputElement;
const dtInput = document.getElementById("dt") as HTMLInputElement;
const drawParticlesInput = document.getElementById(
  "drawParticles",
) as HTMLInputElement;
const drawQuadtreeInput = document.getElementById(
  "drawQuadtree",
) as HTMLInputElement;
const scaleInput = document.getElementById("scale") as HTMLInputElement;
const particlesInput = document.getElementById("particles") as HTMLInputElement;
const particleMassInput = document.getElementById("particleMass") as HTMLInputElement;
const spreadInput = document.getElementById("spread") as HTMLInputElement;
const speedInput = document.getElementById("speed") as HTMLInputElement;
const angularSpeedInput = document.getElementById("angularSpeed") as HTMLInputElement;
const restartButton = document.getElementById("restart") as HTMLButtonElement;

const gl = canvas.getContext("webgl2")!;
if (gl === null) throw new Error("Browser does not support WebGL");

let wasm: Wasm;

function returnError(ptr: number) {
  const errorBuffer = new Uint8Array(wasm.memory.buffer, ptr);
  let i = 0;
  while (errorBuffer[i] !== 0) i += 1;
  const error = new TextDecoder().decode(errorBuffer.slice(0, i));
  console.error(error);
  alert(error);
}

let particlesPipeline: Pipeline;
let sizeOfParticle: number;
let particleCount: number;
function returnParticles(ptr: number, len: number) {
  particleCount = len;
  const particles = new DataView(wasm.memory.buffer, ptr, len * sizeOfParticle);
  gl.bindBuffer(gl.ARRAY_BUFFER, particlesPipeline.buffers.particles);
  gl.bufferData(gl.ARRAY_BUFFER, particles, gl.DYNAMIC_DRAW);
}

let nodesPipeline: Pipeline;
let sizeOfNode: number;
let nodeCount: number;
function returnNodes(ptr: number, len: number) {
  nodeCount = len;
  const nodes = new DataView(wasm.memory.buffer, ptr, len * sizeOfNode);
  gl.bindBuffer(gl.ARRAY_BUFFER, nodesPipeline.buffers.nodes);
  gl.bufferData(gl.ARRAY_BUFFER, nodes, gl.DYNAMIC_DRAW);
}

setupWasm(returnError, returnParticles, returnNodes).then(async (w) => {
  wasm = w;

  const globalView = new DataView(wasm.memory.buffer);
  sizeOfParticle = globalView.getUint32(wasm.sizeOfParticle.value, true);
  sizeOfNode = globalView.getUint32(wasm.sizeOfNode.value, true);

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

  gl.useProgram(particlesPipeline.program);
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
    gl.TRIANGLES,
    6,
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
          { name: "center", type: gl.FLOAT, size: 2 },
          { name: "radius", type: gl.FLOAT, size: 1 },
          { name: "totalMass", type: gl.FLOAT, size: 1 },
          { name: "weightedSum", type: gl.FLOAT, size: 2 },
        ],
      },
    },
    ["view", "scale"],
  );

  gl.useProgram(nodesPipeline.program);
  gl.bindBuffer(gl.ARRAY_BUFFER, nodesPipeline.buffers.vertices);
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

  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.enable(gl.BLEND);
  gl.clearColor(0.05, 0.05, 0.08, 1.0);

  setupControls(canvas);
  init();
  step();
});

function init() {
  gl.useProgram(nodesPipeline.program);
  gl.uniform1f(nodesPipeline.uniforms.scale, scaleInput.valueAsNumber);
  wasm.init(
    scaleInput.valueAsNumber,
    bigGInput.valueAsNumber,
    thetaInput.valueAsNumber,
  );
  for (let i = 0; i < particlesInput.valueAsNumber; i++) {
    const r = Math.random() * spreadInput.valueAsNumber;
    const a = Math.random() * Math.PI * 2.0;
    const angular = a + Math.PI / 2.0;
    wasm.insert(
      Math.cos(a) * r,
      Math.sin(a) * r,
      (Math.random() * 2.0 - 1.0) * speedInput.valueAsNumber + Math.cos(angular) * r / spreadInput.valueAsNumber * angularSpeedInput.valueAsNumber,
      (Math.random() * 2.0 - 1.0) * speedInput.valueAsNumber + Math.sin(angular) * r / spreadInput.valueAsNumber * angularSpeedInput.valueAsNumber,
      particleMassInput.valueAsNumber,
    );
  }
}

function step() {
  wasm.step(dtInput.valueAsNumber);

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
  if (drawQuadtreeInput.checked) {
    wasm.getNodes();
    renderPipeline(gl, nodesPipeline, nodeCount, finalMatrix);
  }
  if (drawParticlesInput.checked) {
    wasm.getParticles();
    renderPipeline(gl, particlesPipeline, particleCount, finalMatrix);
  }
  requestAnimationFrame(step);
}

function setParameters() {
  wasm.setParameters(bigGInput.valueAsNumber, thetaInput.valueAsNumber);
}

bigGInput.addEventListener("change", setParameters);
thetaInput.addEventListener("change", setParameters);

restartButton.addEventListener("click", () => {
  wasm.deinit();
  init();
});
