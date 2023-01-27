/**
 * @param {WebGL2RenderingContext} gl
 * @param {GLenum} type
 * @param {string} source
 * @returns {WebGLShader}
 */
function createShader(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  const success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
  if (success) return shader;
  else {
    const message = gl.getShaderInfoLog(shader);
    gl.deleteShader(shader);
    throw new Error(message);
  }
}

/**
 * @param {WebGL2RenderingContext} gl
 * @param {string} vertex
 * @param {string} fragment
 * @returns {WebGLProgram}
 */
export function createProgam(gl, vertex, fragment) {
  const program = gl.createProgram();
  gl.attachShader(program, createShader(gl, gl.VERTEX_SHADER, vertex));
  gl.attachShader(program, createShader(gl, gl.FRAGMENT_SHADER, fragment));
  gl.linkProgram(program);
  const success = gl.getProgramParameter(program, gl.LINK_STATUS);
  if (success) return program;
  else {
    const message = gl.getProgramInfoLog(program);
    gl.deleteProgram(program);
    throw new Error(message);
  }
}

/**
 * @typedef {Object} VertexAttribute
 * @property {string} name
 * @property {number} size
 */

/**
 * @param {WebGL2RenderingContext} gl
 * @param {WebGLProgram} program
 * @param {VertexAttribute[]} attributes
 */
export function createVertexArray(gl, program, attributes) {
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  const totalSize = attributes.reduce((acc, curr) => acc + curr.size, 0);
  let offset = 0;
  for (const attribute of attributes) {
    const location = gl.getAttribLocation(program, attribute.name);
    gl.enableVertexAttribArray(location);
    gl.vertexAttribPointer(
      location,
      attribute.size,
      gl.FLOAT,
      false,
      Float32Array.BYTES_PER_ELEMENT * totalSize,
      Float32Array.BYTES_PER_ELEMENT * offset,
    );
    gl.vertexAttribDivisor(location, 1);
    offset += attribute.size;
  }
  return vao;
}
