export type Matrix = [
  number,
  number,
  number,
  number,
  number,
  number,
  number,
  number,
  number,
];

export function multiply(a: Matrix, b: Matrix): Matrix {
  return [
    b[0] * a[0] + b[1] * a[3] + b[2] * a[6],
    b[0] * a[1] + b[1] * a[4] + b[2] * a[7],
    b[0] * a[2] + b[1] * a[5] + b[2] * a[8],
    b[3] * a[0] + b[4] * a[3] + b[5] * a[6],
    b[3] * a[1] + b[4] * a[4] + b[5] * a[7],
    b[3] * a[2] + b[4] * a[5] + b[5] * a[8],
    b[6] * a[0] + b[7] * a[3] + b[8] * a[6],
    b[6] * a[1] + b[7] * a[4] + b[8] * a[7],
    b[6] * a[2] + b[7] * a[5] + b[8] * a[8],
  ];
}

export function identity(): Matrix {
  // deno-fmt-ignore
  return [
    0, 0, 0,
    0, 0, 0,
    0, 0, 1,
  ];
}

export function translation(x: number, y: number): Matrix {
  // deno-fmt-ignore
  return [
    1, 0, 0,
    0, 1, 0,
    x, y, 1,
  ];
}

export function rotation(theta: number): Matrix {
  const cos = Math.cos(theta);
  const sin = Math.sin(theta);
  // deno-fmt-ignore
  return [
    cos, -sin, 0,
    sin, cos, 0,
    0, 0, 1,
  ];
}

export function scaling(x: number, y: number): Matrix {
  // deno-fmt-ignore
  return [
    x, 0, 0,
    0, y, 0,
    0, 0, 1,
  ];
}
