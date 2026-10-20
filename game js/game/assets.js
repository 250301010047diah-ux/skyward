import assetsManifest from "../assets.json";
import { AREAS, CORE_SHEETS, REINFORCEMENTS, SKINS } from "./data.js";

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`Gagal memuat gambar: ${url}`));
    image.src = url;
  });
}

function framesUrlFor(key) {
  if (key.startsWith("BG_AREA_")) return null;
  const original = assetsManifest[key];
  return original ? original.replace(/\.[^.]+$/, ".frames.json") : null;
}

export class AssetLibrary {
  constructor(assets) {
    this.assets = assets;
    this.items = new Map();
    this.loading = new Map();
  }

  url(key) {
    return this.assets?.get(key) || assetsManifest[key];
  }

  async load(key) {
    if (this.items.has(key)) return this.items.get(key);
    if (this.loading.has(key)) return this.loading.get(key);
    const task = (async () => {
      const url = this.url(key);
      if (!url) throw new Error(`Asset ${key} tidak tersedia`);
      const imagePromise = loadImage(url);
      const frameUrl = framesUrlFor(key);
      const framesPromise = frameUrl
        ? fetch(frameUrl).then((response) => {
            if (!response.ok) throw new Error(`Frame data ${key} gagal dimuat`);
            return response.json();
          })
        : Promise.resolve(null);
      const [image, frames] = await Promise.all([imagePromise, framesPromise]);
      const item = { image, frames, url };
      this.items.set(key, item);
      return item;
    })();
    this.loading.set(key, task);
    try {
      return await task;
    } finally {
      this.loading.delete(key);
    }
  }

  async loadCore() {
    await Promise.all(CORE_SHEETS.map((key) => this.load(key)));
  }

  async loadArea(index) {
    const area = AREAS[index];
    const reinforcement = REINFORCEMENTS[index];
    await Promise.all([this.load(area.bgKey), this.load(area.commonKey), this.load(area.eliteKey), reinforcement ? this.load(reinforcement[0]) : null]);
  }

  async loadSkin(index) {
    const skin = SKINS[index];
    await Promise.all([this.load(skin.coreKey), this.load(skin.skillKey), this.load(skin.effectKey)]);
  }

  get(key) {
    return this.items.get(key);
  }

  animation(key, name) {
    return this.get(key)?.frames?.animations?.find((entry) => entry.name === name)?.frames || [];
  }

  frame(key, name) {
    return this.get(key)?.frames?.frames?.find((entry) => entry.name === name) || null;
  }

  iconDataUrl(name, size = 96) {
    const hud = this.get("HUD_ICON_ATLAS");
    const power = this.get("POWERUP_ATLAS");
    const relic = this.get("RELIC_ATLAS_3");
    const item = hud?.frames?.frames?.some((entry) => entry.name === name)
      ? hud
      : power?.frames?.frames?.some((entry) => entry.name === name) ? power : relic;
    const frame = item?.frames?.frames?.find((entry) => entry.name === name);
    if (!item || !frame) return "";
    const crop = frame.content || frame.source;
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext("2d");
    const scale = Math.min((size * 0.9) / crop.w, (size * 0.9) / crop.h);
    const width = crop.w * scale;
    const height = crop.h * scale;
    ctx.drawImage(
      item.image,
      crop.x,
      crop.y,
      crop.w,
      crop.h,
      (size - width) / 2,
      (size - height) / 2,
      width,
      height,
    );
    return canvas.toDataURL();
  }
}
