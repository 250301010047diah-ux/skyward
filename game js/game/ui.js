import { UPGRADE_COPY } from "./data.js";

export function createUi(mount, iconFor) {
  const shell = document.createElement("section");
  shell.className = "game-shell";
  shell.innerHTML = `
    <canvas class="game-surface" aria-label="Arena Skyfall Bowguard"></canvas>
    <div class="hud-layer" aria-live="polite">
      <div class="hud-row hud-top">
        <div class="badge area-badge"><span class="area-number">A1</span><span class="area-name">Giant Canopy</span></div>
        <div class="badge score-badge">✦ <span class="score-value">0</span></div>
      </div>
      <div class="hud-row hud-status">
        <div class="pip-row health-row" aria-label="Tiga hati"></div>
        <div class="wave-pill">WAVE <b class="wave-value">1/15</b></div>
        <div class="badge coin-badge"><img alt=""/><b class="coin-value">0</b></div>
      </div>
      <div class="boss-wrap" hidden><div class="boss-name"></div><div class="boss-track"><div class="boss-fill"></div></div></div>
    </div>
    <div class="gesture-hint">GESER UNTUK BERGERAK</div>
    <div class="skill-controls">
      <button class="control-btn skill-btn skill1-btn" type="button" aria-label="Skill satu"><b>S1</b><small>SIAP</small></button>
      <button class="control-btn skill-btn skill2-btn" type="button" aria-label="Skill dua"><b>S2</b><small>SIAP</small></button>
      <button class="control-btn skill-btn ultimate-btn" type="button" aria-label="Ultimate"><b>ULT</b><small>0%</small></button>
    </div>
    <button class="control-btn jump-btn" type="button" aria-label="Lompat"><span class="jump-icon">↑</span><span class="control-label">LOMPAT</span></button>
    <div class="overlay" hidden></div>
  `;
  mount.replaceChildren(shell);

  const canvas = shell.querySelector("canvas");
  const overlay = shell.querySelector(".overlay");
  const jumpButton = shell.querySelector(".jump-btn");
  const skill1Button = shell.querySelector(".skill1-btn");
  const skill2Button = shell.querySelector(".skill2-btn");
  const ultimateButton = shell.querySelector(".ultimate-btn");
  const areaNumber = shell.querySelector(".area-number");
  const areaName = shell.querySelector(".area-name");
  const scoreValue = shell.querySelector(".score-value");
  const waveValue = shell.querySelector(".wave-value");
  const coinValue = shell.querySelector(".coin-value");
  const coinImage = shell.querySelector(".coin-badge img");
  const healthRow = shell.querySelector(".health-row");
  const bossWrap = shell.querySelector(".boss-wrap");
  const bossName = shell.querySelector(".boss-name");
  const bossFill = shell.querySelector(".boss-fill");
  const hint = shell.querySelector(".gesture-hint");
  coinImage.src = iconFor("coin");

  function refreshIcons() {
    coinImage.src = iconFor("coin");
    const state = healthRow.getAttribute("aria-label")?.match(/^(\d+)/);
    if (state) setHealth(Number(state[1]), 3);
  }

  function setHealth(current, maximum = 3) {
    healthRow.replaceChildren();
    for (let index = 0; index < maximum; index += 1) {
      const pip = document.createElement("span");
      pip.className = `pip heart-pip${index >= current ? " empty" : ""}`;
      const image = document.createElement("img");
      image.alt = "";
      image.src = iconFor("heart");
      pip.append(image);
      healthRow.append(pip);
    }
    healthRow.setAttribute("aria-label", `${current} dari ${maximum} hati`);
  }

  function updateHud(state) {
    areaNumber.textContent = `A${state.areaIndex + 1}`;
    areaName.textContent = state.areaName;
    scoreValue.textContent = Math.floor(state.score).toLocaleString("id-ID");
    waveValue.textContent = `${state.wave}/${state.totalWaves || 15}`;
    coinValue.textContent = state.coins;
    setHealth(state.health, state.maxHealth);
    if (state.skills) {
      const s1 = Math.max(0, state.skills.skill1);
      const s2 = Math.max(0, state.skills.skill2);
      skill1Button.querySelector("small").textContent = s1 > 0 ? s1.toFixed(1) : "SIAP";
      skill2Button.querySelector("small").textContent = s2 > 0 ? s2.toFixed(1) : "SIAP";
      skill1Button.disabled = s1 > 0;
      skill2Button.disabled = s2 > 0;
      ultimateButton.querySelector("small").textContent = `${Math.floor(state.skills.ultimate)}%`;
      ultimateButton.disabled = state.skills.ultimate < 100;
      ultimateButton.style.setProperty("--charge", `${state.skills.ultimate}%`);
    }
    if (state.boss) {
      bossWrap.hidden = false;
      bossName.textContent = state.boss.name;
      bossFill.style.width = `${Math.max(0, Math.min(100, state.boss.ratio * 100))}%`;
    } else {
      bossWrap.hidden = true;
    }
  }

  function setOverlay(content, className = "") {
    overlay.className = `overlay ${className}`.trim();
    overlay.hidden = false;
    overlay.replaceChildren(content);
  }

  function hideOverlay() {
    overlay.hidden = true;
    overlay.replaceChildren();
  }

  function panel(title, text) {
    const card = document.createElement("div");
    card.className = "overlay-card";
    const heading = document.createElement("h2");
    heading.textContent = title;
    const copy = document.createElement("p");
    copy.textContent = text;
    card.append(heading, copy);
    return card;
  }

  function actionButton(label, callback, primary = true) {
    const button = document.createElement("button");
    button.className = `panel-btn${primary ? " primary" : ""}`;
    button.type = "button";
    button.innerHTML = `<span class="control-label">${label}</span>`;
    button.addEventListener("click", callback, { once: true });
    return button;
  }

  function showStart(area, skin, onStart) {
    const card = panel(`AREA ${area.index + 1}`, `${area.subtitle} · ${area.name}`);
    const tip = document.createElement("div");
    tip.className = "start-tip";
    tip.textContent = `${skin.name} · ${skin.skill1} · ${skin.skill2} · ${skin.ultimate}`;
    card.append(tip, actionButton("MULAI BERTAHAN", onStart));
    setOverlay(card, "start-overlay");
  }

  function showAreaSelect(areas, selected, onPick) {
    const card = panel("PILIH AREA", "Semua tiga puluh arena dapat langsung dimainkan.");
    const grid = document.createElement("div");
    grid.className = "selection-grid area-selection-grid";
    areas.forEach((area, index) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `selection-btn area-select-btn${index === selected ? " selected" : ""}`;
      button.innerHTML = `<b>${String(index + 1).padStart(2, "0")}</b><span>${area.name}</span><small>${area.subtitle}</small>`;
      button.addEventListener("click", () => onPick(index), { once: true });
      grid.append(button);
    });
    card.append(grid);
    setOverlay(card, "selection-overlay");
  }

  function showSkinSelect(skins, selected, onPick, onBack) {
    const card = panel("PILIH SKY ELF", "Skin 1 ringan; Skin 20 paling overpowered.");
    const grid = document.createElement("div");
    grid.className = "selection-grid skin-selection-grid";
    skins.forEach((skin, index) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `selection-btn skin-select-btn${index === selected ? " selected" : ""}`;
      button.style.setProperty("--skin-color", skin.color);
      button.innerHTML = `<i></i><b>${String(index + 1).padStart(2, "0")} · ${skin.name}</b><span>Power ×${skin.power.toFixed(2)}</span><small>${skin.skill1} · ${skin.ultimate}</small>`;
      button.addEventListener("click", () => onPick(index), { once: true });
      grid.append(button);
    });
    card.append(grid, actionButton("KEMBALI KE AREA", onBack, false));
    setOverlay(card, "selection-overlay skin-overlay");
  }

  function showUpgrade(onPick) {
    const card = panel("PILIH PENINGKATAN", "Emas gelombang ini memperkuatmu sampai boss tumbang.");
    const grid = document.createElement("div");
    grid.className = "upgrade-grid";
    for (const [key, [title, description, icon]] of Object.entries(UPGRADE_COPY)) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "upgrade-btn";
      const image = document.createElement("img");
      image.src = iconFor(icon);
      image.alt = "";
      const strong = document.createElement("strong");
      strong.textContent = title;
      const small = document.createElement("span");
      small.textContent = description;
      button.append(image, strong, small);
      button.addEventListener("click", () => onPick(key), { once: true });
      grid.append(button);
    }
    card.append(grid);
    setOverlay(card, "upgrade-overlay");
  }

  function showAreaComplete(area, nextArea, onContinue) {
    const card = panel("RELIK DIDAPAT", area.relic[0]);
    const icon = document.createElement("img");
    icon.className = "relic-icon";
    icon.src = iconFor(area.relic[1]);
    icon.alt = "";
    const detail = document.createElement("div");
    detail.className = "relic-detail";
    detail.textContent = area.relic[2];
    card.append(icon, detail);
    card.append(actionButton(nextArea ? `LANJUT KE ${nextArea.name}` : "LIHAT KEMENANGAN", onContinue));
    setOverlay(card, "relic-overlay");
  }

  function showGameOver(state, onRetry) {
    const card = panel("PERTAHANAN RUNTUH", `Berhenti di Area ${state.areaIndex + 1}, Wave ${state.wave}.`);
    const result = document.createElement("div");
    result.className = "result-score";
    result.innerHTML = `<span>SKOR</span><b>${Math.floor(state.score).toLocaleString("id-ID")}</b><small>Terbaik ${Math.floor(state.bestScore).toLocaleString("id-ID")}</small>`;
    card.append(result, actionButton("COBA WAVE INI LAGI", onRetry));
    setOverlay(card, "gameover-overlay");
  }

  function showVictory(score, onReplay) {
    const card = panel("REALITAS DISELAMATKAN", "Tiga puluh arena telah tunduk pada Sky Elf.");
    const icon = document.createElement("img");
    icon.className = "relic-icon victory-bow";
    icon.src = iconFor("dawn_bow");
    icon.alt = "";
    const result = document.createElement("div");
    result.className = "result-score";
    result.innerHTML = `<span>SKOR KAMPANYE</span><b>${Math.floor(score).toLocaleString("id-ID")}</b>`;
    card.append(icon, result, actionButton("MAIN LAGI DARI AREA 1", onReplay));
    setOverlay(card, "victory-overlay");
  }

  function showLoading(text = "Memanggil penjaga langit…") {
    const card = panel("", text);
    card.classList.add("loading-card");
    const spinner = document.createElement("div");
    spinner.className = "loading-gem";
    card.prepend(spinner);
    setOverlay(card, "loading-overlay");
  }

  function showLoadError(onRetry) {
    const card = panel("ARENA BELUM TERBUKA", "Aset area tidak berhasil dimuat. Coba sekali lagi.");
    card.append(actionButton("COBA MUAT ULANG", onRetry));
    setOverlay(card, "error-overlay");
  }

  return {
    shell,
    canvas,
    jumpButton,
    skill1Button,
    skill2Button,
    ultimateButton,
    updateHud,
    hideOverlay,
    showStart,
    showAreaSelect,
    showSkinSelect,
    showUpgrade,
    showAreaComplete,
    showGameOver,
    showVictory,
    showLoading,
    showLoadError,
    refreshIcons,
    hideHint() {
      hint.classList.add("hidden");
    },
    destroy() {
      shell.remove();
    },
  };
}
