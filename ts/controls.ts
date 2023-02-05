import { multiply, scaling, translation } from "./matrix.ts";

export let viewMatrix = scaling(0.1, 0.1);

function updateView(
  pixels: { x: number; y: number },
  zoom: number,
  canvas: HTMLCanvasElement,
) {
  viewMatrix = multiply(
    scaling(zoom, zoom),
    translation(pixels.x / canvas.width * 2, -pixels.y / canvas.height * 2),
  );
}

export function setupControls(canvas: HTMLCanvasElement) {
  const pixelTranslation = { x: 0, y: 0 };
  let isMoving = false;
  let zoom = 0.1;

  canvas.addEventListener("mousedown", () => isMoving = true);
  canvas.addEventListener("mouseup", () => isMoving = false);
  canvas.addEventListener("mousemove", (e) => {
    if (isMoving) {
      pixelTranslation.x += e.movementX / zoom;
      pixelTranslation.y += e.movementY / zoom;
      updateView(pixelTranslation, zoom, canvas);
    }
  });
  canvas.addEventListener("wheel", (e) => {
    zoom *= 2 ** -Math.sign(e.deltaY);
    updateView(pixelTranslation, zoom, canvas);
  });
}
