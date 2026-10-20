import { AREAS, REINFORCEMENTS, SKINS } from "./data.js";

const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, value));
const distanceSquared = (ax, ay, bx, by) => (ax - bx) ** 2 + (ay - by) ** 2;

export class GameWorld {
  constructor({ areaIndex, skinIndex = 0, relics, tuning, audio, callbacks }) {
    this.areaIndex = areaIndex;
    this.area = AREAS[areaIndex];
    this.skinIndex = skinIndex;
    this.skin = SKINS[skinIndex];
    this.relics = new Set(relics || []);
    this.tuning = tuning;
    this.audio = audio;
    this.callbacks = callbacks;
    this.width = 400;
    this.height = 700;
    this.groundY = 590;
    this.time = 0;
    this.wave = 1;
    this.score = 0;
    this.bestScore = 0;
    this.coins = 0;
    this.upgrades = { damage: 0, fireRate: 0, speed: 0 };
    this.arrows = [];
    this.enemies = [];
    this.projectiles = [];
    this.pickups = [];
    this.effects = [];
    this.abilityZones = [];
    this.timeStop = 0;
    this.damageModeTimer = 0;
    this.areaDamageBuff = 1;
    this.flightTimer = 0;
    this.contactDestroyTimer = 0;
    this.reflectTimer = 0;
    this.autoVolleyTimer = 0;
    this.started = false;
    this.paused = true;
    this.ended = false;
    this.input = { movement: () => ({ axis: 0, target: null }) };
    this.player = this.makePlayer();
    this.spawnRemaining = 0;
    this.spawnTimer = 0;
    this.waveClearTimer = 0;
    this.nextId = 1;
  }

  makePlayer() {
    return {
      x: this.width * 0.5,
      y: this.groundY,
      vy: 0,
      grounded: true,
      health: 3,
      maxHealth: 3,
      invulnerable: 0,
      fireTimer: 0,
      shootTimer: 0,
      hurtTimer: 0,
      facing: 1,
      shieldUsed: false,
      phoenixUsed: false,
      shotCount: 0,
      skill1Cooldown: 0,
      skill2Cooldown: 0,
      ultimate: 25,
      actionTimer: 0,
      slowTimer: 0,
      actionName: "",
      meleeCooldown: 0,
      shieldCharges: 0,
      buffs: { multishot: 0, haste: 0, power: 0, critical: 0, freeze: 0, magnet: 0 },
    };
  }

  setInput(input) {
    this.input = input;
  }

  setSkin(index) {
    this.skinIndex = clamp(index, 0, SKINS.length - 1);
    this.skin = SKINS[this.skinIndex];
  }

  resize(width, height) {
    const oldWidth = this.width || width;
    const ratio = this.player.x / oldWidth;
    this.width = width;
    this.height = height;
    this.groundY = height * (height < width * 1.15 ? 0.78 : 0.82);
    this.player.x = clamp(ratio * width, 34, width - 34);
    if (this.player.grounded) this.player.y = this.groundY;
  }

  begin() {
    if (this.started && !this.paused) return;
    this.started = true;
    this.paused = false;
    this.startWave();
  }

  startWave() {
    this.paused = false;
    this.waveClearTimer = 0;
    this.spawnTimer = 0.25;
    this.projectiles.length = 0;
    const bossWave = this.area.waveCount || 15;
    const miniWave = bossWave - 5;
    if (this.wave === bossWave || this.wave === miniWave) this.spawnRemaining = 1;
    else this.spawnRemaining = Math.min(12, 4 + Math.ceil(this.wave * 0.55));
    this.callbacks.onWaveStart?.(this.wave);
    if (this.wave === miniWave || this.wave === bossWave) this.audio.play("warning");
  }

  resetArea(areaIndex, { score = this.score, bestScore = this.bestScore } = {}) {
    this.areaIndex = areaIndex;
    this.area = AREAS[areaIndex];
    this.wave = 1;
    this.score = score;
    this.bestScore = bestScore;
    this.coins = 0;
    this.upgrades = { damage: 0, fireRate: 0, speed: 0 };
    this.arrows.length = 0;
    this.enemies.length = 0;
    this.projectiles.length = 0;
    this.pickups.length = 0;
    this.effects.length = 0;
    this.abilityZones.length = 0;
    this.timeStop = 0;
    this.damageModeTimer = 0;
    this.areaDamageBuff = 1;
    this.flightTimer = 0;
    this.contactDestroyTimer = 0;
    this.reflectTimer = 0;
    this.autoVolleyTimer = 0;
    this.player = this.makePlayer();
    this.player.x = this.width * 0.5;
    this.player.y = this.groundY;
    this.started = false;
    this.paused = true;
    this.ended = false;
  }

  retryWave() {
    this.arrows.length = 0;
    this.enemies.length = 0;
    this.projectiles.length = 0;
    this.pickups.length = 0;
    this.effects.length = 0;
    this.abilityZones.length = 0;
    this.timeStop = 0;
    this.damageModeTimer = 0;
    this.flightTimer = 0;
    this.contactDestroyTimer = 0;
    this.reflectTimer = 0;
    this.player.health = this.player.maxHealth;
    this.player.invulnerable = 0;
    this.player.vy = 0;
    this.player.y = this.groundY;
    this.player.grounded = true;
    this.player.shieldUsed = false;
    this.ended = false;
    this.startWave();
  }

  jump() {
    if (this.flightTimer > 0 && !this.paused && !this.ended) {
      this.player.y = Math.max(this.height * 0.24, this.player.y - 75);
      this.audio.play("jump");
      return;
    }
    if (this.paused || this.ended || !this.player.grounded) return;
    this.player.vy = -this.tuning.jumpForce;
    this.player.grounded = false;
    this.audio.play("jump");
  }

  useSkill(type) {
    if (this.paused || this.ended || !this.started) return false;
    const player = this.player;
    const power = this.skin.power;
    if (type === "skill1" && player.skill1Cooldown > 0) return false;
    if (type === "skill2" && player.skill2Cooldown > 0) return false;
    if (type === "ultimate" && player.ultimate < 100) return false;

    player.actionName = type;
    player.actionTimer = type === "ultimate" ? 0.85 : 0.58;
    if (type === "skill1") player.skill1Cooldown = Math.max(3.2, 5.8 - this.skinIndex * 0.09);
    if (type === "skill2") player.skill2Cooldown = Math.max(5.5, 9.4 - this.skinIndex * 0.15);
    if (type === "ultimate") player.ultimate = 0;

    this.activateExactSkill(this.skinIndex, type, power);
    this.effects.push({
      x: type === "ultimate" ? this.width * 0.5 : player.x,
      y: type === "ultimate" ? this.height * 0.42 : player.y - 90,
      type: "skin_result",
      sheetKey: this.skin.effectKey,
      animation: type,
      age: 0,
      duration: type === "ultimate" ? 1.05 : 0.65,
      size: type === "ultimate" ? Math.max(this.width, this.height) * (0.68 + this.skinIndex * 0.02) : 120 + this.skinIndex * 5,
      color: this.skin.color,
    });
    if (type === "ultimate") this.callbacks.onUltimate?.();
    this.audio.play("upgrade");
    return true;
  }

  abilityArrow(angle, damage, properties = {}) {
    const speed = Math.max(540, this.height * 0.86);
    this.arrows.push({
      x: this.player.x,
      y: this.player.y - 68,
      vx: Math.sin(angle) * speed,
      vy: -Math.cos(angle) * speed,
      damage: damage * this.areaDamageBuff * (this.damageModeTimer > 0 ? 3 : 1),
      critical: Boolean(properties.critical),
      pierce: Boolean(properties.pierce),
      maxHits: properties.maxHits || (properties.pierce ? 99 : 1),
      homing: Boolean(properties.homing),
      aoe: properties.aoe || 0,
      slow: properties.slow || 0,
      poison: properties.poison || 0,
      stun: properties.stun || 0,
      chain: properties.chain || 0,
      omni: Boolean(properties.omni),
      hits: new Set(), age: 0, dead: false,
    });
  }

  damageTargets(targets, amount, { critical = false, killCommon = false } = {}) {
    for (const enemy of targets) {
      if (!enemy || enemy.dead) continue;
      enemy.hp -= amount * this.areaDamageBuff * (this.damageModeTimer > 0 ? 3 : 1);
      if (killCommon && enemy.tier === "common") enemy.hp = 0;
      if (enemy.hp <= 0) this.killEnemy(enemy, critical);
    }
  }

  addZone(type, duration, properties = {}) {
    this.abilityZones.push({ type, duration, age: 0, tick: 0, x: properties.x ?? this.player.x, ...properties });
  }

  activateExactSkill(skin, type, power) {
    const living = () => this.enemies.filter((enemy) => !enemy.dead);
    const airborne = () => living().filter((enemy) => enemy.state !== "ground");
    const commons = () => living().filter((enemy) => enemy.tier === "common");
    const strongest = () => living().sort((a, b) => b.hp - a.hp)[0];
    const spread = (count, arc, damage, props = {}) => {
      for (let index = 0; index < count; index += 1) this.abilityArrow((index - (count - 1) / 2) * arc / Math.max(1, count - 1), damage, props);
    };

    if (type === "skill1") {
      if (skin === 0) for (let index = 0; index < 3; index += 1) this.abilityArrow(0, 1.8 * power, { pierce: true, maxHits: 2 });
      if (skin === 1) this.abilityArrow(0, 3 * power, { pierce: true, maxHits: 3 });
      if (skin === 2) this.abilityArrow(0, 3.2 * power, { aoe: 78 });
      if (skin === 3) spread(3, 0.5, 2.3 * power, { slow: 2.4 });
      if (skin === 4) this.abilityArrow(0, 3.4 * power, { chain: 1 });
      if (skin === 5) spread(2, 0.22, 2.8 * power, { homing: true });
      if (skin === 6) this.damageTargets(airborne().filter((enemy) => Math.abs(enemy.x - this.player.x) < 120), 5 * power);
      if (skin === 7) spread(5, 0.9, 2.8 * power);
      if (skin === 8) this.abilityArrow(0, 4 * power, { pierce: true, poison: 4 });
      if (skin === 9) this.addZone("drones", 5, { damage: 1.3 * power, interval: 0.35 });
      if (skin === 10) this.abilityArrow(0, 5.2 * power, { pierce: true, maxHits: 4, chain: 4, critical: true });
      if (skin === 11) spread(9, 1.1, 2.2 * power, { pierce: true, maxHits: 2 });
      if (skin === 12) this.addZone("blackhole", 2.4, { x: this.player.x, y: this.height * 0.35, radius: 150, damage: 1.5 * power });
      if (skin === 13) spread(3, 0.16, 3.4 * power, { pierce: true });
      if (skin === 14) {
        const targets = living().slice(0, 4);
        this.damageTargets(targets, 4 * power);
        this.damageTargets(targets, 4 * power);
      }
      if (skin === 15) {
        this.abilityArrow(0, 4 * power, { aoe: 95 });
        spread(7, 1.1, 2 * power, { homing: true });
      }
      if (skin === 16) this.damageTargets([strongest()], 9 * power, { critical: true });
      if (skin === 17) this.damageTargets(living().filter((enemy) => Math.abs(enemy.x - this.player.x) < 62), 12 * power, { critical: true });
      if (skin === 18) this.abilityArrow(0, 9 * power, { pierce: true, slow: 3, poison: 4, stun: 1.5, omni: true });
      if (skin === 19) {
        this.autoVolleyTimer = 8;
        for (const enemy of living()) this.damageTargets([enemy], 2.5 * power);
      }
    }

    if (type === "skill2") {
      if (skin === 0) for (const enemy of living().filter((enemy) => enemy.state === "ground")) enemy.rootTimer = 2;
      if (skin === 1) {
        const oldX = this.player.x;
        this.player.x = clamp(this.player.x + this.player.facing * 125, 34, this.width - 34);
        this.player.invulnerable = 0.7;
        this.addZone("windtrap", 3, { x: oldX, radius: 70, damage: 1.3 * power });
      }
      if (skin === 2) {
        this.jump();
        this.player.vy *= 1.35;
        this.addZone("firetrail", 3, { x: this.player.x, radius: 105, damage: 1.8 * power });
      }
      if (skin === 3) {
        this.player.shieldCharges += 1;
        this.player.buffs.freeze = 4;
      }
      if (skin === 4) this.addZone("totem", 3, { x: this.player.x, damage: 2.2 * power, interval: 0.35 });
      if (skin === 5) {
        this.abilityArrow(0, 1.2 * power, { homing: true, pierce: true, maxHits: 1 });
        this.player.shieldCharges += 1;
      }
      if (skin === 6) this.addZone("wolf", 1.25, { x: -40, damage: 7 * power });
      if (skin === 7) this.projectiles = this.projectiles.filter((projectile) => distanceSquared(projectile.x, projectile.y, this.player.x, this.player.y) > 180 ** 2);
      if (skin === 8) this.player.invulnerable = 2;
      if (skin === 9) for (const enemy of living().filter((enemy) => enemy.state === "air")) enemy.y = Math.max(-50, enemy.y - 170);
      if (skin === 10) {
        this.damageTargets(living().slice(0, 6), 2.4 * power);
        this.player.health = Math.min(this.player.maxHealth, this.player.health + 1);
      }
      if (skin === 11) this.addZone("crystalwall", 3, { y: this.height * 0.48 });
      if (skin === 12) {
        const oldX = this.player.x;
        this.player.x = this.player.facing > 0 ? this.width - 45 : 45;
        this.damageTargets(living().filter((enemy) => Math.abs(enemy.x - oldX) < 95), 5 * power);
      }
      if (skin === 13) this.addZone("decoy", 4, { x: this.player.x });
      if (skin === 14) this.timeStop = 3;
      if (skin === 15) {
        this.player.invulnerable = 4;
        this.contactDestroyTimer = 4;
      }
      if (skin === 16) {
        const enemy = strongest();
        if (enemy) {
          const oldX = this.player.x;
          this.player.x = enemy.x;
          enemy.x = oldX;
          enemy.stunTimer = 3;
        }
      }
      if (skin === 17) {
        this.flightTimer = 4;
        this.player.invulnerable = 4;
      }
      if (skin === 18) this.projectiles.length = 0;
      if (skin === 19) {
        this.reflectTimer = 6;
        this.player.invulnerable = 0.6;
      }
    }

    if (type === "ultimate") {
      if (skin === 0) this.addZone("arrowrain", 2.4, { count: 15, damage: 2.6 * power, interval: 0.12 });
      if (skin === 1) this.addZone("tornado", 4, { x: this.width * 0.5, radius: 170, damage: 1.5 * power });
      if (skin === 2) this.addZone("meteors", 1.8, { count: 3, damage: 8 * power, interval: 0.45 });
      if (skin === 3) {
        this.timeStop = 4;
        this.projectiles.length = 0;
        for (const enemy of living()) enemy.slowTimer = 4;
      }
      if (skin === 4) this.damageTargets(airborne().slice(0, 10), 10 * power, { critical: true });
      if (skin === 5) this.addZone("gatling", 3, { count: 50, damage: 1.1 * power, interval: 0.055 });
      if (skin === 6) {
        this.projectiles.length = 0;
        this.damageTargets(living(), 7 * power);
      }
      if (skin === 7) this.damageTargets(living().filter((enemy) => Math.abs(enemy.x - this.width * 0.5) < 120 || Math.abs(enemy.y - this.height * 0.42) < 90), 16 * power, { critical: true });
      if (skin === 8) {
        this.timeStop = 5;
        this.damageModeTimer = 5;
      }
      if (skin === 9) this.damageTargets(living(), 15 * power, { critical: true });
      if (skin === 10) {
        this.addZone("bloodfloor", 3, { damage: 3.3 * power, interval: 0.25 });
      }
      if (skin === 11) this.damageTargets(commons(), 9999, { killCommon: true });
      if (skin === 12) {
        this.projectiles.length = 0;
        this.damageTargets(commons(), 9999, { killCommon: true });
        this.damageTargets(living().filter((enemy) => enemy.tier === "boss"), 18 * power);
      }
      if (skin === 13) this.addZone("clones", 5, { count: 5, damage: 2.2 * power, interval: 0.16 });
      if (skin === 14) this.addZone("timelasers", 5, { count: 3, damage: 3 * power, interval: 0.2 });
      if (skin === 15) this.damageTargets(living(), 35 * power, { critical: true, killCommon: true });
      if (skin === 16) {
        this.damageTargets(commons(), 9999, { killCommon: true });
        for (const enemy of living().filter((entry) => entry.tier === "boss")) enemy.armor = 0;
      }
      if (skin === 17) this.damageTargets(living(), 45 * power, { critical: true, killCommon: true });
      if (skin === 18) {
        this.timeStop = 0.55;
        const boss = living().find((enemy) => enemy.tier === "boss");
        if (boss) boss.hp *= 0.5;
        this.player.health = this.player.maxHealth;
      }
      if (skin === 19) {
        this.damageTargets(commons(), 9999, { killCommon: true });
        this.projectiles.length = 0;
        this.areaDamageBuff *= 3;
      }
      this.player.invulnerable = Math.max(this.player.invulnerable, 1.2);
    }
  }

  chooseUpgrade(key) {
    if (!(key in this.upgrades)) return;
    this.upgrades[key] += 1;
    this.audio.play("upgrade");
    this.paused = false;
    this.wave += 1;
    this.startWave();
  }

  update(dt) {
    dt = Math.min(dt, 0.034);
    this.time += dt;
    for (const effect of this.effects) effect.age += dt;
    this.effects = this.effects.filter((effect) => effect.age < effect.duration);
    if (this.paused || this.ended || !this.started) return;

    this.timeStop = Math.max(0, this.timeStop - dt);
    this.damageModeTimer = Math.max(0, this.damageModeTimer - dt);
    this.flightTimer = Math.max(0, this.flightTimer - dt);
    this.contactDestroyTimer = Math.max(0, this.contactDestroyTimer - dt);
    this.reflectTimer = Math.max(0, this.reflectTimer - dt);
    this.autoVolleyTimer = Math.max(0, this.autoVolleyTimer - dt);

    this.updatePlayer(dt);
    this.updateSpawning(dt);
    this.updateArrows(dt);
    if (this.timeStop <= 0) {
      this.updateEnemies(dt);
      this.updateProjectiles(dt);
    }
    this.updateAbilities(dt);
    this.updatePickups(dt);
    this.resolveArrowHits();
    this.resolvePlayerHits();
    this.checkWaveClear(dt);
  }

  updateAbilities(dt) {
    const living = () => this.enemies.filter((enemy) => !enemy.dead);
    if (this.reflectTimer > 0) {
      for (const projectile of this.projectiles) {
        if (projectile.dead || distanceSquared(projectile.x, projectile.y, this.player.x, this.player.y - 45) > 115 ** 2) continue;
        projectile.dead = true;
        const target = living().sort((a, b) => b.hp - a.hp)[0];
        if (target) {
          target.hp -= 10 * this.skin.power;
          if (target.hp <= 0) this.killEnemy(target, true);
        }
      }
    }
    if (this.contactDestroyTimer > 0) {
      for (const enemy of living()) {
        if (distanceSquared(enemy.x, enemy.y, this.player.x, this.player.y) < 70 ** 2 && enemy.tier !== "boss") this.killEnemy(enemy, true);
      }
    }
    for (const zone of this.abilityZones) {
      zone.age += dt;
      zone.tick -= dt;
      if (zone.type === "wolf") zone.x += this.width * dt * 0.9;
      if (["tornado", "blackhole", "windtrap"].includes(zone.type)) {
        for (const enemy of living()) {
          const centerY = zone.y ?? this.height * 0.42;
          if (distanceSquared(enemy.x, enemy.y, zone.x, centerY) < (zone.radius || 120) ** 2) {
            enemy.x += (zone.x - enemy.x) * dt * 4;
            enemy.y += (centerY - enemy.y) * dt * 2;
            if (zone.tick <= 0) enemy.hp -= zone.damage;
          }
        }
      }
      if (zone.type === "firetrail") {
        for (const enemy of living().filter((entry) => entry.state === "ground" && Math.abs(entry.x - zone.x) < zone.radius)) if (zone.tick <= 0) enemy.hp -= zone.damage;
      }
      if (zone.type === "crystalwall") {
        for (const enemy of living().filter((entry) => entry.state === "air" && entry.y > zone.y - 40 && entry.y < zone.y + 70)) enemy.rootTimer = 0.15;
      }
      if (zone.type === "decoy") for (const enemy of living()) enemy.x += (zone.x - enemy.x) * dt * 0.8;
      if (zone.tick <= 0) {
        if (zone.type === "arrowrain") this.abilityArrow((Math.random() - 0.5) * 1.4, zone.damage, { pierce: true, maxHits: 2 });
        if (zone.type === "meteors") this.damageTargets(living().slice(0, 4), zone.damage, { critical: true });
        if (["gatling", "clones", "timelasers"].includes(zone.type)) this.abilityArrow((Math.random() - 0.5) * 1.3, zone.damage, { homing: true, pierce: zone.type !== "gatling" });
        if (zone.type === "totem") this.damageTargets(living().filter((entry) => entry.state !== "ground").slice(0, 1), zone.damage);
        if (zone.type === "drones") this.damageTargets(living().slice(0, 3), zone.damage);
        if (zone.type === "wolf") this.damageTargets(living().filter((entry) => entry.state === "ground" && Math.abs(entry.x - zone.x) < 80), zone.damage);
        if (zone.type === "bloodfloor") this.damageTargets(living(), zone.damage);
        for (const enemy of living()) if (enemy.hp <= 0) this.killEnemy(enemy, false);
        zone.tick = zone.interval || 0.28;
      }
    }
    this.abilityZones = this.abilityZones.filter((zone) => zone.age < zone.duration);
  }

  updatePlayer(dt) {
    const player = this.player;
    player.invulnerable = Math.max(0, player.invulnerable - dt);
    player.shootTimer = Math.max(0, player.shootTimer - dt);
    player.hurtTimer = Math.max(0, player.hurtTimer - dt);
    player.actionTimer = Math.max(0, player.actionTimer - dt);
    player.meleeCooldown = Math.max(0, player.meleeCooldown - dt);
    player.skill1Cooldown = Math.max(0, player.skill1Cooldown - dt);
    player.skill2Cooldown = Math.max(0, player.skill2Cooldown - dt);
    for (const key of Object.keys(player.buffs)) player.buffs[key] = Math.max(0, player.buffs[key] - dt);
    const move = this.input.movement();
    const speed = this.tuning.playerSpeed * 0.72 * 1.18 ** this.upgrades.speed * (player.buffs.haste > 0 ? 1.35 : 1);
    if (move.target !== null) {
      const difference = move.target - player.x;
      const step = clamp(difference, -speed * dt, speed * dt);
      player.x += step;
      if (Math.abs(step) > 0.1) player.facing = Math.sign(step);
    } else {
      player.x += move.axis * speed * dt;
      if (move.axis) player.facing = move.axis;
    }
    player.x = clamp(player.x, 34, this.width - 34);

    if (this.flightTimer > 0) {
      player.grounded = false;
      player.vy = 0;
      player.y += (this.groundY - Math.min(150, this.height * 0.22) - player.y) * Math.min(1, dt * 6);
    } else if (!player.grounded) {
      player.vy += this.tuning.gravity * dt;
      player.y += player.vy * dt;
      if (player.y >= this.groundY) {
        player.y = this.groundY;
        player.vy = 0;
        player.grounded = true;
      }
    }

    const meleeTarget = this.enemies.find((enemy) => !enemy.dead && enemy.state === "ground" && Math.abs(enemy.x - player.x) < 72);
    if (meleeTarget && player.meleeCooldown <= 0) {
      player.meleeCooldown = 0.62;
      player.actionName = "melee";
      player.actionTimer = 0.42;
      player.facing = meleeTarget.x < player.x ? -1 : 1;
      meleeTarget.hp -= 2.8 * this.skin.power;
      meleeTarget.x += player.facing * 34;
      this.effects.push({ x: meleeTarget.x, y: meleeTarget.y - 35, type: "skin_skill1", age: 0, duration: 0.32, size: 64 + this.skinIndex * 2, color: this.skin.color });
      if (meleeTarget.hp <= 0) this.killEnemy(meleeTarget, false);
    }

    player.fireTimer -= dt;
    const rate = this.tuning.baseFireRate * 1.22 ** this.upgrades.fireRate * (player.buffs.haste > 0 ? 1.4 : 1) * (this.skinIndex === 19 || this.autoVolleyTimer > 0 ? 2.25 : 1);
    if (player.fireTimer <= 0) {
      this.fireArrow();
      player.fireTimer = 1 / rate;
    }
  }

  targetEnemy() {
    let selected = null;
    let selectedScore = -Infinity;
    for (const enemy of this.enemies) {
      if (enemy.dead) continue;
      const groundedThreat = enemy.state === "ground" ? 10000 - Math.abs(enemy.x - this.player.x) * 4 : 0;
      const landingThreat = enemy.state === "air" ? enemy.y * 8 : 0;
      const bossThreat = enemy.tier === "boss" ? 4000 : 0;
      const score = groundedThreat + landingThreat + bossThreat - Math.abs(enemy.x - this.player.x);
      if (score > selectedScore) {
        selected = enemy;
        selectedScore = score;
      }
    }
    return selected;
  }

  fireArrow() {
    const target = this.targetEnemy();
    const startX = this.player.x;
    const startY = this.player.y - Math.min(72, this.height * 0.1);
    let dx = 0;
    let dy = -1;
    if (target) {
      dx = target.x - startX;
      dy = target.y - target.size * 0.48 - startY;
      const length = Math.hypot(dx, dy) || 1;
      dx /= length;
      dy /= length;
      if (dy > -0.18 && target.state !== "ground") dy = -0.18;
    }
    const speed = Math.max(520, this.height * 0.82);
    this.player.shotCount += 1;
    const pierce = this.relics.has("Segel Lich") && this.player.shotCount % 12 === 0;
    const critical = Math.random() < (this.player.buffs.critical > 0 ? 0.5 : 0.1);
    const shots = this.player.buffs.multishot > 0 ? 3 : this.skinIndex >= 19 ? 2 : 1;
    for (let index = 0; index < shots; index += 1) {
      const offset = (index - (shots - 1) / 2) * 0.12;
      const cos = Math.cos(offset);
      const sin = Math.sin(offset);
      const shotX = dx * cos - dy * sin;
      const shotY = dx * sin + dy * cos;
      this.arrows.push({
        x: startX,
        y: startY,
        vx: shotX * speed,
        vy: shotY * speed,
        damage: (1.65 * this.skin.power * this.areaDamageBuff * (this.damageModeTimer > 0 ? 3 : 1) * 1.35 ** this.upgrades.damage * (this.player.buffs.power > 0 ? 1.65 : 1)) * (critical ? 2 : 1),
        critical,
        pierce: pierce || this.skinIndex >= 17,
        hits: new Set(),
        age: 0,
        dead: false,
      });
    }
    if (this.skinIndex === 19) {
      for (const enemy of this.enemies.filter((entry) => !entry.dead).slice(0, 6)) {
        const ex = enemy.x - startX;
        const ey = enemy.y - enemy.size * 0.45 - startY;
        this.abilityArrow(Math.atan2(ex, -ey), 1.2 * this.skin.power, { homing: true, pierce: true, maxHits: 2 });
      }
    }
    this.player.shootTimer = 0.18;
    this.player.facing = target && target.x < startX ? -1 : 1;
    this.effects.push({ x: startX, y: startY, type: "release", age: 0, duration: 0.22, size: 54 * this.tuning.effectIntensity });
    this.audio.play("bow");
  }

  updateSpawning(dt) {
    if (this.spawnRemaining <= 0) return;
    this.spawnTimer -= dt;
    if (this.spawnTimer > 0) return;
    let tier = "common";
    const bossWave = this.area.waveCount || 15;
    const miniWave = bossWave - 5;
    if (this.wave === bossWave) tier = "boss";
    else if (this.wave === miniWave) tier = "mini";
    else if (this.wave === 5 && this.spawnRemaining === Math.min(12, 4 + Math.ceil(this.wave * 0.55))) tier = "rare";
    else if (this.wave >= 5 && Math.random() < Math.min(0.35, 0.08 + this.wave * 0.015)) tier = "rare";
    this.spawnEnemy(tier);
    this.spawnRemaining -= 1;
    this.spawnTimer = tier === "common" ? Math.max(0.34, 0.92 - this.wave * 0.025) : 1.05;
  }

  spawnEnemy(tier = "common", options = {}) {
    const commonPool = this.area.commons.map((data, index) => ({ data, assetKey: this.area.commonKey, index }));
    const reinforcement = REINFORCEMENTS[this.areaIndex];
    if (reinforcement) commonPool.push({ data: [reinforcement[2], reinforcement[1], reinforcement[3]], assetKey: reinforcement[0], index: commonPool.length });
    const commonIndex = options.commonIndex ?? Math.floor(Math.random() * commonPool.length);
    const commonEntry = commonPool[commonIndex % commonPool.length];
    const data = tier === "common"
      ? commonEntry.data
      : tier === "rare"
        ? this.area.rare
        : tier === "mini"
          ? this.area.mini
          : this.area.boss;
    const size = tier === "boss" ? Math.min(154, this.width * 0.34) : tier === "mini" ? 104 : tier === "rare" ? 76 : 58;
    const baseHp = tier === "boss" ? 58 + this.areaIndex * 13 : tier === "mini" ? 22 + this.areaIndex * 4 : tier === "rare" ? 5 + this.areaIndex * 0.8 : 1.35 + this.areaIndex * 0.22 + this.wave * 0.04;
    const fromRight = tier === "common" && !options.child && this.wave > 1 && Math.random() < 0.18 + this.wave * 0.006;
    const x = fromRight ? this.width + size : 34 + Math.random() * (this.width - 68);
    const enemy = {
      id: this.nextId++,
      name: data[0],
      animation: data[1],
      behavior: tier === "common" ? data[2] : tier,
      tier,
      commonIndex,
      assetKey: tier === "common" ? commonEntry.assetKey : this.area.eliteKey,
      x,
      y: tier === "boss" ? this.height * 0.27 : fromRight ? this.groundY : -size * 0.25,
      originX: x,
      state: tier === "boss" ? "hover" : fromRight ? "ground" : "air",
      size,
      hp: baseHp,
      maxHp: baseHp,
      speed: this.tuning.enemySpeed * (0.74 + this.areaIndex * 0.045 + this.wave * 0.018) * (tier === "rare" ? 0.82 : 1),
      shootTimer: 0.7 + Math.random() * 1.5,
      actionTimer: 0,
      armor: data[2] === "armored" ? 1 : 0,
      child: Boolean(options.child),
      revived: false,
      dead: false,
    };
    this.enemies.push(enemy);
    return enemy;
  }

  updateArrows(dt) {
    for (const arrow of this.arrows) {
      if (arrow.homing) {
        const target = this.enemies.filter((enemy) => !enemy.dead && !arrow.hits.has(enemy.id)).sort((a, b) => distanceSquared(arrow.x, arrow.y, a.x, a.y) - distanceSquared(arrow.x, arrow.y, b.x, b.y))[0];
        if (target) {
          const speed = Math.hypot(arrow.vx, arrow.vy);
          const dx = target.x - arrow.x;
          const dy = target.y - target.size * 0.45 - arrow.y;
          const length = Math.hypot(dx, dy) || 1;
          arrow.vx += ((dx / length) * speed - arrow.vx) * dt * 7;
          arrow.vy += ((dy / length) * speed - arrow.vy) * dt * 7;
        }
      }
      arrow.x += arrow.vx * dt;
      arrow.y += arrow.vy * dt;
      arrow.age += dt;
      if (arrow.x < -80 || arrow.x > this.width + 80 || arrow.y < -100 || arrow.y > this.height + 60) arrow.dead = true;
    }
    this.arrows = this.arrows.filter((arrow) => !arrow.dead);
  }

  updateEnemies(dt) {
    for (const enemy of this.enemies) {
      if (enemy.dead) continue;
      enemy.actionTimer += dt;
      enemy.shootTimer -= dt;
      enemy.slowTimer = Math.max(0, enemy.slowTimer - dt);
      enemy.rootTimer = Math.max(0, enemy.rootTimer - dt);
      enemy.stunTimer = Math.max(0, enemy.stunTimer - dt);
      enemy.poisonTimer = Math.max(0, enemy.poisonTimer - dt);
      if (enemy.poisonTimer > 0) {
        enemy.hp -= dt * 1.4 * this.skin.power;
        if (enemy.hp <= 0) {
          this.killEnemy(enemy, false);
          continue;
        }
      }
      const motionScale = enemy.slowTimer > 0 || this.player.buffs.freeze > 0 ? 0.45 : 1;
      if ((enemy.behavior === "pull" || (enemy.tier !== "common" && [11, 12, 13, 14, 17, 19].includes(this.areaIndex))) && enemy.state !== "ground") {
        this.player.x += (enemy.x - this.player.x) * dt * (0.07 + this.areaIndex * 0.003);
        this.player.x = clamp(this.player.x, 34, this.width - 34);
      }
      if (enemy.tier === "boss") {
        if (enemy.stunTimer > 0) continue;
        this.updateBoss(enemy, dt);
        continue;
      }
      if (enemy.tier === "mini") {
        if (enemy.rootTimer > 0 || enemy.stunTimer > 0) continue;
        if (enemy.state === "air") {
          enemy.y += enemy.speed * 0.45 * dt * motionScale;
          enemy.x += Math.sin(this.time * 2.8 + enemy.id) * enemy.speed * 0.28 * dt * motionScale;
          if (enemy.y > this.height * 0.3) enemy.state = "hover";
        } else if (enemy.state === "hover") {
          enemy.x += Math.sin(this.time * 2.2 + enemy.id) * enemy.speed * 0.45 * dt * motionScale;
        }
        if (enemy.shootTimer <= 0) {
          this.shootAtPlayer(enemy, 210 + this.areaIndex * 8);
          enemy.shootTimer = 1.45;
        }
        continue;
      }
      if (enemy.rootTimer > 0 || enemy.stunTimer > 0) continue;
      if (enemy.state === "air") {
        const phase = this.time * (enemy.tier === "rare" ? 4 : 2.2) + enemy.id;
        const horizontal = ["zigzag", "swoop", "circle", "teleport"].includes(enemy.behavior) || enemy.tier === "rare";
        enemy.x += (horizontal ? Math.sin(phase) * enemy.speed * 0.62 * dt : Math.sin(phase) * enemy.speed * 0.12 * dt) * motionScale;
        enemy.y += enemy.speed * (enemy.behavior === "float" ? 0.55 : enemy.behavior === "meteor" ? 1.65 : 1) * dt * motionScale;
        if (enemy.behavior === "teleport" && Math.floor(enemy.actionTimer * 2.2) !== Math.floor((enemy.actionTimer - dt) * 2.2)) {
          enemy.x = clamp(enemy.x + (Math.random() - 0.5) * 110, 30, this.width - 30);
        }
        if (enemy.y >= this.groundY) {
          enemy.y = this.groundY;
          enemy.state = "ground";
          enemy.actionTimer = 0;
        }
      } else if (enemy.state === "ground") {
        const direction = Math.sign(this.player.x - enemy.x) || -1;
        enemy.x += direction * enemy.speed * (enemy.behavior === "rush" ? 1.45 : 0.72) * dt * motionScale;
      }
      if (["shooter", "hover"].includes(enemy.behavior) || enemy.tier === "rare") {
        if (enemy.shootTimer <= 0 && enemy.state !== "ground") {
          this.shootAtPlayer(enemy, 170 + this.areaIndex * 8);
          enemy.shootTimer = enemy.tier === "rare" ? 1.7 : 2.6;
        }
      }
      enemy.x = clamp(enemy.x, -enemy.size, this.width + enemy.size);
    }
  }

  updateBoss(enemy, dt) {
    const hpRatio = enemy.hp / enemy.maxHp;
    if (this.areaIndex === 3 && hpRatio < 0.3) {
      enemy.state = "ground";
      enemy.y = this.groundY;
      enemy.x += Math.sign(this.player.x - enemy.x) * enemy.speed * 0.7 * dt;
    } else if ([9, 19].includes(this.areaIndex) && hpRatio < 0.66 && hpRatio >= 0.33) {
      enemy.state = "ground";
      enemy.y = this.groundY;
      enemy.x += Math.sign(this.player.x - enemy.x) * enemy.speed * 0.45 * dt;
    } else {
      enemy.state = "hover";
      enemy.y = this.height * ([9, 19].includes(this.areaIndex) && hpRatio < 0.33 ? 0.47 : 0.27) + Math.sin(this.time * 1.6) * 12;
      enemy.x = this.width * 0.5 + Math.sin(this.time * (0.72 + this.areaIndex * 0.04)) * this.width * 0.27;
    }
    if (enemy.shootTimer <= 0) {
      this.bossAttack(enemy, hpRatio);
      enemy.shootTimer = Math.max(0.72, 1.55 - this.areaIndex * 0.055 - (1 - hpRatio) * 0.35);
    }
  }

  bossAttack(enemy, hpRatio) {
    const shootSpread = (count, speed, spread = 0.7) => {
      for (let index = 0; index < count; index += 1) {
        const angle = Math.PI / 2 + (index - (count - 1) / 2) * spread / Math.max(1, count - 1);
        this.projectiles.push({ x: enemy.x, y: enemy.y - enemy.size * 0.35, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, type: "orb", size: 13, age: 0, dead: false });
      }
    };
    if (this.areaIndex === 0) shootSpread(3, 190, 1.05);
    if (this.areaIndex === 1) {
      shootSpread(1, 175);
      if (this.enemies.length < 6) this.spawnEnemy("common", { commonIndex: 0, child: true });
    }
    if (this.areaIndex === 2) this.projectiles.push({ x: this.player.x, y: -40, vx: 0, vy: 155, type: "tornado", size: 32, age: 0, dead: false });
    if (this.areaIndex === 3) {
      for (let index = 0; index < 4; index += 1) this.projectiles.push({ x: 25 + Math.random() * (this.width - 50), y: -25, vx: 0, vy: 190, type: "acid", size: 11, age: 0, dead: false });
    }
    if (this.areaIndex === 4) this.spawnBeam(this.player.x, 22);
    if (this.areaIndex === 5) shootSpread(5, 215, 1.3);
    if (this.areaIndex === 6) shootSpread(2, 210, 0.5);
    if (this.areaIndex === 7) {
      for (let index = 0; index < 3; index += 1) this.spawnBeam(35 + Math.random() * (this.width - 70), 18);
    }
    if (this.areaIndex === 8) {
      enemy.x = 50 + Math.random() * (this.width - 100);
      shootSpread(4, 205, 1.15);
      this.projectiles.push({ x: this.width + 40, y: this.groundY - 12, vx: -245, vy: 0, type: "wave", size: 28, age: 0, dead: false });
    }
    if (this.areaIndex === 9) {
      if (hpRatio > 0.66) shootSpread(5, 220, 1.35);
      else if (hpRatio > 0.33) {
        this.projectiles.push({ x: this.width + 40, y: this.groundY - 12, vx: -270, vy: 0, type: "wave", size: 30, age: 0, dead: false });
        this.projectiles.push({ x: -40, y: this.groundY - 12, vx: 270, vy: 0, type: "wave", size: 30, age: 0, dead: false });
      } else {
        this.spawnBeam(this.player.x, 34);
        shootSpread(3, 235, 0.8);
        if (this.enemies.length < 4) this.spawnEnemy("common", { commonIndex: 2, child: true });
      }
    }
    if (this.areaIndex === 10) {
      shootSpread(6, 225, 1.45);
      this.spawnBeam(this.player.x, 18);
    }
    if (this.areaIndex === 11) {
      this.player.x += (enemy.x - this.player.x) * 0.16;
      shootSpread(4, 215, 1.2);
    }
    if (this.areaIndex === 12) {
      shootSpread(3, 175, 0.7);
      for (const target of this.enemies) target.slowTimer = Math.max(target.slowTimer, 0.8);
    }
    if (this.areaIndex === 13) {
      this.player.x += (enemy.x - this.player.x) * 0.12;
      for (let index = 0; index < 4; index += 1) this.projectiles.push({ x: 30 + Math.random() * (this.width - 60), y: -20, vx: 0, vy: 205, type: "acid", size: 13, age: 0, dead: false });
    }
    if (this.areaIndex === 14) {
      shootSpread(7, 225, 1.5);
      if (this.enemies.length < 5) this.spawnEnemy("common", { commonIndex: 1, child: true });
    }
    if (this.areaIndex === 15) {
      enemy.x = this.width - enemy.x;
      shootSpread(6, 230, 1.4);
    }
    if (this.areaIndex === 16) {
      shootSpread(5, 240, 1.55);
      this.projectiles.push({ x: this.width + 40, y: this.groundY - 12, vx: -285, vy: 0, type: "wave", size: 30, age: 0, dead: false });
    }
    if (this.areaIndex === 17) {
      this.player.x += (enemy.x - this.player.x) * 0.2;
      this.spawnBeam(this.player.x, 28);
      shootSpread(3, 235, 0.8);
    }
    if (this.areaIndex === 18) {
      shootSpread(6, 245, 1.5);
      if (this.enemies.length < 5) this.spawnEnemy("common", { commonIndex: Math.floor(Math.random() * 3), child: true });
    }
    if (this.areaIndex === 19) {
      this.player.x += (enemy.x - this.player.x) * (hpRatio < 0.33 ? 0.22 : 0.1);
      if (hpRatio > 0.66) shootSpread(7, 245, 1.7);
      else if (hpRatio > 0.33) {
        this.spawnBeam(this.player.x, 34);
        shootSpread(5, 255, 1.3);
      } else {
        for (let index = 0; index < 3; index += 1) this.spawnBeam(30 + Math.random() * (this.width - 60), 26);
        shootSpread(9, 270, 1.85);
      }
    }
    if (this.areaIndex >= 20) {
      const phase = this.areaIndex - 20;
      shootSpread(5 + Math.floor(phase / 2), 235 + phase * 5, 1.35 + phase * 0.05);
      if (phase % 3 === 0) this.spawnBeam(this.player.x, 22 + phase);
      if (phase % 3 === 1) this.player.x += (enemy.x - this.player.x) * 0.12;
      if (phase % 3 === 2) this.projectiles.push({ x: this.width + 40, y: this.groundY - 12, vx: -275 - phase * 4, vy: 0, type: "wave", size: 28, age: 0, dead: false });
      if (hpRatio < 0.45 && this.enemies.length < 5) this.spawnEnemy("common", { commonIndex: Math.floor(Math.random() * this.area.commons.length), child: true });
    }
  }

  spawnBeam(x, size) {
    this.projectiles.push({ x, y: 0, vx: 0, vy: 0, type: "beam", size, age: 0, dead: false });
  }

  shootAtPlayer(enemy, speed) {
    const dx = this.player.x - enemy.x;
    const dy = this.player.y - 35 - enemy.y;
    const length = Math.hypot(dx, dy) || 1;
    this.projectiles.push({ x: enemy.x, y: enemy.y - enemy.size * 0.45, vx: (dx / length) * speed, vy: (dy / length) * speed, type: "orb", size: 10, age: 0, dead: false });
  }

  updateProjectiles(dt) {
    for (const projectile of this.projectiles) {
      projectile.age += dt;
      if (projectile.type === "beam") {
        if (projectile.age > 1.18) projectile.dead = true;
        continue;
      }
      projectile.x += projectile.vx * dt;
      projectile.y += projectile.vy * dt;
      if (projectile.x < -90 || projectile.x > this.width + 90 || projectile.y > this.height + 80) projectile.dead = true;
    }
    this.projectiles = this.projectiles.filter((projectile) => !projectile.dead);
  }

  updatePickups(dt) {
    for (const pickup of this.pickups) {
      pickup.vy += 480 * dt;
      pickup.y += pickup.vy * dt;
      if (pickup.y > this.groundY - 8) {
        pickup.y = this.groundY - 8;
        pickup.vy = 0;
      }
      const pickupRange = this.player.buffs.magnet > 0 || this.relics.has("Inti Gravitasi") ? 150 : 30;
      if (Math.abs(pickup.x - this.player.x) < pickupRange && Math.abs(pickup.y - this.player.y) < 110) {
        if (pickupRange > 30) pickup.x += (this.player.x - pickup.x) * dt * 8;
      }
      if (Math.abs(pickup.x - this.player.x) < 30 && Math.abs(pickup.y - this.player.y) < 65) {
        pickup.dead = true;
        if (pickup.kind === "coin") {
          this.coins += pickup.value;
          this.score += pickup.value * 8;
        } else {
          this.applyPowerup(pickup.kind);
        }
        this.audio.play("coin");
      }
    }
    this.pickups = this.pickups.filter((pickup) => !pickup.dead);
  }

  applyPowerup(kind) {
    const player = this.player;
    if (kind === "multishot") player.buffs.multishot = 10;
    if (kind === "shield") player.shieldCharges += 1;
    if (kind === "haste") player.buffs.haste = 10;
    if (kind === "power") player.buffs.power = 10;
    if (kind === "freeze") player.buffs.freeze = 8;
    if (kind === "magnet") player.buffs.magnet = 12;
    if (kind === "heal") player.health = Math.min(player.maxHealth, player.health + 1);
    if (kind === "critical") player.buffs.critical = 10;
    if (kind === "cooldown") {
      player.skill1Cooldown = 0;
      player.skill2Cooldown = 0;
    }
    if (kind === "nova") player.ultimate = 100;
    this.effects.push({ x: player.x, y: player.y - 55, type: "skin_skill2", age: 0, duration: 0.55, size: 105, color: this.skin.color });
  }

  resolveArrowHits() {
    for (const arrow of this.arrows) {
      for (const enemy of this.enemies) {
        if (enemy.dead || arrow.dead || arrow.hits.has(enemy.id)) continue;
        const centerY = enemy.y - enemy.size * 0.46;
        const radius = enemy.size * (enemy.tier === "boss" ? 0.43 : 0.36);
        if (distanceSquared(arrow.x, arrow.y, enemy.x, centerY) > radius ** 2) continue;
        arrow.hits.add(enemy.id);
        const shieldedBoss = enemy.tier === "boss" && this.areaIndex === 6 && Math.sin(this.time * 2.1) < -0.1;
        const phasedGhost = enemy.tier === "rare" && this.areaIndex === 4 && Math.sin(this.time * 3) < -0.4;
        if (!shieldedBoss && !phasedGhost) {
          const armorMultiplier = enemy.armor > 0 ? 0.35 : 1;
          enemy.hp -= arrow.damage * armorMultiplier;
          if (arrow.slow) enemy.slowTimer = Math.max(enemy.slowTimer, arrow.slow);
          if (arrow.poison) enemy.poisonTimer = Math.max(enemy.poisonTimer, arrow.poison);
          if (arrow.stun) enemy.stunTimer = Math.max(enemy.stunTimer, arrow.stun);
          if (arrow.omni) enemy.armor = 0;
          if (enemy.armor > 0) enemy.armor -= 1;
          this.effects.push({ x: arrow.x, y: arrow.y, type: arrow.critical ? "critical" : "impact", age: 0, duration: arrow.critical ? 0.4 : 0.25, size: (arrow.critical ? 82 : 48) * this.tuning.effectIntensity });
          this.audio.play("impact");
          if (arrow.aoe > 0) {
            const nearby = this.enemies.filter((candidate) => !candidate.dead && candidate.id !== enemy.id && distanceSquared(candidate.x, candidate.y, enemy.x, enemy.y) < arrow.aoe ** 2);
            this.damageTargets(nearby, arrow.damage * 0.65);
          }
          if (arrow.chain > 0) {
            const next = this.enemies.find((candidate) => !candidate.dead && candidate.id !== enemy.id && !arrow.hits.has(candidate.id));
            if (next) {
              next.hp -= arrow.damage * 0.8;
              if (next.hp <= 0) this.killEnemy(next, true);
            }
          }
          if (enemy.hp <= 0) this.killEnemy(enemy, arrow.critical);
        } else {
          this.effects.push({ x: arrow.x, y: arrow.y, type: "impact", age: 0, duration: 0.18, size: 34 });
        }
        if (!arrow.pierce || arrow.hits.size >= (arrow.maxHits || 1)) arrow.dead = true;
      }
    }
  }

  killEnemy(enemy, critical = false) {
    if (!enemy || enemy.dead) return;
    if (enemy.tier === "boss" && this.areaIndex === 5 && !enemy.revived) {
      enemy.revived = true;
      enemy.hp = enemy.maxHp * 0.42;
      enemy.size *= 0.82;
      this.effects.push({ x: enemy.x, y: enemy.y - enemy.size * 0.5, type: "boss_collapse", sheet: "defeat", age: 0, duration: 0.55, size: enemy.size * 1.25 });
      return;
    }
    enemy.dead = true;
    const effectType = enemy.tier === "boss" ? "boss_collapse" : enemy.tier === "mini" ? "mini_break" : enemy.tier === "rare" ? "rare_dissolve" : "common_burst";
    this.effects.push({ x: enemy.x, y: enemy.y - enemy.size * 0.45, type: effectType, sheet: "defeat", age: 0, duration: enemy.tier === "boss" ? 0.9 : 0.48, size: enemy.size * (enemy.tier === "boss" ? 1.45 : 1.15) });
    const value = enemy.tier === "boss" ? 80 : enemy.tier === "mini" ? 35 : enemy.tier === "rare" ? 12 : 3;
    this.score += value * 25 + (critical ? value * 8 : 0);
    this.pickups.push({ x: enemy.x, y: enemy.y - enemy.size * 0.5, vy: -110, value, kind: "coin", dead: false });
    this.player.ultimate = Math.min(100, this.player.ultimate + (enemy.tier === "boss" ? 40 : enemy.tier === "mini" ? 28 : enemy.tier === "rare" ? 16 : 4));
    const powerupChance = enemy.tier === "mini" ? 1 : enemy.tier === "rare" ? 0.45 : enemy.tier === "common" ? 0.06 : 0;
    if (Math.random() < powerupChance) {
      const kinds = ["multishot", "shield", "haste", "power", "freeze", "magnet", "heal", "critical", "cooldown", "nova"];
      const kind = kinds[Math.floor(Math.random() * kinds.length)];
      this.pickups.push({ x: enemy.x + 16, y: enemy.y - enemy.size * 0.55, vy: -145, value: 0, kind, dead: false });
    }
    if (enemy.behavior === "split" && !enemy.child && enemy.tier === "common") {
      for (const direction of [-1, 1]) {
        const child = this.spawnEnemy("common", { commonIndex: enemy.commonIndex, child: true });
        child.x = clamp(enemy.x + direction * 18, 25, this.width - 25);
        child.y = enemy.y;
        child.size *= 0.62;
        child.hp = 0.7;
        child.maxHp = 0.7;
        child.state = enemy.state;
      }
    }
    if (this.relics.has("Mahkota Petir") && critical) {
      const next = this.enemies.find((candidate) => !candidate.dead && candidate.id !== enemy.id);
      if (next) {
        next.hp -= 1.5;
        this.effects.push({ x: next.x, y: next.y - next.size * 0.45, type: "critical", age: 0, duration: 0.3, size: 62 });
        if (next.hp <= 0) this.killEnemy(next, false);
      }
    }
    if (this.relics.has("Taring Void")) {
      const closest = this.projectiles.reduce((best, projectile) => {
        const distance = distanceSquared(enemy.x, enemy.y, projectile.x, projectile.y);
        return !best || distance < best.distance ? { projectile, distance } : best;
      }, null);
      if (closest && closest.distance < 160 ** 2) closest.projectile.dead = true;
    }
    this.audio.play("defeat");
  }

  resolvePlayerHits() {
    const playerCenterY = this.player.y - 42;
    for (const enemy of this.enemies) {
      if (enemy.dead) continue;
      const centerY = enemy.y - enemy.size * 0.42;
      const touching = distanceSquared(this.player.x, playerCenterY, enemy.x, centerY) < (enemy.size * 0.34 + 22) ** 2;
      if (touching && enemy.state === "ground") {
        if (this.skinIndex === 3 && this.player.shieldCharges > 0) enemy.rootTimer = 4;
        this.hurtPlayer("ground");
        enemy.x += Math.sign(enemy.x - this.player.x || 1) * 35;
      }
    }
    for (const projectile of this.projectiles) {
      if (projectile.dead) continue;
      let hit = false;
      if (projectile.type === "beam") hit = projectile.age > 0.68 && projectile.age < 1.05 && Math.abs(projectile.x - this.player.x) < projectile.size;
      else if (projectile.type === "wave") hit = this.player.grounded && distanceSquared(this.player.x, playerCenterY, projectile.x, projectile.y) < (projectile.size + 22) ** 2;
      else hit = distanceSquared(this.player.x, playerCenterY, projectile.x, projectile.y) < (projectile.size + 20) ** 2;
      if (hit) {
        projectile.dead = true;
        this.hurtPlayer(projectile.type === "wave" ? "ground" : "projectile");
      }
    }
  }

  hurtPlayer(source) {
    if (this.player.invulnerable > 0 || this.ended) return;
    if (this.player.shieldCharges > 0) {
      this.player.shieldCharges -= 1;
      this.player.invulnerable = 0.8;
      this.effects.push({ x: this.player.x, y: this.player.y - 42, type: "skin_skill2", age: 0, duration: 0.4, size: 95, color: this.skin.color });
      return;
    }
    if (source === "ground" && this.relics.has("Kulit Kayu Titan") && !this.player.shieldUsed) {
      this.player.shieldUsed = true;
      this.player.invulnerable = 0.8;
      this.effects.push({ x: this.player.x, y: this.player.y - 42, type: "critical", age: 0, duration: 0.35, size: 88 });
      return;
    }
    this.player.health -= 1;
    this.player.invulnerable = 1.15;
    this.player.hurtTimer = 0.38;
    this.audio.play("hurt");
    this.callbacks.onHit?.();
    if (this.player.health <= 0 && this.relics.has("Abu Phoenix") && !this.player.phoenixUsed) {
      this.player.phoenixUsed = true;
      this.player.health = 1;
      this.player.invulnerable = 2;
      this.effects.push({ x: this.player.x, y: this.player.y - 40, type: "boss_collapse", sheet: "defeat", age: 0, duration: 0.8, size: 110 });
      return;
    }
    if (this.player.health <= 0) {
      this.ended = true;
      this.paused = true;
      this.bestScore = Math.max(this.bestScore, this.score);
      this.callbacks.onGameOver?.(this.snapshot());
    }
  }

  checkWaveClear(dt) {
    this.enemies = this.enemies.filter((enemy) => !enemy.dead);
    if (this.spawnRemaining > 0 || this.enemies.length > 0) {
      this.waveClearTimer = 0;
      return;
    }
    this.waveClearTimer += dt;
    if (this.waveClearTimer < 0.85) return;
    this.waveClearTimer = -999;
    this.projectiles.length = 0;
    this.score += this.wave * 45;
    const bossWave = this.area.waveCount || 15;
    const miniWave = bossWave - 5;
    if (this.wave === miniWave && this.relics.has("Inti Lumut")) this.player.health = Math.min(this.player.maxHealth, this.player.health + 1);
    if (this.wave === bossWave) {
      this.paused = true;
      this.relics.add(this.area.relic[0]);
      this.callbacks.onAreaComplete?.(this.snapshot());
      return;
    }
    if (this.wave === 5 || this.wave === 10 || this.wave === miniWave) {
      this.paused = true;
      this.callbacks.onUpgrade?.(this.snapshot());
      return;
    }
    this.wave += 1;
    this.startWave();
  }

  playerAnimation() {
    if (this.player.actionTimer > 0 && this.player.actionName) return { key: this.skin.skillKey, name: this.player.actionName };
    if (this.player.shootTimer > 0) return { key: this.skin.coreKey, name: "shoot" };
    if (!this.player.grounded) return { key: this.skin.coreKey, name: "jump" };
    const move = this.input.movement();
    if (move.axis || (move.target !== null && Math.abs(move.target - this.player.x) > 3)) return { key: this.skin.coreKey, name: "run" };
    return { key: this.skin.coreKey, name: "idle" };
  }

  snapshot() {
    const boss = this.enemies.find((enemy) => enemy.tier === "boss" && !enemy.dead);
    return {
      areaIndex: this.areaIndex,
      areaName: this.area.name,
      wave: this.wave,
      totalWaves: this.area.waveCount || 15,
      score: this.score,
      bestScore: this.bestScore,
      coins: this.coins,
      health: this.player.health,
      maxHealth: this.player.maxHealth,
      skinIndex: this.skinIndex,
      skin: this.skin,
      skills: {
        skill1: this.player.skill1Cooldown,
        skill2: this.player.skill2Cooldown,
        ultimate: this.player.ultimate,
      },
      boss: boss ? { name: boss.name, ratio: boss.hp / boss.maxHp } : null,
      player: this.player,
      playerAnimation: this.playerAnimation(),
      arrows: this.arrows,
      enemies: this.enemies,
      projectiles: this.projectiles,
      pickups: this.pickups,
      effects: this.effects,
      abilityZones: this.abilityZones,
      timeStop: this.timeStop,
      damageModeTimer: this.damageModeTimer,
      time: this.time,
      groundY: this.groundY,
      width: this.width,
      height: this.height,
      paused: this.paused,
      started: this.started,
    };
  }
}
