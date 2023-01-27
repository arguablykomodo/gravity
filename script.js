import { createProgam, createVertexArray } from "./gl.js";

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

const program = createProgam(
  gl,
  ...await Promise.all(
    ["vertex.glsl", "fragment.glsl"].map((u) => fetch(u).then((r) => r.text())),
  ),
);

const particleBuffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, particleBuffer);

const vao = createVertexArray(gl, program, [
  { name: "position", size: 2 },
  { name: "velocity", size: 2 },
  { name: "mass", size: 1 },
]);

const vertexBuffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
  -1.0, -1.0,
  -1.0, +1.0,
  +1.0, -1.0,
  +1.0, -1.0,
  -1.0, +1.0,
  +1.0, +1.0,
]), gl.STATIC_DRAW);

const vertexLocation = gl.getAttribLocation(program, "vertex");
gl.enableVertexAttribArray(vertexLocation);
gl.vertexAttribPointer(vertexLocation, 2, gl.FLOAT, false, 0, 0);

gl.useProgram(program);
gl.bindVertexArray(vao);
gl.bindBuffer(gl.ARRAY_BUFFER, particleBuffer);

gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
gl.enable(gl.BLEND);

gl.viewport(0, 0, canvas.width, canvas.height);
gl.clearColor(0, 0, 0, 0);
gl.clear(gl.COLOR_BUFFER_BIT);

/**
 * @param {number} ptr
 * @param {number} len
 */
function bufferParticles(ptr, len) {
  const particles = new Float32Array(
    exports.memory.buffer,
    ptr,
    len * Float32Array.BYTES_PER_ELEMENT * 5,
  );
  gl.bufferData(gl.ARRAY_BUFFER, particles, gl.DYNAMIC_DRAW);
  gl.drawArraysInstanced(gl.TRIANGLES, 0, 6, len);
  requestAnimationFrame(() => exports.update(timestep));
}

exports.setup();
exports.update(timestep);
