import { createProgam, createShader, createVertexArray } from "./gl.js";

/** @type {HTMLCanvasElement} */
const canvas = document.getElementById("canvas");

const { instance: { exports } } = await WebAssembly.instantiateStreaming(
  fetch("main.wasm"),
  { env: { print: console.log } },
);
console.log(exports);

const particles = new Float32Array(
  exports.memory.buffer,
  exports.setup(),
  5 * 3,
);

canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

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

function draw() {
  exports.update(1 / 60);
  gl.bufferData(gl.ARRAY_BUFFER, particles, gl.DYNAMIC_DRAW);
  gl.drawArrays(gl.POINTS, 0, 3);
  requestAnimationFrame(draw);
}
requestAnimationFrame(draw);
