/**
 * @param {WebGL2RenderingContext} gl
 * @param {GLenum} type
 * @param {string} source
 * @returns {WebGLShader}
 */
export function createShader(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  const success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
  if (success) return shader;
  console.error(gl.getShaderInfoLog(shader));
  gl.deleteShader(shader);
}

/**
 * @param {WebGL2RenderingContext} gl
 * @param {WebGLShader} vertexShader
 * @param {WebGLShader} fragmentShader
 * @returns {WebGLProgram}
 */
export function createProgam(gl, vertexShader, fragmentShader) {
  const program = gl.createProgram();
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  const success = gl.getProgramParameter(program, gl.LINK_STATUS);
  if (success) return program;
  console.error(gl.getProgramInfoLog(program));
  gl.deleteProgram(program);
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
    offset += attribute.size;
  }
  return vao;
}
