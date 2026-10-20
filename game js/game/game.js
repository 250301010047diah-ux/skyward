import { createAudio } from "./audio.js";
import { AssetLibrary } from "./assets.js";
import { AREAS, SKINS } from "./data.js";
import { createInput } from "./input.js";
import { createRenderer } from "./renderer.js";
import { createUi } from "./ui.js";
import { GameWorld } from "./world.js";

const SAVE_VERSION = 2;

function safeSavedState(value) {
  if (!value) return { version: SAVE_VERSION, currentArea: 0, unlockedArea: 29, skinIndex: 0, relics: [], bestScore: 0 };
  return {
    version: SAVE_VERSION,
    currentArea: Math.max(0, Math.min(29, Number(value.currentArea) || 0)),
    unlockedArea: 29,
    skinIndex: Math.max(0, Math.min(19, Number(value.skinIndex) || 0)),
    relics: Array.isArray(value.relics) ? value.relics.filter((entry) => typeof entry === "string") : [],
    bestScore: Math.max(0, Number(value.bestScore) || 0),
  };
}

function leaderboardScore(value) {
  if (!Number.isFinite(value)) return null;
  return Math.max(0, Math.min(Math.floor(value), Number.MAX_SAFE_INTEGER));
}

export function createGame({ mount, sdk, ready, tweaks, assets }) {
  let active = false;
  let raf = 0;
  let lastTime = 0;
  let renderer = null;
  let input = null;
  let world = null;
  let ui = null;
  let audio = null;
  let library = null;
  let saved = null;
  let jumpHandler = null;
  const controlHandlers = [];
  const unsubscribers = [];

  async function saveProgress(overrides = {}) {
    if (!world || !saved) return;
    saved = {
      version: SAVE_VERSION,
      currentArea: world.areaIndex,
      unlockedArea: Math.max(saved.unlockedArea, world.areaIndex),
      skinIndex: world.skinIndex,
      relics: [...world.relics],
      bestScore: Math.max(saved.bestScore, world.bestScore, world.score),
      ...overrides,
    };
    await sdk.gameState.save(saved).catch(() => {});
  }

  function submitScore(score) {
    const value = leaderboardScore(score);
    if (value === null) return;
    void sdk.leaderboard.submit(value).catch(() => {});
  }

  function engage() {
    ui?.hideHint();
    void audio?.unlock();
  }

  function showAreaStart() {
    const area = AREAS[world.areaIndex];
    ui.showStart({ ...area, index: world.areaIndex }, SKINS[world.skinIndex], () => {
      engage();
      ui.hideOverlay();
      world.begin();
      if (world.areaIndex < AREAS.length - 1) void library.loadArea(world.areaIndex + 1).catch(() => {});
    });
  }

  function showSelection() {
    ui.showAreaSelect(AREAS, saved.currentArea, (areaIndex) => {
      ui.showSkinSelect(SKINS, saved.skinIndex, (skinIndex) => {
        engage();
        void prepareSelection(areaIndex, skinIndex);
      }, showSelection);
    });
  }

  async function prepareSelection(areaIndex, skinIndex) {
    ui.showLoading(`Menyiapkan ${SKINS[skinIndex].name} di ${AREAS[areaIndex].name}…`);
    try {
      await Promise.all([library.loadArea(areaIndex), library.loadSkin(skinIndex)]);
      if (!active) return;
      world.setSkin(skinIndex);
      world.resetArea(areaIndex, { score: 0, bestScore: Math.max(saved.bestScore, world.bestScore) });
      saved.currentArea = areaIndex;
      saved.skinIndex = skinIndex;
      await saveProgress();
      showAreaStart();
    } catch {
      if (!active) return;
      ui.showLoadError(() => void prepareSelection(areaIndex, skinIndex));
    }
  }

  async function moveToArea(index) {
    ui.showLoading(`Membuka ${AREAS[index].name}…`);
    try {
      await library.loadArea(index);
      if (!active) return;
      world.resetArea(index, { score: world.score, bestScore: Math.max(saved.bestScore, world.bestScore) });
      saved.currentArea = index;
      saved.unlockedArea = Math.max(saved.unlockedArea, index);
      await saveProgress();
      showAreaStart();
    } catch {
      if (!active) return;
      ui.showLoadError(() => void moveToArea(index));
    }
  }

  function wireWorld(tuning) {
    world = new GameWorld({
      areaIndex: saved.currentArea,
      skinIndex: saved.skinIndex,
      relics: saved.relics,
      tuning,
      audio,
      callbacks: {
        onHit() {
          if (sdk.device.haptics.isSupported()) void sdk.device.haptics.vibrate(35).catch(() => {});
        },
        onUltimate() {
          if (sdk.device.haptics.isSupported()) void sdk.device.haptics.vibrate([30, 25, 55]).catch(() => {});
        },
        onUpgrade() {
          ui.showUpgrade((key) => {
            engage();
            ui.hideOverlay();
            world.chooseUpgrade(key);
          });
        },
        onAreaComplete(state) {
          saved.unlockedArea = Math.max(saved.unlockedArea, Math.min(29, state.areaIndex + 1));
          saved.relics = [...world.relics];
          saved.bestScore = Math.max(saved.bestScore, state.score);
          void saveProgress();
          if (state.areaIndex === AREAS.length - 1) {
            submitScore(state.score);
            ui.showVictory(state.score, () => {
              engage();
              void moveToArea(0);
            });
            return;
          }
          const area = AREAS[state.areaIndex];
          const next = AREAS[state.areaIndex + 1];
          ui.showAreaComplete(area, next, () => {
            engage();
            void moveToArea(state.areaIndex + 1);
          });
        },
        onGameOver(state) {
          saved.bestScore = Math.max(saved.bestScore, state.score);
          state.bestScore = saved.bestScore;
          ui.showGameOver(state, () => {
            engage();
            ui.hideOverlay();
            world.retryWave();
          });
          void saveProgress();
          submitScore(state.score);
        },
      },
    });
    world.bestScore = saved.bestScore;
  }

  async function boot() {
    active = true;
    library = new AssetLibrary(assets);
    ui = createUi(mount, (name) => library.iconDataUrl(name));
    ui.showLoading();
    audio = createAudio(sdk);

    const tuning = {
      playerSpeed: Number(tweaks.get("playerSpeed")),
      jumpForce: Number(tweaks.get("jumpForce")),
      gravity: Number(tweaks.get("gravity")),
      baseFireRate: Number(tweaks.get("baseFireRate")),
      enemySpeed: Number(tweaks.get("enemySpeed")),
      effectIntensity: Number(tweaks.get("effectIntensity")),
    };
    for (const key of Object.keys(tuning)) {
      unsubscribers.push(tweaks.subscribe(key, (value) => {
        tuning[key] = Number(value);
      }));
    }

    try {
      const [loadedSave] = await Promise.all([
        sdk.gameState.load().catch(() => null),
        library.loadCore(),
      ]);
      if (!active) return;
      saved = safeSavedState(loadedSave);
      await Promise.all([library.loadArea(saved.currentArea), library.loadSkin(saved.skinIndex)]);
      if (!active) return;
      ui.refreshIcons();
      wireWorld(tuning);
      renderer = createRenderer(ui.canvas, library, (width, height) => world.resize(width, height));
      input = createInput(ui.canvas, { onEngage: engage, onJump: () => world.jump(), onSkill: (type) => world.useSkill(type) });
      world.setInput(input);
      jumpHandler = (event) => {
        event.preventDefault();
        engage();
        world.jump();
      };
      ui.jumpButton.addEventListener("pointerdown", jumpHandler);
      for (const [button, type] of [[ui.skill1Button, "skill1"], [ui.skill2Button, "skill2"], [ui.ultimateButton, "ultimate"]]) {
        const handler = (event) => {
          event.preventDefault();
          engage();
          world.useSkill(type);
        };
        button.addEventListener("pointerdown", handler);
        controlHandlers.push([button, handler]);
      }
      showSelection();

      const frame = (time) => {
        if (!active) return;
        const dt = lastTime ? (time - lastTime) / 1000 : 0;
        lastTime = time;
        world.update(dt);
        const state = world.snapshot();
        renderer.draw(state);
        ui.updateHud(state);
        raf = requestAnimationFrame(frame);
      };
      raf = requestAnimationFrame(frame);
    } catch {
      if (!active) return;
      ui.showLoadError(() => {
        void destroyRuntime().then(boot);
      });
    }
  }

  async function destroyRuntime() {
    active = false;
    cancelAnimationFrame(raf);
    if (jumpHandler) ui?.jumpButton.removeEventListener("pointerdown", jumpHandler);
    for (const [button, handler] of controlHandlers.splice(0)) button.removeEventListener("pointerdown", handler);
    input?.destroy();
    renderer?.destroy();
    await audio?.destroy();
    for (const unsubscribe of unsubscribers.splice(0)) unsubscribe?.();
    ui?.destroy();
    renderer = null;
    input = null;
    world = null;
    ui = null;
    audio = null;
    lastTime = 0;
  }

  return {
    start() {
      void boot();
    },
    destroy() {
      void destroyRuntime();
    },
    sdk,
    ready,
    tweaks,
    assets,
  };
}
