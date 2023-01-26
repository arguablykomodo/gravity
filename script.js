import { createProgam, createShader, createVertexArray } from "./gl.js";

/** @type {HTMLCanvasElement} */
const canvas = document.getElementById("canvas");

const timestep = 1 / 60;

const { instance: { exports } } = await WebAssembly.instantiateStreaming(
  fetch("main.wasm"),
  { env: { bufferParticles } },
);

canvas.width = 1024;
canvas.height = 1024;

const gl = canvas.getContext("webgl2");
if (!gl) alert("Your browser does not support WebGL :(");

const vertexShader = createShader(
  gl,
  gl.VERTEX_SHADER,
  await fetch("vertex.glsl").then((r) => r.text()),
);
const fragmentShader = createShader(
  gl,
  gl.FRAGMENT_SHADER,
  await fetch("fragment.glsl").then((r) => r.text()),
);
const program = createProgam(gl, vertexShader, fragmentShader);

const buffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, buffer);

const vao = createVertexArray(gl, program, [
  { name: "position", size: 2 },
  { name: "velocity", size: 2 },
  { name: "mass", size: 1 },
]);

gl.useProgram(program);
gl.bindVertexArray(vao);

gl.viewport(0, 0, canvas.width, canvas.height);
gl.clearColor(0, 0, 0, 0);
gl.clear(gl.COLOR_BUFFER_BIT);

/**
 * @param {number} ptr
 * @param {number} len
 */
function bufferParticles(ptr, len) {
  const particles = new Float32Array(exports.memory.buffer, ptr, len * Float32Array.BYTES_PER_ELEMENT * 5);
  gl.bufferData(gl.ARRAY_BUFFER, particles, gl.DYNAMIC_DRAW);
  gl.drawArrays(gl.POINTS, 0, len);
  requestAnimationFrame(() => exports.update(timestep));
}

exports.setup();
exports.update(timestep);
