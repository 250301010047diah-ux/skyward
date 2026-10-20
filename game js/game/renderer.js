import { AREAS } from "./data.js";

function cropFor(item, frame) {
  const flagged = item.frames?.notes?.some((note) => note.includes(frame.name));
  return flagged ? frame.source : frame.content || frame.source;
}

export function createRenderer(canvas, library, onResize) {
  const context = canvas.getContext("2d", { alpha: false });
  const metrics = new Map();
  let width = 0;
  let height = 0;
  let destroyed = false;

  function resize() {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    context.setTransform(dpr, 0, 0, dpr, 0, 0);
    width = rect.width;
    height = rect.height;
    onResize(width, height);
  }

  const observer = new ResizeObserver(resize);
  observer.observe(canvas);
  resize();

  function animationFrames(key, name) {
    return library.animation(key, name);
  }

  function animationMetric(key, name) {
    const cacheKey = `${key}:${name}`;
    if (metrics.has(cacheKey)) return metrics.get(cacheKey);
    const item = library.get(key);
    const frames = animationFrames(key, name);
    const result = frames.reduce(
      (largest, frame) => {
        const crop = cropFor(item, frame);
        return { width: Math.max(largest.width, crop.w), height: Math.max(largest.height, crop.h) };
      },
      { width: 1, height: 1 },
    );
    metrics.set(cacheKey, result);
    return result;
  }

  function drawAnchored(key, name, index, x, y, targetHeight, flip = false, alpha = 1) {
    const item = library.get(key);
    const frames = animationFrames(key, name);
    if (!item || !frames.length) return;
    const frame = frames[index % frames.length];
    const crop = cropFor(item, frame);
    const metric = animationMetric(key, name);
    const scale = targetHeight / metric.height;
    context.save();
    context.globalAlpha = alpha;
    context.translate(x, y);
    if (flip) context.scale(-1, 1);
    context.drawImage(
      item.image,
      crop.x,
      crop.y,
      crop.w,
      crop.h,
      -(frame.anchor.x - crop.x) * scale,
      -(frame.anchor.y - crop.y) * scale,
      crop.w * scale,
      crop.h * scale,
    );
    context.restore();
  }

  function drawFrameCentered(key, frame, x, y, size, rotation = 0, alpha = 1) {
    const item = library.get(key);
    if (!item || !frame) return;
    const crop = cropFor(item, frame);
    const scale = Math.min(size / crop.w, size / crop.h);
    context.save();
    context.globalAlpha = alpha;
    context.translate(x, y);
    context.rotate(rotation);
    context.drawImage(item.image, crop.x, crop.y, crop.w, crop.h, -crop.w * scale * 0.5, -crop.h * scale * 0.5, crop.w * scale, crop.h * scale);
    context.restore();
  }

  function drawBackdrop(areaIndex) {
    const item = library.get(AREAS[areaIndex].bgKey);
    if (!item) {
      context.fillStyle = "#160d35";
      context.fillRect(0, 0, width, height);
      return;
    }
    const image = item.image;
    const scale = Math.max(width / image.width, height / image.height);
    const drawWidth = image.width * scale;
    const drawHeight = image.height * scale;
    context.drawImage(image, (width - drawWidth) * 0.5, (height - drawHeight) * 0.5, drawWidth, drawHeight);
    const wash = context.createLinearGradient(0, 0, 0, height);
    wash.addColorStop(0, "rgba(18, 5, 50, .08)");
    wash.addColorStop(0.7, "rgba(11, 9, 38, .02)");
    wash.addColorStop(1, "rgba(8, 6, 26, .48)");
    context.fillStyle = wash;
    context.fillRect(0, 0, width, height);
  }

  function drawGround(areaIndex, groundY) {
    const groundKey = AREAS[areaIndex].groundKey || "GROUND_ATLAS";
    const item = library.get(groundKey);
    const frame = library.frame(groundKey, AREAS[areaIndex].ground);
    if (!item || !frame) return;
    const crop = cropFor(item, frame);
    const tileWidth = Math.max(86, Math.min(128, width / 4));
    const tileHeight = Math.max(90, height - groundY + 28);
    for (let x = -tileWidth * 0.4; x < width + tileWidth; x += tileWidth * 0.92) {
      context.drawImage(item.image, crop.x, crop.y, crop.w, crop.h, x, groundY - 4, tileWidth, tileHeight);
    }
    const edge = context.createLinearGradient(0, groundY - 7, 0, groundY + 15);
    edge.addColorStop(0, "rgba(115, 248, 255, .72)");
    edge.addColorStop(0.25, "rgba(70, 128, 255, .34)");
    edge.addColorStop(1, "rgba(8, 5, 24, 0)");
    context.fillStyle = edge;
    context.fillRect(0, groundY - 7, width, 24);
  }

  function drawTelegraphs(state) {
    for (const enemy of state.enemies) {
      if (enemy.state !== "air") continue;
      const closeness = Math.max(0, Math.min(1, enemy.y / state.groundY));
      context.save();
      context.globalAlpha = 0.16 + closeness * 0.46;
      context.fillStyle = closeness > 0.72 ? "#ff4b7d" : "#62e9ff";
      context.beginPath();
      context.ellipse(enemy.x, state.groundY - 2, 10 + closeness * 18, 4 + closeness * 5, 0, 0, Math.PI * 2);
      context.fill();
      context.restore();
    }
  }

  function drawEnemy(enemy, state) {
    const key = enemy.assetKey || (enemy.tier === "common" ? AREAS[state.areaIndex].commonKey : AREAS[state.areaIndex].eliteKey);
    const frame = Math.floor((state.time * (enemy.tier === "boss" ? 7 : 9) + enemy.id * 0.7) % 5);
    const alpha = enemy.tier === "rare" && state.areaIndex === 4 && Math.sin(state.time * 3) < -0.4 ? 0.35 : 1;
    drawAnchored(key, enemy.animation, frame, enemy.x, enemy.y, enemy.size, false, alpha);
    if (enemy.tier !== "common") {
      const barWidth = enemy.tier === "boss" ? enemy.size * 0.72 : enemy.size * 0.58;
      const barY = enemy.y - enemy.size * 0.93;
      context.fillStyle = "rgba(10, 7, 28, .76)";
      context.fillRect(enemy.x - barWidth / 2, barY, barWidth, 5);
      context.fillStyle = enemy.tier === "boss" ? "#ffca55" : "#8ff7ff";
      context.fillRect(enemy.x - barWidth / 2, barY, barWidth * Math.max(0, enemy.hp / enemy.maxHp), 5);
    }
    if (enemy.tier === "boss" && state.areaIndex === 6 && Math.sin(state.time * 2.1) < -0.1) {
      context.strokeStyle = "rgba(111, 243, 255, .75)";
      context.lineWidth = 4;
      context.beginPath();
      context.arc(enemy.x, enemy.y - enemy.size * 0.48, enemy.size * 0.48, 0, Math.PI * 2);
      context.stroke();
    }
  }

  function drawProjectile(projectile) {
    if (projectile.type === "beam") {
      const active = projectile.age > 0.68;
      context.save();
      context.globalCompositeOperation = "lighter";
      context.fillStyle = active ? "rgba(118, 247, 255, .72)" : "rgba(255, 84, 177, .26)";
      context.fillRect(projectile.x - (active ? projectile.size : 3), 0, active ? projectile.size * 2 : 6, height);
      context.restore();
      return;
    }
    if (projectile.type === "wave") {
      context.strokeStyle = "#b07bff";
      context.lineWidth = 7;
      context.beginPath();
      context.arc(projectile.x, projectile.y + 20, projectile.size, Math.PI, Math.PI * 2);
      context.stroke();
      return;
    }
    const radius = projectile.size * 1.8;
    const gradient = context.createRadialGradient(projectile.x, projectile.y, 1, projectile.x, projectile.y, radius);
    gradient.addColorStop(0, projectile.type === "acid" ? "#d8ff61" : "#ffffff");
    gradient.addColorStop(0.25, projectile.type === "acid" ? "#73ef7f" : "#e56cff");
    gradient.addColorStop(1, "rgba(83, 49, 210, 0)");
    context.save();
    context.globalCompositeOperation = "lighter";
    context.fillStyle = gradient;
    context.beginPath();
    context.arc(projectile.x, projectile.y, radius, 0, Math.PI * 2);
    context.fill();
    context.restore();
  }

  function drawPickup(pickup, state) {
    const key = pickup.kind === "coin" ? "HUD_ICON_ATLAS" : "POWERUP_ATLAS";
    const frame = library.frame(key, pickup.kind || "coin");
    drawFrameCentered(key, frame, pickup.x, pickup.y - 8 + Math.sin(state.time * 6 + pickup.x) * 3, pickup.kind === "coin" ? 26 : 38, state.time * 1.2);
  }

  function drawArrow(arrow, state) {
    const effectKey = state.skin?.effectKey || "ARROW_EFFECT_SHEET";
    const frames = animationFrames(effectKey, state.skin?.effectKey ? "basic" : "trail");
    if (!frames.length) return;
    const rotation = Math.atan2(arrow.vy, arrow.vx);
    const frame = frames[Math.floor((state.time * 18 + arrow.age * 12) % 5)];
    context.save();
    context.globalCompositeOperation = "lighter";
    context.globalAlpha = 0.36;
    context.fillStyle = state.skin?.color || "#66efff";
    context.beginPath();
    context.arc(arrow.x, arrow.y, state.skinIndex > 14 ? 13 : 8, 0, Math.PI * 2);
    context.fill();
    context.restore();
    drawFrameCentered(effectKey, frame, arrow.x, arrow.y, arrow.critical ? 68 : 52, rotation, 0.95);
  }

  function drawEffect(effect) {
    if (effect.sheetKey && effect.animation) {
      const frames = animationFrames(effect.sheetKey, effect.animation);
      if (frames.length) {
        const progress = Math.max(0, Math.min(0.999, effect.age / effect.duration));
        drawFrameCentered(effect.sheetKey, frames[Math.floor(progress * 5)], effect.x, effect.y, effect.size, 0, 1 - progress * 0.12);
      }
      return;
    }
    if (effect.type.startsWith("skin_")) {
      const progress = Math.max(0, Math.min(1, effect.age / effect.duration));
      const radius = effect.size * (0.18 + progress * 0.5);
      context.save();
      context.globalCompositeOperation = "lighter";
      context.globalAlpha = (1 - progress) * 0.7;
      context.strokeStyle = effect.color || "#8ff7ff";
      context.fillStyle = effect.color || "#8ff7ff";
      context.lineWidth = Math.max(3, effect.size * 0.025);
      for (let ring = 0; ring < (effect.type === "skin_ultimate" ? 4 : 2); ring += 1) {
        context.beginPath();
        context.arc(effect.x, effect.y, radius * (1 + ring * 0.32), 0, Math.PI * 2);
        context.stroke();
      }
      for (let ray = 0; ray < (effect.type === "skin_ultimate" ? 14 : 6); ray += 1) {
        const angle = ray * Math.PI * 2 / (effect.type === "skin_ultimate" ? 14 : 6) + progress * 1.8;
        context.beginPath();
        context.moveTo(effect.x + Math.cos(angle) * radius * 0.4, effect.y + Math.sin(angle) * radius * 0.4);
        context.lineTo(effect.x + Math.cos(angle) * radius * 1.35, effect.y + Math.sin(angle) * radius * 1.35);
        context.stroke();
      }
      context.restore();
      return;
    }
    const key = effect.sheet === "defeat" ? "DEFEAT_EFFECT_SHEET" : "ARROW_EFFECT_SHEET";
    const frames = animationFrames(key, effect.type);
    if (!frames.length) return;
    const progress = Math.max(0, Math.min(0.999, effect.age / effect.duration));
    const frame = frames[Math.floor(progress * 5)];
    drawFrameCentered(key, frame, effect.x, effect.y, effect.size, 0, 1 - progress * 0.2);
  }

  function drawAbilityZones(state) {
    for (const zone of state.abilityZones || []) {
      const progress = zone.age / zone.duration;
      context.save();
      context.globalCompositeOperation = "lighter";
      context.globalAlpha = 0.35 + Math.sin(state.time * 9) * 0.08;
      context.strokeStyle = state.skin?.color || "#8ff7ff";
      context.fillStyle = state.skin?.color || "#8ff7ff";
      context.lineWidth = 4;
      if (zone.type === "crystalwall") {
        context.fillRect(0, zone.y - 8, width, 16);
      } else if (["firetrail", "bloodfloor"].includes(zone.type)) {
        context.fillRect(0, state.groundY - 14, width, 18);
      } else if (zone.type === "wolf") {
        context.beginPath();
        context.moveTo(zone.x - 35, state.groundY - 18);
        context.lineTo(zone.x + 40, state.groundY - 42);
        context.lineTo(zone.x + 18, state.groundY - 4);
        context.closePath();
        context.fill();
      } else {
        const radius = zone.radius || 95;
        context.beginPath();
        context.arc(zone.x ?? state.player.x, zone.y ?? state.groundY - 90, radius * (0.9 + progress * 0.12), 0, Math.PI * 2);
        context.stroke();
      }
      context.restore();
    }
  }

  function drawPlayer(state) {
    const animation = state.playerAnimation;
    const frame = Math.floor(state.time * (animation.name === "run" ? 12 : 9)) % 5;
    const playerHeight = Math.min(104, Math.max(78, height * 0.13));
    const blink = state.player.invulnerable > 0 && Math.floor(state.player.invulnerable * 14) % 2 === 0;
    drawAnchored(animation.key, animation.name, frame, state.player.x, state.player.y, playerHeight, state.player.facing < 0, blink ? 0.45 : 1);
  }

  function draw(state) {
    if (destroyed || !width || !height) return;
    context.clearRect(0, 0, width, height);
    drawBackdrop(state.areaIndex);
    drawTelegraphs(state);
    drawGround(state.areaIndex, state.groundY);
    drawAbilityZones(state);
    for (const pickup of state.pickups) drawPickup(pickup, state);
    for (const arrow of state.arrows) drawArrow(arrow, state);
    for (const enemy of state.enemies) drawEnemy(enemy, state);
    for (const projectile of state.projectiles) drawProjectile(projectile);
    drawPlayer(state);
    for (const effect of state.effects) drawEffect(effect);

    if (state.skinIndex === 8 && state.damageModeTimer > 0) {
      context.fillStyle = "rgba(2, 0, 12, .64)";
      context.fillRect(0, 0, width, height);
    }
    if (state.skinIndex === 18 && state.player.actionName === "ultimate" && state.player.actionTimer > 0) {
      context.fillStyle = Math.floor(state.time * 24) % 2 ? "rgba(255, 0, 190, .18)" : "rgba(0, 255, 255, .16)";
      context.fillRect(0, 0, width, height);
    }
    if (state.skinIndex === 19 && state.player.actionName === "ultimate" && state.player.actionTimer > 0) {
      context.fillStyle = `rgba(255,255,255,${Math.min(0.92, state.player.actionTimer)})`;
      context.fillRect(0, 0, width, height);
    }

    if (state.areaIndex === 3) {
      context.fillStyle = "rgba(155, 255, 218, .055)";
      for (let index = 0; index < 3; index += 1) {
        const y = ((state.time * 18 + index * height * 0.36) % height);
        context.fillRect(0, y, width, Math.max(18, height * 0.04));
      }
    }
  }

  return {
    draw,
    resize,
    destroy() {
      destroyed = true;
      observer.disconnect();
    },
  };
}
