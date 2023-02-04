import { Matrix } from "./matrix.ts";

function createShader(
  gl: WebGL2RenderingContext,
  type: GLenum,
  source: string,
): WebGLShader {
  const shader = gl.createShader(type);
  if (shader === null) throw new Error("Couldn't create shader");
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  const success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
  if (success) return shader;
  else {
    const message = gl.getShaderInfoLog(shader);
    gl.deleteShader(shader);
    throw new Error(message ?? "Error compiling shader");
  }
}

function createProgam(
  gl: WebGL2RenderingContext,
  vertex: string,
  fragment: string,
): WebGLProgram {
  const program = gl.createProgram();
  if (program === null) throw new Error("Couldn't create program");
  gl.attachShader(program, createShader(gl, gl.VERTEX_SHADER, vertex));
  gl.attachShader(program, createShader(gl, gl.FRAGMENT_SHADER, fragment));
  gl.linkProgram(program);
  const success = gl.getProgramParameter(program, gl.LINK_STATUS);
  if (success) return program;
  else {
    const message = gl.getProgramInfoLog(program);
    gl.deleteProgram(program);
    throw new Error(message ?? "Error linking program");
  }
}

const sizes: Map<GLenum, { size: number; int: boolean }> = new Map([
  [WebGL2RenderingContext.BYTE, { size: 1, int: true }],
  [WebGL2RenderingContext.SHORT, { size: 2, int: true }],
  [WebGL2RenderingContext.UNSIGNED_BYTE, { size: 1, int: true }],
  [WebGL2RenderingContext.UNSIGNED_SHORT, { size: 2, int: true }],
  [WebGL2RenderingContext.FLOAT, { size: 4, int: false }],
  [WebGL2RenderingContext.HALF_FLOAT, { size: 2, int: false }],
  [WebGL2RenderingContext.INT, { size: 4, int: true }],
  [WebGL2RenderingContext.UNSIGNED_INT, { size: 4, int: true }],
  [WebGL2RenderingContext.INT_2_10_10_10_REV, { size: 4, int: true }],
  [WebGL2RenderingContext.UNSIGNED_INT_2_10_10_10_REV, { size: 4, int: true }],
]);

interface VertexAttribute {
  name: string;
  type: GLenum;
  size: number;
}

interface BufferStruct {
  size: number;
  divisor: number;
  attributes: VertexAttribute[];
}

function createBuffer(
  gl: WebGL2RenderingContext,
  program: WebGLProgram,
  struct: BufferStruct,
): WebGLBuffer {
  const buffer = gl.createBuffer();
  if (buffer === null) throw new Error("Couldn't create buffer");
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);

  let offset = 0;
  for (const attr of struct.attributes) {
    const { size, int } = sizes.get(attr.type) ?? { size: 0, int: false };
    const location = gl.getAttribLocation(program, attr.name);
    if (location === -1) throw new Error(`${attr.name} attribute not found`);
    gl.enableVertexAttribArray(location);
    if (int) {
      gl.vertexAttribIPointer(
        location,
        attr.size,
        attr.type,
        struct.size,
        offset,
      );
    } else {
      gl.vertexAttribPointer(
        location,
        attr.size,
        attr.type,
        false,
        struct.size,
        offset,
      );
    }
    gl.vertexAttribDivisor(location, struct.divisor);
    offset += size * attr.size;
  }

  return buffer;
}

export interface Pipeline {
  program: WebGLProgram;
  vao: WebGLVertexArrayObject;
  mode: GLenum;
  vertexCount: number;
  buffers: Record<string, WebGLBuffer>;
  uniforms: Record<string, WebGLUniformLocation>;
}

export function createPipeline(
  gl: WebGL2RenderingContext,
  vertex: string,
  fragment: string,
  mode: GLenum,
  vertexCount: number,
  buffers: Record<string, BufferStruct>,
  uniforms: string[],
): Pipeline {
  const program = createProgam(gl, vertex, fragment);
  const vao = gl.createVertexArray();
  if (vao === null) throw new Error("Couldn't create vertex array object");
  gl.bindVertexArray(vao);
  const pipeline: Pipeline = {
    program,
    vao,
    mode,
    vertexCount,
    buffers: {},
    uniforms: {},
  };
  for (const [name, buffer] of Object.entries(buffers)) {
    pipeline.buffers[name] = createBuffer(gl, program, buffer);
  }
  for (const name of uniforms) {
    const uniform = gl.getUniformLocation(program, name);
    if (uniform === null) throw new Error(`${name} uniform not found`);
    pipeline.uniforms[name] = uniform;
  }
  return pipeline;
}

export function renderPipeline(
  gl: WebGL2RenderingContext,
  pipeline: Pipeline,
  count: number,
  view: Matrix,
): void {
  gl.useProgram(pipeline.program);
  gl.bindVertexArray(pipeline.vao);
  gl.uniformMatrix3fv(pipeline.uniforms.view, false, view);
  gl.drawArraysInstanced(pipeline.mode, 0, pipeline.vertexCount, count);
}
