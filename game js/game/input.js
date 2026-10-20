export function createInput(surface, { onEngage, onJump, onSkill }) {
  const keys = new Set();
  let pointerId = null;
  let pointerX = null;

  const localX = (event) => {
    const rect = surface.getBoundingClientRect();
    return event.clientX - rect.left;
  };

  const onPointerDown = (event) => {
    if (event.target.closest("button, [role='button'], .overlay")) return;
    event.preventDefault();
    onEngage();
    pointerId = event.pointerId;
    pointerX = localX(event);
    surface.setPointerCapture(event.pointerId);
  };
  const onPointerMove = (event) => {
    if (event.pointerId !== pointerId) return;
    event.preventDefault();
    pointerX = localX(event);
  };
  const onPointerUp = (event) => {
    if (event.pointerId !== pointerId) return;
    pointerId = null;
    pointerX = null;
  };
  const onKeyDown = (event) => {
    if (["ArrowLeft", "ArrowRight", "KeyA", "KeyD", "Space", "KeyQ", "KeyE", "KeyR"].includes(event.code)) {
      event.preventDefault();
      onEngage();
    }
    if (event.code === "Space" && !event.repeat) onJump();
    if (event.code === "KeyQ" && !event.repeat) onSkill("skill1");
    if (event.code === "KeyE" && !event.repeat) onSkill("skill2");
    if (event.code === "KeyR" && !event.repeat) onSkill("ultimate");
    keys.add(event.code);
  };
  const onKeyUp = (event) => keys.delete(event.code);

  surface.addEventListener("pointerdown", onPointerDown);
  surface.addEventListener("pointermove", onPointerMove);
  surface.addEventListener("pointerup", onPointerUp);
  surface.addEventListener("pointercancel", onPointerUp);
  window.addEventListener("keydown", onKeyDown, { passive: false });
  window.addEventListener("keyup", onKeyUp);

  return {
    movement() {
      const left = keys.has("ArrowLeft") || keys.has("KeyA");
      const right = keys.has("ArrowRight") || keys.has("KeyD");
      if (left !== right) return { axis: left ? -1 : 1, target: null };
      if (pointerX !== null) return { axis: 0, target: pointerX };
      return { axis: 0, target: null };
    },
    destroy() {
      surface.removeEventListener("pointerdown", onPointerDown);
      surface.removeEventListener("pointermove", onPointerMove);
      surface.removeEventListener("pointerup", onPointerUp);
      surface.removeEventListener("pointercancel", onPointerUp);
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
    },
  };
}
