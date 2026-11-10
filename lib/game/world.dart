// Gameplay logic, without rendering.
import 'dart:math';

import 'data.dart';

double clampd(double value, double minimum, double maximum) =>
    max(minimum, min(maximum, value));

double distanceSquared(double ax, double ay, double bx, double by) {
  final dx = ax - bx;
  final dy = ay - by;
  return dx * dx + dy * dy;
}

/// Mirrors JavaScript Math.max: any NaN operand makes the result NaN.
/// The web code never initialises enemy timers, so they start as `undefined`
/// and become NaN on first update; keeping NaN here reproduces that behaviour.
double jsMax(double a, double b) =>
    (a.isNaN || b.isNaN) ? double.nan : max(a, b);

/// First element with the largest key (same result as a stable JS sort()[0]).
T? firstMaxBy<T>(Iterable<T> items, double Function(T) key) {
  T? best;
  var bestKey = double.negativeInfinity;
  for (final item in items) {
    final k = key(item);
    if (best == null || k > bestKey) {
      best = item;
      bestKey = k;
    }
  }
  return best;
}

/// First element with the smallest key.
T? firstMinBy<T>(Iterable<T> items, double Function(T) key) {
  T? best;
  var bestKey = double.infinity;
  for (final item in items) {
    final k = key(item);
    if (best == null || k < bestKey) {
      best = item;
      bestKey = k;
    }
  }
  return best;
}

/// Multiplier on every enemy's speed (1.3 = 30% faster).
const double kEnemyDifficulty = 1.3;

/// Extra multiplier on every enemy's health (1.3 = 30% tougher).
const double kEnemyHpMultiplier = 1.3;

class Tuning {
  const Tuning({
    this.playerSpeed = 420,
    this.jumpForce = 620,
    this.gravity = 1600,
    this.baseFireRate = 2.6,
    this.enemySpeed = 88,
    this.effectIntensity = 1,
  });

  // Default gameplay values.
  final double playerSpeed;
  final double jumpForce;
  final double gravity;
  final double baseFireRate;
  final double enemySpeed;
  final double effectIntensity;
}

class MoveIntent {
  const MoveIntent(this.axis, this.target, {this.fire = false});
  final double axis;
  final double? target;

  /// True while the fire button (or key) is held.
  final bool fire;
}

abstract class MovementSource {
  MoveIntent movement();
}

class Enemy {
  Enemy({
    required this.id,
    required this.name,
    required this.animation,
    required this.behavior,
    required this.tier,
    required this.commonIndex,
    required this.assetKey,
    required this.x,
    required this.y,
    required this.originX,
    required this.state,
    required this.size,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.shootTimer,
    required this.armor,
    required this.child,
  });

  final int id;
  final String name;
  final String animation;
  final String behavior;
  final String tier; // common | rare | mini | boss
  final int commonIndex;
  final String assetKey;
  double x;
  double y;
  final double originX;
  String state; // ground | air | hover
  double size;
  double hp;
  double maxHp;
  double speed;
  double shootTimer;
  double actionTimer = 0;
  int armor;
  final bool child;
  bool revived = false;
  bool dead = false;
  // Start as NaN, like `undefined` in the web code.
  double slowTimer = double.nan;
  double rootTimer = double.nan;
  double stunTimer = double.nan;
  double poisonTimer = double.nan;
}

class Arrow {
  Arrow({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    this.critical = false,
    this.pierce = false,
    this.maxHits = 1,
    this.homing = false,
    this.aoe = 0,
    this.slow = 0,
    this.poison = 0,
    this.stun = 0,
    this.chain = 0,
    this.omni = false,
  });

  double x;
  double y;
  double vx;
  double vy;
  double damage;
  bool critical;
  bool pierce;
  int maxHits;
  bool homing;
  double aoe;
  double slow;
  double poison;
  double stun;
  int chain;
  bool omni;
  final Set<int> hits = {};
  double age = 0;
  bool dead = false;
}

class Projectile {
  Projectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.type,
    required this.size,
  });

  double x;
  double y;
  double vx;
  double vy;
  final String type; // orb | tornado | acid | beam | wave
  final double size;
  double age = 0;
  bool dead = false;
}

class Pickup {
  Pickup({
    required this.x,
    required this.y,
    required this.vy,
    required this.value,
    required this.kind,
  });

  double x;
  double y;
  double vy;
  final double value;
  final String kind; // coin or powerup name
  bool dead = false;
}

class Effect {
  Effect({
    required this.x,
    required this.y,
    required this.type,
    required this.duration,
    required this.size,
    this.age = 0,
    this.sheet,
    this.sheetKey,
    this.animation,
    this.color,
  });

  double x;
  double y;
  final String type;
  double age;
  final double duration;
  final double size;
  final String? sheet; // defeat | arrow
  final String? sheetKey;
  final String? animation;
  final String? color;
}

class AbilityZone {
  AbilityZone({
    required this.type,
    required this.duration,
    required this.x,
    this.y,
    this.radius,
    this.damage = 0,
    this.interval,
    this.count,
  });

  final String type;
  final double duration;
  double age = 0;
  double tick = 0;
  double x;
  double? y;
  double? radius;
  double damage;
  double? interval;
  int? count;
}

class PlayerState {
  PlayerState({required this.x, required this.y});

  double x;
  double y;
  double vy = 0;
  bool grounded = true;
  int health = 3;
  int maxHealth = 3;
  double invulnerable = 0;
  double fireTimer = 0;
  double shootTimer = 0;
  double hurtTimer = 0;
  double facing = 1;
  bool shieldUsed = false;
  bool phoenixUsed = false;
  int shotCount = 0;
  double skill1Cooldown = 0;
  double skill2Cooldown = 0;
  double ultimate = 25;
  double actionTimer = 0;
  double slowTimer = 0;
  String actionName = '';
  double meleeCooldown = 0;
  int shieldCharges = 0;
  final Map<String, double> buffs = {
    'multishot': 0,
    'haste': 0,
    'power': 0,
    'critical': 0,
    'freeze': 0,
    'magnet': 0,
  };
}

/// Read-only data handed to the HUD and the overlays (the web `snapshot()`).
class HudState {
  const HudState({
    required this.areaIndex,
    required this.areaName,
    required this.wave,
    required this.totalWaves,
    required this.score,
    required this.bestScore,
    required this.coins,
    required this.health,
    required this.maxHealth,
    required this.skinIndex,
    required this.skill1,
    required this.skill2,
    required this.ultimate,
    required this.bossName,
    required this.bossRatio,
    this.upgradeTokens = 0,
  });

  final int areaIndex;
  final String areaName;
  final int wave;
  final int totalWaves;
  final double score;
  final double bestScore;
  final int coins;
  final int health;
  final int maxHealth;
  final int skinIndex;
  final double skill1;
  final double skill2;
  final double ultimate;
  final String? bossName;
  final double bossRatio;
  final int upgradeTokens;
}

class WorldCallbacks {
  const WorldCallbacks({
    this.onHit,
    this.onUltimate,
    this.onUpgrade,
    this.onAreaComplete,
    this.onGameOver,
  });

  final void Function()? onHit;
  final void Function()? onUltimate;
  final void Function()? onUpgrade;
  final void Function(HudState state)? onAreaComplete;
  final void Function(HudState state)? onGameOver;
}

/// Sound effects are addressed by name.
abstract class SoundSink {
  void play(String name);
}

class GameWorld {
  GameWorld({
    required this.areaIndex,
    this.skinIndex = 0,
    required Iterable<String> relics,
    required this.tuning,
    required this.audio,
    required this.callbacks,
    required this.random,
  }) : area = kAreas[areaIndex],
       skin = kSkins[skinIndex],
       relics = Set<String>.of(relics) {
    player = makePlayer();
  }

  static const int skinCount = 20;
  static const int areaCount = 30;

  int areaIndex;
  AreaData area;
  int skinIndex;
  SkinData skin;
  final Set<String> relics;
  final Tuning tuning;
  final SoundSink audio;
  final WorldCallbacks callbacks;
  final Random random;
  MovementSource? input;

  double width = 400;
  double height = 700;
  double groundY = 590;
  double time = 0;
  int wave = 1;
  double score = 0;
  double bestScore = 0;
  int coins = 0;
  final Map<String, int> upgrades = {'damage': 0, 'fireRate': 0, 'speed': 0};

  /// Earned by clearing a wave; spent from the HUD upgrade button.
  int upgradeTokens = 0;
  final List<Arrow> arrows = [];
  final List<Enemy> enemies = [];
  final List<Projectile> projectiles = [];
  final List<Pickup> pickups = [];
  final List<Effect> effects = [];
  final List<AbilityZone> abilityZones = [];
  double timeStop = 0;
  double damageModeTimer = 0;
  double areaDamageBuff = 1;
  double flightTimer = 0;
  double contactDestroyTimer = 0;
  double reflectTimer = 0;
  double autoVolleyTimer = 0;
  bool started = false;
  bool paused = true;
  bool ended = false;
  late PlayerState player;
  int spawnRemaining = 0;
  double spawnTimer = 0;
  double waveClearTimer = 0;
  int nextId = 1;

  MoveIntent _noMove() => const MoveIntent(0, null);

  MoveIntent _movement() => input?.movement() ?? _noMove();

  PlayerState makePlayer() => PlayerState(x: width * 0.5, y: groundY);

  void setInput(MovementSource source) {
    input = source;
  }

  void setSkin(int index) {
    skinIndex = index.clamp(0, skinCount - 1);
    skin = kSkins[skinIndex];
  }

  void resize(double newWidth, double newHeight) {
    final oldWidth = width == 0 ? newWidth : width;
    final ratio = player.x / oldWidth;
    width = newWidth;
    height = newHeight;
    groundY = newHeight * (newHeight < newWidth * 1.15 ? 0.78 : 0.82);
    player.x = clampd(ratio * newWidth, 34, newWidth - 34);
    if (player.grounded) player.y = groundY;
  }

  void begin() {
    if (started && !paused) return;
    started = true;
    paused = false;
    startWave();
  }

  void startWave() {
    paused = false;
    waveClearTimer = 0;
    spawnTimer = 0.25;
    projectiles.clear();
    final bossWave = area.waveCount;
    final miniWave = bossWave - 5;
    if (wave == bossWave || wave == miniWave) {
      spawnRemaining = 1;
    } else {
      spawnRemaining = min(12, 4 + (wave * 0.55).ceil());
    }
    if (wave == miniWave || wave == bossWave) audio.play('warning');
  }

  void resetArea(int index, {double? score, double? bestScore}) {
    areaIndex = index;
    area = kAreas[index];
    wave = 1;
    this.score = score ?? this.score;
    this.bestScore = bestScore ?? this.bestScore;
    coins = 0;
    upgrades.updateAll((_, _) => 0);
    arrows.clear();
    enemies.clear();
    projectiles.clear();
    pickups.clear();
    effects.clear();
    abilityZones.clear();
    timeStop = 0;
    damageModeTimer = 0;
    areaDamageBuff = 1;
    flightTimer = 0;
    contactDestroyTimer = 0;
    reflectTimer = 0;
    autoVolleyTimer = 0;
    player = makePlayer();
    player.x = width * 0.5;
    player.y = groundY;
    started = false;
    paused = true;
    ended = false;
  }

  void retryWave() {
    arrows.clear();
    enemies.clear();
    projectiles.clear();
    pickups.clear();
    effects.clear();
    abilityZones.clear();
    timeStop = 0;
    damageModeTimer = 0;
    flightTimer = 0;
    contactDestroyTimer = 0;
    reflectTimer = 0;
    player.health = player.maxHealth;
    player.invulnerable = 0;
    player.vy = 0;
    player.y = groundY;
    player.grounded = true;
    player.shieldUsed = false;
    ended = false;
    startWave();
  }

  void jump() {
    if (flightTimer > 0 && !paused && !ended) {
      player.y = max(height * 0.24, player.y - 75);
      audio.play('jump');
      return;
    }
    if (paused || ended || !player.grounded) return;
    player.vy = -tuning.jumpForce;
    player.grounded = false;
    audio.play('jump');
  }

  bool useSkill(String type) {
    if (paused || ended || !started) return false;
    final power = skin.power;
    if (type == 'skill1' && player.skill1Cooldown > 0) return false;
    if (type == 'skill2' && player.skill2Cooldown > 0) return false;
    if (type == 'ultimate' && player.ultimate < 100) return false;

    player.actionName = type;
    player.actionTimer = type == 'ultimate' ? 0.85 : 0.58;
    if (type == 'skill1') {
      player.skill1Cooldown = max(3.2, 5.8 - skinIndex * 0.09);
    }
    if (type == 'skill2') {
      player.skill2Cooldown = max(5.5, 9.4 - skinIndex * 0.15);
    }
    if (type == 'ultimate') player.ultimate = 0;

    activateExactSkill(skinIndex, type, power);
    effects.add(
      Effect(
        x: type == 'ultimate' ? width * 0.5 : player.x,
        y: type == 'ultimate' ? height * 0.42 : player.y - 90,
        type: 'skin_result',
        sheetKey: skin.effectKey,
        animation: type,
        duration: type == 'ultimate' ? 1.05 : 0.65,
        size: type == 'ultimate'
            ? max(width, height) * (0.68 + skinIndex * 0.02)
            : 120 + skinIndex * 5.0,
        color: skin.color,
      ),
    );
    if (type == 'ultimate') callbacks.onUltimate?.call();
    audio.play(type == 'ultimate' ? 'ultimate' : 'skill');
    return true;
  }

  void abilityArrow(
    double angle,
    double damage, {
    bool pierce = false,
    int maxHits = 0,
    bool homing = false,
    double aoe = 0,
    double slow = 0,
    double poison = 0,
    double stun = 0,
    int chain = 0,
    bool critical = false,
    bool omni = false,
  }) {
    final speed = max(540, height * 0.86);
    arrows.add(
      Arrow(
        x: player.x,
        y: player.y - 68,
        vx: sin(angle) * speed,
        vy: -cos(angle) * speed,
        damage: damage * areaDamageBuff * (damageModeTimer > 0 ? 3 : 1),
        critical: critical,
        pierce: pierce,
        maxHits: maxHits != 0 ? maxHits : (pierce ? 99 : 1),
        homing: homing,
        aoe: aoe,
        slow: slow,
        poison: poison,
        stun: stun,
        chain: chain,
        omni: omni,
      ),
    );
  }

  void damageTargets(
    Iterable<Enemy?> targets,
    double amount, {
    bool critical = false,
    bool killCommon = false,
  }) {
    for (final enemy in targets.toList()) {
      if (enemy == null || enemy.dead) continue;
      enemy.hp -= amount * areaDamageBuff * (damageModeTimer > 0 ? 3 : 1);
      if (killCommon && enemy.tier == 'common') enemy.hp = 0;
      if (enemy.hp <= 0) killEnemy(enemy, critical: critical);
    }
  }

  void addZone(
    String type,
    double duration, {
    double? x,
    double? y,
    double? radius,
    double damage = 0,
    double? interval,
    int? count,
  }) {
    abilityZones.add(
      AbilityZone(
        type: type,
        duration: duration,
        x: x ?? player.x,
        y: y,
        radius: radius,
        damage: damage,
        interval: interval,
        count: count,
      ),
    );
  }

  List<Enemy> living() => enemies.where((enemy) => !enemy.dead).toList();

  List<Enemy> airborne() =>
      living().where((enemy) => enemy.state != 'ground').toList();

  List<Enemy> commons() =>
      living().where((enemy) => enemy.tier == 'common').toList();

  Enemy? strongest() => firstMaxBy(living(), (enemy) => enemy.hp);

  void spread(
    int count,
    double arc,
    double damage, {
    bool pierce = false,
    int maxHits = 0,
    bool homing = false,
    double slow = 0,
  }) {
    for (var index = 0; index < count; index += 1) {
      abilityArrow(
        (index - (count - 1) / 2) * arc / max(1, count - 1),
        damage,
        pierce: pierce,
        maxHits: maxHits,
        homing: homing,
        slow: slow,
      );
    }
  }

  void activateExactSkill(int skin, String type, double power) {
    if (type == 'skill1') {
      if (skin == 0) {
        for (var index = 0; index < 3; index += 1) {
          abilityArrow(0, 1.8 * power, pierce: true, maxHits: 2);
        }
      }
      if (skin == 1) abilityArrow(0, 3 * power, pierce: true, maxHits: 3);
      if (skin == 2) abilityArrow(0, 3.2 * power, aoe: 78);
      if (skin == 3) spread(3, 0.5, 2.3 * power, slow: 2.4);
      if (skin == 4) abilityArrow(0, 3.4 * power, chain: 1);
      if (skin == 5) spread(2, 0.22, 2.8 * power, homing: true);
      if (skin == 6) {
        damageTargets(
          airborne().where((enemy) => (enemy.x - player.x).abs() < 120),
          5 * power,
        );
      }
      if (skin == 7) spread(5, 0.9, 2.8 * power);
      if (skin == 8) abilityArrow(0, 4 * power, pierce: true, poison: 4);
      if (skin == 9) addZone('drones', 5, damage: 1.3 * power, interval: 0.35);
      if (skin == 10) {
        abilityArrow(
          0,
          5.2 * power,
          pierce: true,
          maxHits: 4,
          chain: 4,
          critical: true,
        );
      }
      if (skin == 11) spread(9, 1.1, 2.2 * power, pierce: true, maxHits: 2);
      if (skin == 12) {
        addZone(
          'blackhole',
          2.4,
          x: player.x,
          y: height * 0.35,
          radius: 150,
          damage: 1.5 * power,
        );
      }
      if (skin == 13) spread(3, 0.16, 3.4 * power, pierce: true);
      if (skin == 14) {
        final targets = living().take(4).toList();
        damageTargets(targets, 4 * power);
        damageTargets(targets, 4 * power);
      }
      if (skin == 15) {
        abilityArrow(0, 4 * power, aoe: 95);
        spread(7, 1.1, 2 * power, homing: true);
      }
      if (skin == 16) damageTargets([strongest()], 9 * power, critical: true);
      if (skin == 17) {
        damageTargets(
          living().where((enemy) => (enemy.x - player.x).abs() < 62),
          12 * power,
          critical: true,
        );
      }
      if (skin == 18) {
        abilityArrow(
          0,
          9 * power,
          pierce: true,
          slow: 3,
          poison: 4,
          stun: 1.5,
          omni: true,
        );
      }
      if (skin == 19) {
        autoVolleyTimer = 8;
        for (final enemy in living()) {
          damageTargets([enemy], 2.5 * power);
        }
      }
    }

    if (type == 'skill2') {
      if (skin == 0) {
        for (final enemy in living().where(
          (enemy) => enemy.state == 'ground',
        )) {
          enemy.rootTimer = 2;
        }
      }
      if (skin == 1) {
        final oldX = player.x;
        player.x = clampd(player.x + player.facing * 125, 34, width - 34);
        player.invulnerable = 0.7;
        addZone('windtrap', 3, x: oldX, radius: 70, damage: 1.3 * power);
      }
      if (skin == 2) {
        jump();
        player.vy *= 1.35;
        addZone('firetrail', 3, x: player.x, radius: 105, damage: 1.8 * power);
      }
      if (skin == 3) {
        player.shieldCharges += 1;
        player.buffs['freeze'] = 4;
      }
      if (skin == 4) {
        addZone('totem', 3, x: player.x, damage: 2.2 * power, interval: 0.35);
      }
      if (skin == 5) {
        abilityArrow(0, 1.2 * power, homing: true, pierce: true, maxHits: 1);
        player.shieldCharges += 1;
      }
      if (skin == 6) addZone('wolf', 1.25, x: -40, damage: 7 * power);
      if (skin == 7) {
        projectiles.removeWhere(
          (projectile) =>
              distanceSquared(projectile.x, projectile.y, player.x, player.y) <=
              180 * 180,
        );
      }
      if (skin == 8) player.invulnerable = 2;
      if (skin == 9) {
        for (final enemy in living().where((enemy) => enemy.state == 'air')) {
          enemy.y = max(-50, enemy.y - 170);
        }
      }
      if (skin == 10) {
        damageTargets(living().take(6), 2.4 * power);
        player.health = min(player.maxHealth, player.health + 1);
      }
      if (skin == 11) addZone('crystalwall', 3, y: height * 0.48);
      if (skin == 12) {
        final oldX = player.x;
        player.x = player.facing > 0 ? width - 45 : 45;
        damageTargets(
          living().where((enemy) => (enemy.x - oldX).abs() < 95),
          5 * power,
        );
      }
      if (skin == 13) addZone('decoy', 4, x: player.x);
      if (skin == 14) timeStop = 3;
      if (skin == 15) {
        player.invulnerable = 4;
        contactDestroyTimer = 4;
      }
      if (skin == 16) {
        final enemy = strongest();
        if (enemy != null) {
          final oldX = player.x;
          player.x = enemy.x;
          enemy.x = oldX;
          enemy.stunTimer = 3;
        }
      }
      if (skin == 17) {
        flightTimer = 4;
        player.invulnerable = 4;
      }
      if (skin == 18) projectiles.clear();
      if (skin == 19) {
        reflectTimer = 6;
        player.invulnerable = 0.6;
      }
    }

    if (type == 'ultimate') {
      if (skin == 0) {
        addZone(
          'arrowrain',
          2.4,
          damage: 2.6 * power,
          interval: 0.12,
          count: 15,
        );
      }
      if (skin == 1) {
        addZone('tornado', 4, x: width * 0.5, radius: 170, damage: 1.5 * power);
      }
      if (skin == 2) {
        addZone('meteors', 1.8, damage: 8 * power, interval: 0.45, count: 3);
      }
      if (skin == 3) {
        timeStop = 4;
        projectiles.clear();
        for (final enemy in living()) {
          enemy.slowTimer = 4;
        }
      }
      if (skin == 4) {
        damageTargets(airborne().take(10), 10 * power, critical: true);
      }
      if (skin == 5) {
        addZone('gatling', 3, damage: 1.1 * power, interval: 0.055, count: 50);
      }
      if (skin == 6) {
        projectiles.clear();
        damageTargets(living(), 7 * power);
      }
      if (skin == 7) {
        damageTargets(
          living().where(
            (enemy) =>
                (enemy.x - width * 0.5).abs() < 120 ||
                (enemy.y - height * 0.42).abs() < 90,
          ),
          16 * power,
          critical: true,
        );
      }
      if (skin == 8) {
        timeStop = 5;
        damageModeTimer = 5;
      }
      if (skin == 9) damageTargets(living(), 15 * power, critical: true);
      if (skin == 10) {
        addZone('bloodfloor', 3, damage: 3.3 * power, interval: 0.25);
      }
      if (skin == 11) damageTargets(commons(), 9999, killCommon: true);
      if (skin == 12) {
        projectiles.clear();
        damageTargets(commons(), 9999, killCommon: true);
        damageTargets(
          living().where((enemy) => enemy.tier == 'boss'),
          18 * power,
        );
      }
      if (skin == 13) {
        addZone('clones', 5, damage: 2.2 * power, interval: 0.16, count: 5);
      }
      if (skin == 14) {
        addZone('timelasers', 5, damage: 3 * power, interval: 0.2, count: 3);
      }
      if (skin == 15) {
        damageTargets(living(), 35 * power, critical: true, killCommon: true);
      }
      if (skin == 16) {
        damageTargets(commons(), 9999, killCommon: true);
        for (final enemy in living().where((entry) => entry.tier == 'boss')) {
          enemy.armor = 0;
        }
      }
      if (skin == 17) {
        damageTargets(living(), 45 * power, critical: true, killCommon: true);
      }
      if (skin == 18) {
        timeStop = 0.55;
        final boss = living()
            .where((enemy) => enemy.tier == 'boss')
            .firstOrNull;
        if (boss != null) boss.hp *= 0.5;
        player.health = player.maxHealth;
      }
      if (skin == 19) {
        damageTargets(commons(), 9999, killCommon: true);
        projectiles.clear();
        areaDamageBuff *= 3;
      }
      player.invulnerable = max(player.invulnerable, 1.2);
    }
  }

  /// Spends one upgrade token from the HUD. Does not change the wave.
  void buyUpgrade(String key) {
    if (upgradeTokens <= 0 || !upgrades.containsKey(key)) return;
    upgradeTokens -= 1;
    upgrades[key] = upgrades[key]! + 1;
    audio.play('upgrade');
  }

  void chooseUpgrade(String key) {
    if (!upgrades.containsKey(key)) return;
    upgrades[key] = upgrades[key]! + 1;
    audio.play('upgrade');
    paused = false;
    wave += 1;
    startWave();
  }

  void update(double rawDt) {
    final dt = min(rawDt, 0.034);
    time += dt;
    for (final effect in effects) {
      effect.age += dt;
    }
    effects.removeWhere((effect) => effect.age >= effect.duration);
    if (paused || ended || !started) return;

    timeStop = max(0, timeStop - dt);
    damageModeTimer = max(0, damageModeTimer - dt);
    flightTimer = max(0, flightTimer - dt);
    contactDestroyTimer = max(0, contactDestroyTimer - dt);
    reflectTimer = max(0, reflectTimer - dt);
    autoVolleyTimer = max(0, autoVolleyTimer - dt);

    updatePlayer(dt);
    updateSpawning(dt);
    updateArrows(dt);
    if (timeStop <= 0) {
      updateEnemies(dt);
      updateProjectiles(dt);
    }
    updateAbilities(dt);
    updatePickups(dt);
    resolveArrowHits();
    resolvePlayerHits();
    checkWaveClear(dt);
  }

  void updateAbilities(double dt) {
    if (reflectTimer > 0) {
      for (final projectile in projectiles) {
        if (projectile.dead ||
            distanceSquared(
                  projectile.x,
                  projectile.y,
                  player.x,
                  player.y - 45,
                ) >
                115 * 115) {
          continue;
        }
        projectile.dead = true;
        final target = firstMaxBy(living(), (enemy) => enemy.hp);
        if (target != null) {
          target.hp -= 10 * skin.power;
          if (target.hp <= 0) killEnemy(target, critical: true);
        }
      }
    }
    if (contactDestroyTimer > 0) {
      for (final enemy in living()) {
        if (distanceSquared(enemy.x, enemy.y, player.x, player.y) < 70 * 70 &&
            enemy.tier != 'boss') {
          killEnemy(enemy, critical: true);
        }
      }
    }
    for (var zi = 0; zi < abilityZones.length; zi++) {
      final zone = abilityZones[zi];
      zone.age += dt;
      zone.tick -= dt;
      if (zone.type == 'wolf') zone.x += width * dt * 0.9;
      if (const ['tornado', 'blackhole', 'windtrap'].contains(zone.type)) {
        for (final enemy in living()) {
          final centerY = zone.y ?? height * 0.42;
          if (distanceSquared(enemy.x, enemy.y, zone.x, centerY) <
              pow(zone.radius ?? 120, 2)) {
            enemy.x += (zone.x - enemy.x) * dt * 4;
            enemy.y += (centerY - enemy.y) * dt * 2;
            if (zone.tick <= 0) enemy.hp -= zone.damage;
          }
        }
      }
      if (zone.type == 'firetrail') {
        for (final enemy in living().where(
          (entry) =>
              entry.state == 'ground' &&
              (entry.x - zone.x).abs() < zone.radius!,
        )) {
          if (zone.tick <= 0) enemy.hp -= zone.damage;
        }
      }
      if (zone.type == 'crystalwall') {
        for (final enemy in living().where(
          (entry) =>
              entry.state == 'air' &&
              entry.y > zone.y! - 40 &&
              entry.y < zone.y! + 70,
        )) {
          enemy.rootTimer = 0.15;
        }
      }
      if (zone.type == 'decoy') {
        for (final enemy in living()) {
          enemy.x += (zone.x - enemy.x) * dt * 0.8;
        }
      }
      if (zone.tick <= 0) {
        if (zone.type == 'arrowrain') {
          abilityArrow(
            (random.nextDouble() - 0.5) * 1.4,
            zone.damage,
            pierce: true,
            maxHits: 2,
          );
        }
        if (zone.type == 'meteors') audio.play('explode');
        if (zone.type == 'meteors') {
          damageTargets(living().take(4), zone.damage, critical: true);
        }
        if (const ['gatling', 'clones', 'timelasers'].contains(zone.type)) {
          abilityArrow(
            (random.nextDouble() - 0.5) * 1.3,
            zone.damage,
            homing: true,
            pierce: zone.type != 'gatling',
          );
        }
        if (zone.type == 'totem') {
          damageTargets(
            living().where((entry) => entry.state != 'ground').take(1),
            zone.damage,
          );
        }
        if (zone.type == 'drones') damageTargets(living().take(3), zone.damage);
        if (zone.type == 'wolf') {
          damageTargets(
            living().where(
              (entry) =>
                  entry.state == 'ground' && (entry.x - zone.x).abs() < 80,
            ),
            zone.damage,
          );
        }
        if (zone.type == 'bloodfloor') damageTargets(living(), zone.damage);
        for (final enemy in living()) {
          if (enemy.hp <= 0) killEnemy(enemy);
        }
        zone.tick = zone.interval ?? 0.28;
      }
    }
    abilityZones.removeWhere((zone) => zone.age >= zone.duration);
  }

  void updatePlayer(double dt) {
    player.invulnerable = max(0, player.invulnerable - dt);
    player.shootTimer = max(0, player.shootTimer - dt);
    player.hurtTimer = max(0, player.hurtTimer - dt);
    player.actionTimer = max(0, player.actionTimer - dt);
    player.meleeCooldown = max(0, player.meleeCooldown - dt);
    player.skill1Cooldown = max(0, player.skill1Cooldown - dt);
    player.skill2Cooldown = max(0, player.skill2Cooldown - dt);
    for (final key in player.buffs.keys.toList()) {
      player.buffs[key] = max(0, player.buffs[key]! - dt);
    }
    final move = _movement();
    final speed =
        tuning.playerSpeed *
        0.72 *
        pow(1.18, upgrades['speed']!) *
        (player.buffs['haste']! > 0 ? 1.35 : 1);
    if (move.target != null) {
      final difference = move.target! - player.x;
      final step = clampd(difference, -speed * dt, speed * dt);
      player.x += step;
      if (step.abs() > 0.1) player.facing = step.sign;
    } else {
      player.x += move.axis * speed * dt;
      if (move.axis != 0) player.facing = move.axis;
    }
    player.x = clampd(player.x, 34, width - 34);

    if (flightTimer > 0) {
      player.grounded = false;
      player.vy = 0;
      player.y +=
          (groundY - min(150, height * 0.22) - player.y) * min(1, dt * 6);
    } else if (!player.grounded) {
      player.vy += tuning.gravity * dt;
      player.y += player.vy * dt;
      if (player.y >= groundY) {
        player.y = groundY;
        player.vy = 0;
        player.grounded = true;
        audio.play('land');
      }
    }

    final meleeTarget = enemies
        .where(
          (enemy) =>
              !enemy.dead &&
              enemy.state == 'ground' &&
              (enemy.x - player.x).abs() < 72,
        )
        .firstOrNull;
    if (meleeTarget != null && player.meleeCooldown <= 0) {
      player.meleeCooldown = 0.62;
      audio.play('melee');
      player.actionName = 'melee';
      player.actionTimer = 0.42;
      player.facing = meleeTarget.x < player.x ? -1 : 1;
      meleeTarget.hp -= 2.8 * skin.power;
      meleeTarget.x += player.facing * 34;
      effects.add(
        Effect(
          x: meleeTarget.x,
          y: meleeTarget.y - 35,
          type: 'skin_skill1',
          duration: 0.32,
          size: 64 + skinIndex * 2.0,
          color: skin.color,
        ),
      );
      if (meleeTarget.hp <= 0) killEnemy(meleeTarget);
    }

    player.fireTimer -= dt;
    final rate =
        tuning.baseFireRate *
        pow(1.22, upgrades['fireRate']!) *
        (player.buffs['haste']! > 0 ? 1.4 : 1) *
        (skinIndex == 19 || autoVolleyTimer > 0 ? 2.25 : 1);
    if (move.fire && player.fireTimer <= 0) {
      fireArrow();
      player.fireTimer = 1 / rate;
    }
  }

  Enemy? targetEnemy() {
    Enemy? selected;
    var selectedScore = double.negativeInfinity;
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      final groundedThreat = enemy.state == 'ground'
          ? 10000 - (enemy.x - player.x).abs() * 4
          : 0.0;
      final landingThreat = enemy.state == 'air' ? enemy.y * 8 : 0.0;
      final bossThreat = enemy.tier == 'boss' ? 4000.0 : 0.0;
      final score =
          groundedThreat +
          landingThreat +
          bossThreat -
          (enemy.x - player.x).abs();
      if (score > selectedScore) {
        selected = enemy;
        selectedScore = score;
      }
    }
    return selected;
  }

  void fireArrow() {
    final target = targetEnemy();
    final startX = player.x;
    final startY = player.y - min(72, height * 0.1);
    var dx = 0.0;
    var dy = -1.0;
    if (target != null) {
      dx = target.x - startX;
      dy = target.y - target.size * 0.48 - startY;
      final length = sqrt(dx * dx + dy * dy);
      final safeLength = length == 0 ? 1.0 : length;
      dx /= safeLength;
      dy /= safeLength;
      if (dy > -0.18 && target.state != 'ground') dy = -0.18;
    }
    final speed = max(520, height * 0.82);
    player.shotCount += 1;
    final pierce = relics.contains('Segel Lich') && player.shotCount % 12 == 0;
    final critical =
        random.nextDouble() < (player.buffs['critical']! > 0 ? 0.5 : 0.1);
    final shots = player.buffs['multishot']! > 0
        ? 3
        : (skinIndex >= 19 ? 2 : 1);
    for (var index = 0; index < shots; index += 1) {
      final offset = (index - (shots - 1) / 2) * 0.12;
      final cosine = cos(offset);
      final sine = sin(offset);
      final shotX = dx * cosine - dy * sine;
      final shotY = dx * sine + dy * cosine;
      final damage =
          1.65 *
          skin.power *
          areaDamageBuff *
          (damageModeTimer > 0 ? 3 : 1) *
          pow(1.35, upgrades['damage']!) *
          (player.buffs['power']! > 0 ? 1.65 : 1) *
          (critical ? 2 : 1);
      arrows.add(
        Arrow(
          x: startX,
          y: startY,
          vx: shotX * speed,
          vy: shotY * speed,
          damage: damage,
          critical: critical,
          pierce: pierce || skinIndex >= 17,
        ),
      );
    }
    if (skinIndex == 19) {
      for (final enemy
          in enemies.where((entry) => !entry.dead).take(6).toList()) {
        final ex = enemy.x - startX;
        final ey = enemy.y - enemy.size * 0.45 - startY;
        abilityArrow(
          atan2(ex, -ey),
          1.2 * skin.power,
          homing: true,
          pierce: true,
          maxHits: 2,
        );
      }
    }
    player.shootTimer = 0.18;
    player.facing = (target != null && target.x < startX) ? -1 : 1;
    effects.add(
      Effect(
        x: startX,
        y: startY,
        type: 'release',
        duration: 0.22,
        size: 54 * tuning.effectIntensity,
      ),
    );
    audio.play('bow');
  }

  void updateSpawning(double dt) {
    if (spawnRemaining <= 0) return;
    spawnTimer -= dt;
    if (spawnTimer > 0) return;
    var tier = 'common';
    final bossWave = area.waveCount;
    final miniWave = bossWave - 5;
    if (wave == bossWave) {
      tier = 'boss';
    } else if (wave == miniWave) {
      tier = 'mini';
    } else if (wave == 5 &&
        spawnRemaining == min(12, 4 + (wave * 0.55).ceil())) {
      tier = 'rare';
    } else if (wave >= 5 &&
        random.nextDouble() < min(0.35, 0.08 + wave * 0.015)) {
      tier = 'rare';
    }
    spawnEnemy(tier);
    spawnRemaining -= 1;
    spawnTimer = tier == 'common' ? max(0.34, 0.92 - wave * 0.025) : 1.05;
  }

  Enemy spawnEnemy(String tier, {int? commonIndex, bool child = false}) {
    // Common pool: the area's own commons plus the area's reinforcement pack.
    final commonPool = <_CommonEntry>[
      for (var i = 0; i < area.commons.length; i++)
        _CommonEntry(area.commons[i], area.commonKey, i),
    ];
    final reinforcement = reinforcementFor(areaIndex);
    if (reinforcement != null) {
      commonPool.add(
        _CommonEntry(
          [reinforcement[2], reinforcement[1], reinforcement[3]],
          reinforcement[0],
          commonPool.length,
        ),
      );
    }
    final chosenIndex = commonIndex ?? random.nextInt(commonPool.length);
    final commonEntry = commonPool[chosenIndex % commonPool.length];
    final List<String> data;
    if (tier == 'common') {
      data = commonEntry.data;
    } else if (tier == 'rare') {
      data = area.rare;
    } else if (tier == 'mini') {
      data = area.mini;
    } else {
      data = area.boss;
    }
    final size = tier == 'boss'
        ? min(154.0, width * 0.34)
        : tier == 'mini'
        ? 104.0
        : tier == 'rare'
        ? 76.0
        : 58.0;
    final baseHp =
        kEnemyHpMultiplier *
        (tier == 'boss'
            ? 58.0 + areaIndex * 13
            : tier == 'mini'
            ? 22.0 + areaIndex * 4
            : tier == 'rare'
            ? 5.0 + areaIndex * 0.8
            : 1.35 + areaIndex * 0.22 + wave * 0.04);
    final fromRight =
        tier == 'common' &&
        !child &&
        wave > 1 &&
        random.nextDouble() < 0.18 + wave * 0.006;
    final x = fromRight
        ? width + size
        : 34 + random.nextDouble() * (width - 68);
    final enemy = Enemy(
      id: nextId++,
      name: data[0],
      animation: data[1],
      behavior: tier == 'common' ? data[2] : tier,
      tier: tier,
      commonIndex: chosenIndex,
      assetKey: tier == 'common' ? commonEntry.assetKey : area.eliteKey,
      x: x,
      y: tier == 'boss' ? height * 0.27 : (fromRight ? groundY : -size * 0.25),
      originX: x,
      state: tier == 'boss' ? 'hover' : (fromRight ? 'ground' : 'air'),
      size: size,
      hp: baseHp,
      maxHp: baseHp,
      speed:
          tuning.enemySpeed *
          kEnemyDifficulty *
          (0.74 + areaIndex * 0.045 + wave * 0.018) *
          (tier == 'rare' ? 0.82 : 1),
      shootTimer: 0.7 + random.nextDouble() * 1.5,
      armor: (tier == 'common' && data[2] == 'armored') ? 1 : 0,
      child: child,
    );
    enemies.add(enemy);
    return enemy;
  }

  void updateArrows(double dt) {
    for (final arrow in arrows) {
      if (arrow.homing) {
        final target = firstMinBy(
          enemies.where(
            (enemy) => !enemy.dead && !arrow.hits.contains(enemy.id),
          ),
          (enemy) => distanceSquared(arrow.x, arrow.y, enemy.x, enemy.y),
        );
        if (target != null) {
          final speed = sqrt(arrow.vx * arrow.vx + arrow.vy * arrow.vy);
          final dx = target.x - arrow.x;
          final dy = target.y - target.size * 0.45 - arrow.y;
          final rawLength = sqrt(dx * dx + dy * dy);
          final length = rawLength == 0 ? 1.0 : rawLength;
          arrow.vx += ((dx / length) * speed - arrow.vx) * dt * 7;
          arrow.vy += ((dy / length) * speed - arrow.vy) * dt * 7;
        }
      }
      arrow.x += arrow.vx * dt;
      arrow.y += arrow.vy * dt;
      arrow.age += dt;
      // Homing arrows that never reach a target would hover at the screen edge.
      final maxAge = arrow.homing ? 1.4 : 3.0;
      if (arrow.age > maxAge ||
          arrow.x < -80 ||
          arrow.x > width + 80 ||
          arrow.y < -100 ||
          arrow.y > height + 60) {
        arrow.dead = true;
      }
    }
    arrows.removeWhere((arrow) => arrow.dead);
  }

  void updateEnemies(double dt) {
    for (var index = 0; index < enemies.length; index++) {
      final enemy = enemies[index];
      if (enemy.dead) continue;
      enemy.actionTimer += dt;
      enemy.shootTimer -= dt;
      enemy.slowTimer = jsMax(0, enemy.slowTimer - dt);
      enemy.rootTimer = jsMax(0, enemy.rootTimer - dt);
      enemy.stunTimer = jsMax(0, enemy.stunTimer - dt);
      enemy.poisonTimer = jsMax(0, enemy.poisonTimer - dt);
      if (enemy.poisonTimer > 0) {
        enemy.hp -= dt * 1.4 * skin.power;
        if (enemy.hp <= 0) {
          killEnemy(enemy);
          continue;
        }
      }
      final motionScale = (enemy.slowTimer > 0 || player.buffs['freeze']! > 0)
          ? 0.45
          : 1.0;
      final pulls =
          enemy.behavior == 'pull' ||
          (enemy.tier != 'common' &&
              const [11, 12, 13, 14, 17, 19].contains(areaIndex));
      if (pulls && enemy.state != 'ground') {
        player.x += (enemy.x - player.x) * dt * (0.07 + areaIndex * 0.003);
        player.x = clampd(player.x, 34, width - 34);
      }
      if (enemy.tier == 'boss') {
        if (enemy.stunTimer > 0) continue;
        updateBoss(enemy, dt);
        continue;
      }
      if (enemy.tier == 'mini') {
        if (enemy.rootTimer > 0 || enemy.stunTimer > 0) continue;
        if (enemy.state == 'air') {
          enemy.y += enemy.speed * 0.45 * dt * motionScale;
          enemy.x +=
              sin(time * 2.8 + enemy.id) *
              enemy.speed *
              0.28 *
              dt *
              motionScale;
          if (enemy.y > height * 0.3) enemy.state = 'hover';
        } else if (enemy.state == 'hover') {
          enemy.x +=
              sin(time * 2.2 + enemy.id) *
              enemy.speed *
              0.45 *
              dt *
              motionScale;
        }
        if (enemy.shootTimer <= 0) {
          shootAtPlayer(enemy, 210 + areaIndex * 8.0);
          enemy.shootTimer = 1.45;
        }
        continue;
      }
      if (enemy.rootTimer > 0 || enemy.stunTimer > 0) continue;
      if (enemy.state == 'air') {
        final phase = time * (enemy.tier == 'rare' ? 4 : 2.2) + enemy.id;
        final horizontal =
            const [
              'zigzag',
              'swoop',
              'circle',
              'teleport',
            ].contains(enemy.behavior) ||
            enemy.tier == 'rare';
        enemy.x +=
            (horizontal
                ? sin(phase) * enemy.speed * 0.62 * dt
                : sin(phase) * enemy.speed * 0.12 * dt) *
            motionScale;
        final behaviorScale = enemy.behavior == 'float'
            ? 0.55
            : enemy.behavior == 'meteor'
            ? 1.65
            : 1.0;
        enemy.y += enemy.speed * behaviorScale * dt * motionScale;
        if (enemy.behavior == 'teleport' &&
            (enemy.actionTimer * 2.2).floor() !=
                ((enemy.actionTimer - dt) * 2.2).floor()) {
          enemy.x = clampd(
            enemy.x + (random.nextDouble() - 0.5) * 110,
            30,
            width - 30,
          );
        }
        if (enemy.y >= groundY) {
          enemy.y = groundY;
          enemy.state = 'ground';
          enemy.actionTimer = 0;
        }
      } else if (enemy.state == 'ground') {
        final rawDirection = (player.x - enemy.x).sign;
        final direction = rawDirection == 0 ? -1.0 : rawDirection;
        enemy.x +=
            direction *
            enemy.speed *
            (enemy.behavior == 'rush' ? 1.45 : 0.72) *
            dt *
            motionScale;
      }
      if (const ['shooter', 'hover'].contains(enemy.behavior) ||
          enemy.tier == 'rare') {
        if (enemy.shootTimer <= 0 && enemy.state != 'ground') {
          shootAtPlayer(enemy, 170 + areaIndex * 8.0);
          enemy.shootTimer = enemy.tier == 'rare' ? 1.7 : 2.6;
        }
      }
      enemy.x = clampd(enemy.x, -enemy.size, width + enemy.size);
    }
  }

  void updateBoss(Enemy enemy, double dt) {
    final hpRatio = enemy.hp / enemy.maxHp;
    if (areaIndex == 3 && hpRatio < 0.3) {
      enemy.state = 'ground';
      enemy.y = groundY;
      enemy.x += (player.x - enemy.x).sign * enemy.speed * 0.7 * dt;
    } else if (const [9, 19].contains(areaIndex) &&
        hpRatio < 0.66 &&
        hpRatio >= 0.33) {
      enemy.state = 'ground';
      enemy.y = groundY;
      enemy.x += (player.x - enemy.x).sign * enemy.speed * 0.45 * dt;
    } else {
      enemy.state = 'hover';
      final low = const [9, 19].contains(areaIndex) && hpRatio < 0.33;
      enemy.y = height * (low ? 0.47 : 0.27) + sin(time * 1.6) * 12;
      enemy.x =
          width * 0.5 + sin(time * (0.72 + areaIndex * 0.04)) * width * 0.27;
    }
    if (enemy.shootTimer <= 0) {
      bossAttack(enemy, hpRatio);
      enemy.shootTimer = max(
        0.72,
        1.55 - areaIndex * 0.055 - (1 - hpRatio) * 0.35,
      );
    }
  }

  void _shootSpread(
    Enemy enemy,
    int count,
    double speed, {
    double spread = 0.7,
  }) {
    for (var index = 0; index < count; index += 1) {
      final angle =
          pi / 2 + (index - (count - 1) / 2) * spread / max(1, count - 1);
      projectiles.add(
        Projectile(
          x: enemy.x,
          y: enemy.y - enemy.size * 0.35,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          type: 'orb',
          size: 13,
        ),
      );
    }
  }

  void _addProjectile(
    double x,
    double y,
    double vx,
    double vy,
    String type,
    double size,
  ) {
    projectiles.add(
      Projectile(x: x, y: y, vx: vx, vy: vy, type: type, size: size),
    );
  }

  void bossAttack(Enemy enemy, double hpRatio) {
    if (areaIndex == 0) _shootSpread(enemy, 3, 190, spread: 1.05);
    if (areaIndex == 1) {
      _shootSpread(enemy, 1, 175);
      if (enemies.length < 6) spawnEnemy('common', commonIndex: 0, child: true);
    }
    if (areaIndex == 2) _addProjectile(player.x, -40, 0, 155, 'tornado', 32);
    if (areaIndex == 3) {
      for (var index = 0; index < 4; index += 1) {
        _addProjectile(
          25 + random.nextDouble() * (width - 50),
          -25,
          0,
          190,
          'acid',
          11,
        );
      }
    }
    if (areaIndex == 4) spawnBeam(player.x, 22);
    if (areaIndex == 5) _shootSpread(enemy, 5, 215, spread: 1.3);
    if (areaIndex == 6) _shootSpread(enemy, 2, 210, spread: 0.5);
    if (areaIndex == 7) {
      for (var index = 0; index < 3; index += 1) {
        spawnBeam(35 + random.nextDouble() * (width - 70), 18);
      }
    }
    if (areaIndex == 8) {
      enemy.x = 50 + random.nextDouble() * (width - 100);
      _shootSpread(enemy, 4, 205, spread: 1.15);
      _addProjectile(width + 40, groundY - 12, -245, 0, 'wave', 28);
    }
    if (areaIndex == 9) {
      if (hpRatio > 0.66) {
        _shootSpread(enemy, 5, 220, spread: 1.35);
      } else if (hpRatio > 0.33) {
        _addProjectile(width + 40, groundY - 12, -270, 0, 'wave', 30);
        _addProjectile(-40, groundY - 12, 270, 0, 'wave', 30);
      } else {
        spawnBeam(player.x, 34);
        _shootSpread(enemy, 3, 235, spread: 0.8);
        if (enemies.length < 4) {
          spawnEnemy('common', commonIndex: 2, child: true);
        }
      }
    }
    if (areaIndex == 10) {
      _shootSpread(enemy, 6, 225, spread: 1.45);
      spawnBeam(player.x, 18);
    }
    if (areaIndex == 11) {
      player.x += (enemy.x - player.x) * 0.16;
      _shootSpread(enemy, 4, 215, spread: 1.2);
    }
    if (areaIndex == 12) {
      _shootSpread(enemy, 3, 175, spread: 0.7);
      for (final target in enemies) {
        target.slowTimer = jsMax(target.slowTimer, 0.8);
      }
    }
    if (areaIndex == 13) {
      player.x += (enemy.x - player.x) * 0.12;
      for (var index = 0; index < 4; index += 1) {
        _addProjectile(
          30 + random.nextDouble() * (width - 60),
          -20,
          0,
          205,
          'acid',
          13,
        );
      }
    }
    if (areaIndex == 14) {
      _shootSpread(enemy, 7, 225, spread: 1.5);
      if (enemies.length < 5) spawnEnemy('common', commonIndex: 1, child: true);
    }
    if (areaIndex == 15) {
      enemy.x = width - enemy.x;
      _shootSpread(enemy, 6, 230, spread: 1.4);
    }
    if (areaIndex == 16) {
      _shootSpread(enemy, 5, 240, spread: 1.55);
      _addProjectile(width + 40, groundY - 12, -285, 0, 'wave', 30);
    }
    if (areaIndex == 17) {
      player.x += (enemy.x - player.x) * 0.2;
      spawnBeam(player.x, 28);
      _shootSpread(enemy, 3, 235, spread: 0.8);
    }
    if (areaIndex == 18) {
      _shootSpread(enemy, 6, 245, spread: 1.5);
      if (enemies.length < 5) {
        spawnEnemy('common', commonIndex: random.nextInt(3), child: true);
      }
    }
    if (areaIndex == 19) {
      player.x += (enemy.x - player.x) * (hpRatio < 0.33 ? 0.22 : 0.1);
      if (hpRatio > 0.66) {
        _shootSpread(enemy, 7, 245, spread: 1.7);
      } else if (hpRatio > 0.33) {
        spawnBeam(player.x, 34);
        _shootSpread(enemy, 5, 255, spread: 1.3);
      } else {
        for (var index = 0; index < 3; index += 1) {
          spawnBeam(30 + random.nextDouble() * (width - 60), 26);
        }
        _shootSpread(enemy, 9, 270, spread: 1.85);
      }
    }
    if (areaIndex >= 20) {
      final phase = areaIndex - 20;
      _shootSpread(
        enemy,
        5 + phase ~/ 2,
        235.0 + phase * 5,
        spread: 1.35 + phase * 0.05,
      );
      if (phase % 3 == 0) spawnBeam(player.x, 22.0 + phase);
      if (phase % 3 == 1) player.x += (enemy.x - player.x) * 0.12;
      if (phase % 3 == 2) {
        _addProjectile(
          width + 40,
          groundY - 12,
          -275.0 - phase * 4,
          0,
          'wave',
          28,
        );
      }
      if (hpRatio < 0.45 && enemies.length < 5) {
        spawnEnemy(
          'common',
          commonIndex: random.nextInt(area.commons.length),
          child: true,
        );
      }
    }
  }

  void spawnBeam(double x, double size) {
    audio.play('beam');
    projectiles.add(
      Projectile(x: x, y: 0, vx: 0, vy: 0, type: 'beam', size: size),
    );
  }

  void shootAtPlayer(Enemy enemy, double speed) {
    final dx = player.x - enemy.x;
    final dy = player.y - 35 - enemy.y;
    final rawLength = sqrt(dx * dx + dy * dy);
    final length = rawLength == 0 ? 1.0 : rawLength;
    projectiles.add(
      Projectile(
        x: enemy.x,
        y: enemy.y - enemy.size * 0.45,
        vx: (dx / length) * speed,
        vy: (dy / length) * speed,
        type: 'orb',
        size: 10,
      ),
    );
  }

  void updateProjectiles(double dt) {
    for (final projectile in projectiles) {
      projectile.age += dt;
      if (projectile.type == 'beam') {
        if (projectile.age > 1.18) projectile.dead = true;
        continue;
      }
      projectile.x += projectile.vx * dt;
      projectile.y += projectile.vy * dt;
      if (projectile.x < -90 ||
          projectile.x > width + 90 ||
          projectile.y > height + 80) {
        projectile.dead = true;
      }
    }
    projectiles.removeWhere((projectile) => projectile.dead);
  }

  void updatePickups(double dt) {
    for (final pickup in pickups) {
      pickup.vy += 480 * dt;
      pickup.y += pickup.vy * dt;
      if (pickup.y > groundY - 8) {
        pickup.y = groundY - 8;
        pickup.vy = 0;
      }
      final pickupRange =
          (player.buffs['magnet']! > 0 || relics.contains('Inti Gravitasi'))
          ? 150.0
          : 30.0;
      if ((pickup.x - player.x).abs() < pickupRange &&
          (pickup.y - player.y).abs() < 110) {
        if (pickupRange > 30) pickup.x += (player.x - pickup.x) * dt * 8;
      }
      if ((pickup.x - player.x).abs() < 30 &&
          (pickup.y - player.y).abs() < 65) {
        pickup.dead = true;
        if (pickup.kind == 'coin') {
          coins += pickup.value.toInt();
          score += pickup.value * 8;
        } else {
          applyPowerup(pickup.kind);
        }
        audio.play(pickup.kind == 'coin' ? 'coin' : 'powerup');
      }
    }
    pickups.removeWhere((pickup) => pickup.dead);
  }

  void applyPowerup(String kind) {
    if (kind == 'multishot') player.buffs['multishot'] = 10;
    if (kind == 'shield') player.shieldCharges += 1;
    if (kind == 'haste') player.buffs['haste'] = 10;
    if (kind == 'power') player.buffs['power'] = 10;
    if (kind == 'freeze') player.buffs['freeze'] = 8;
    if (kind == 'magnet') player.buffs['magnet'] = 12;
    if (kind == 'heal') {
      player.health = min(player.maxHealth, player.health + 1);
    }
    if (kind == 'critical') player.buffs['critical'] = 10;
    if (kind == 'cooldown') {
      player.skill1Cooldown = 0;
      player.skill2Cooldown = 0;
    }
    if (kind == 'nova') player.ultimate = 100;
    effects.add(
      Effect(
        x: player.x,
        y: player.y - 55,
        type: 'skin_skill2',
        duration: 0.55,
        size: 105,
        color: skin.color,
      ),
    );
  }

  void resolveArrowHits() {
    for (var ai = 0; ai < arrows.length; ai++) {
      final arrow = arrows[ai];
      for (var ei = 0; ei < enemies.length; ei++) {
        final enemy = enemies[ei];
        if (enemy.dead || arrow.dead || arrow.hits.contains(enemy.id)) continue;
        final centerY = enemy.y - enemy.size * 0.46;
        final radius = enemy.size * (enemy.tier == 'boss' ? 0.43 : 0.36);
        if (distanceSquared(arrow.x, arrow.y, enemy.x, centerY) >
            radius * radius) {
          continue;
        }
        arrow.hits.add(enemy.id);
        final shieldedBoss =
            enemy.tier == 'boss' && areaIndex == 6 && sin(time * 2.1) < -0.1;
        final phasedGhost =
            enemy.tier == 'rare' && areaIndex == 4 && sin(time * 3) < -0.4;
        if (!shieldedBoss && !phasedGhost) {
          final armorMultiplier = enemy.armor > 0 ? 0.35 : 1.0;
          enemy.hp -= arrow.damage * armorMultiplier;
          if (arrow.slow != 0) {
            enemy.slowTimer = jsMax(enemy.slowTimer, arrow.slow);
          }
          if (arrow.poison != 0) {
            enemy.poisonTimer = jsMax(enemy.poisonTimer, arrow.poison);
          }
          if (arrow.stun != 0) {
            enemy.stunTimer = jsMax(enemy.stunTimer, arrow.stun);
          }
          if (arrow.omni) enemy.armor = 0;
          if (enemy.armor > 0) enemy.armor -= 1;
          effects.add(
            Effect(
              x: arrow.x,
              y: arrow.y,
              type: arrow.critical ? 'critical' : 'impact',
              duration: arrow.critical ? 0.4 : 0.25,
              size: (arrow.critical ? 82.0 : 48.0) * tuning.effectIntensity,
            ),
          );
          audio.play('hit');
          if (arrow.aoe > 0) {
            audio.play('explode');
            final nearby = enemies
                .where(
                  (candidate) =>
                      !candidate.dead &&
                      candidate.id != enemy.id &&
                      distanceSquared(
                            candidate.x,
                            candidate.y,
                            enemy.x,
                            enemy.y,
                          ) <
                          arrow.aoe * arrow.aoe,
                )
                .toList();
            damageTargets(nearby, arrow.damage * 0.65);
          }
          if (arrow.chain > 0) {
            final next = enemies
                .where(
                  (candidate) =>
                      !candidate.dead &&
                      candidate.id != enemy.id &&
                      !arrow.hits.contains(candidate.id),
                )
                .firstOrNull;
            if (next != null) {
              next.hp -= arrow.damage * 0.8;
              if (next.hp <= 0) killEnemy(next, critical: true);
            }
          }
          if (enemy.hp <= 0) killEnemy(enemy, critical: arrow.critical);
        } else {
          effects.add(
            Effect(
              x: arrow.x,
              y: arrow.y,
              type: 'impact',
              duration: 0.18,
              size: 34,
            ),
          );
        }
        if (!arrow.pierce || arrow.hits.length >= arrow.maxHits) {
          arrow.dead = true;
        }
      }
    }
  }

  void killEnemy(Enemy enemy, {bool critical = false}) {
    if (enemy.dead) return;
    if (enemy.tier == 'boss' && areaIndex == 5 && !enemy.revived) {
      enemy.revived = true;
      enemy.hp = enemy.maxHp * 0.42;
      enemy.size *= 0.82;
      effects.add(
        Effect(
          x: enemy.x,
          y: enemy.y - enemy.size * 0.5,
          type: 'boss_collapse',
          sheet: 'defeat',
          duration: 0.55,
          size: enemy.size * 1.25,
        ),
      );
      return;
    }
    enemy.dead = true;
    final effectType = enemy.tier == 'boss'
        ? 'boss_collapse'
        : enemy.tier == 'mini'
        ? 'mini_break'
        : enemy.tier == 'rare'
        ? 'rare_dissolve'
        : 'common_burst';
    effects.add(
      Effect(
        x: enemy.x,
        y: enemy.y - enemy.size * 0.45,
        type: effectType,
        sheet: 'defeat',
        duration: enemy.tier == 'boss' ? 0.9 : 0.48,
        size: enemy.size * (enemy.tier == 'boss' ? 1.45 : 1.15),
      ),
    );
    final value = enemy.tier == 'boss'
        ? 80.0
        : enemy.tier == 'mini'
        ? 35.0
        : enemy.tier == 'rare'
        ? 12.0
        : 3.0;
    score += value * 25 + (critical ? value * 8 : 0);
    pickups.add(
      Pickup(
        x: enemy.x,
        y: enemy.y - enemy.size * 0.5,
        vy: -110,
        value: value,
        kind: 'coin',
      ),
    );
    player.ultimate = min(
      100,
      player.ultimate +
          (enemy.tier == 'boss'
              ? 40
              : enemy.tier == 'mini'
              ? 28
              : enemy.tier == 'rare'
              ? 16
              : 4),
    );
    final powerupChance = enemy.tier == 'mini'
        ? 1.0
        : enemy.tier == 'rare'
        ? 0.45
        : enemy.tier == 'common'
        ? 0.06
        : 0.0;
    if (random.nextDouble() < powerupChance) {
      const kinds = [
        'multishot',
        'shield',
        'haste',
        'power',
        'freeze',
        'magnet',
        'heal',
        'critical',
        'cooldown',
        'nova',
      ];
      final kind = kinds[random.nextInt(kinds.length)];
      pickups.add(
        Pickup(
          x: enemy.x + 16,
          y: enemy.y - enemy.size * 0.55,
          vy: -145,
          value: 0,
          kind: kind,
        ),
      );
    }
    if (enemy.behavior == 'split' && !enemy.child && enemy.tier == 'common') {
      for (final direction in [-1, 1]) {
        final child = spawnEnemy(
          'common',
          commonIndex: enemy.commonIndex,
          child: true,
        );
        child.x = clampd(enemy.x + direction * 18, 25, width - 25);
        child.y = enemy.y;
        child.size *= 0.62;
        child.hp = 0.7;
        child.maxHp = 0.7;
        child.state = enemy.state;
      }
    }
    if (relics.contains('Mahkota Petir') && critical) {
      final next = enemies
          .where((candidate) => !candidate.dead && candidate.id != enemy.id)
          .firstOrNull;
      if (next != null) {
        next.hp -= 1.5;
        effects.add(
          Effect(
            x: next.x,
            y: next.y - next.size * 0.45,
            type: 'critical',
            duration: 0.3,
            size: 62,
          ),
        );
        if (next.hp <= 0) killEnemy(next);
      }
    }
    if (relics.contains('Taring Void')) {
      final closest = firstMinBy(
        projectiles,
        (projectile) =>
            distanceSquared(enemy.x, enemy.y, projectile.x, projectile.y),
      );
      if (closest != null &&
          distanceSquared(enemy.x, enemy.y, closest.x, closest.y) < 160 * 160) {
        closest.dead = true;
      }
    }
    audio.play('defeat');
  }

  void resolvePlayerHits() {
    final playerCenterY = player.y - 42;
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      final centerY = enemy.y - enemy.size * 0.42;
      final reach = enemy.size * 0.34 + 22;
      final touching =
          distanceSquared(player.x, playerCenterY, enemy.x, centerY) <
          reach * reach;
      if (touching && enemy.state == 'ground') {
        if (skinIndex == 3 && player.shieldCharges > 0) enemy.rootTimer = 4;
        hurtPlayer('ground');
        final diff = enemy.x - player.x;
        enemy.x += (diff == 0 ? 1 : diff.sign) * 35;
      }
    }
    for (final projectile in projectiles) {
      if (projectile.dead) continue;
      bool hit;
      if (projectile.type == 'beam') {
        hit =
            projectile.age > 0.68 &&
            projectile.age < 1.05 &&
            (projectile.x - player.x).abs() < projectile.size;
      } else if (projectile.type == 'wave') {
        final r = projectile.size + 22;
        hit =
            player.grounded &&
            distanceSquared(
                  player.x,
                  playerCenterY,
                  projectile.x,
                  projectile.y,
                ) <
                r * r;
      } else {
        final r = projectile.size + 20;
        hit =
            distanceSquared(
              player.x,
              playerCenterY,
              projectile.x,
              projectile.y,
            ) <
            r * r;
      }
      if (hit) {
        projectile.dead = true;
        hurtPlayer(projectile.type == 'wave' ? 'ground' : 'projectile');
      }
    }
  }

  void hurtPlayer(String source) {
    if (player.invulnerable > 0 || ended) return;
    if (player.shieldCharges > 0) {
      player.shieldCharges -= 1;
      audio.play('shield');
      player.invulnerable = 0.8;
      effects.add(
        Effect(
          x: player.x,
          y: player.y - 42,
          type: 'skin_skill2',
          duration: 0.4,
          size: 95,
          color: skin.color,
        ),
      );
      return;
    }
    if (source == 'ground' &&
        relics.contains('Kulit Kayu Titan') &&
        !player.shieldUsed) {
      player.shieldUsed = true;
      audio.play('shield');
      player.invulnerable = 0.8;
      effects.add(
        Effect(
          x: player.x,
          y: player.y - 42,
          type: 'critical',
          duration: 0.35,
          size: 88,
        ),
      );
      return;
    }
    player.health -= 1;
    player.invulnerable = 1.15;
    player.hurtTimer = 0.38;
    audio.play('hurt');
    callbacks.onHit?.call();
    if (player.health <= 0 &&
        relics.contains('Abu Phoenix') &&
        !player.phoenixUsed) {
      player.phoenixUsed = true;
      player.health = 1;
      player.invulnerable = 2;
      effects.add(
        Effect(
          x: player.x,
          y: player.y - 40,
          type: 'boss_collapse',
          sheet: 'defeat',
          duration: 0.8,
          size: 110,
        ),
      );
      return;
    }
    if (player.health <= 0) {
      ended = true;
      paused = true;
      bestScore = max(bestScore, score);
      callbacks.onGameOver?.call(snapshot());
    }
  }

  void checkWaveClear(double dt) {
    enemies.removeWhere((enemy) => enemy.dead);
    if (spawnRemaining > 0 || enemies.isNotEmpty) {
      waveClearTimer = 0;
      return;
    }
    waveClearTimer += dt;
    if (waveClearTimer < 0.85) return;
    waveClearTimer = -999;
    projectiles.clear();
    score += wave * 45;
    upgradeTokens += 1;
    final bossWave = area.waveCount;
    final miniWave = bossWave - 5;
    if (wave == miniWave && relics.contains('Inti Lumut')) {
      player.health = min(player.maxHealth, player.health + 1);
    }
    if (wave == bossWave) {
      paused = true;
      relics.add(area.relic[0]);
      callbacks.onAreaComplete?.call(snapshot());
      return;
    }
    if (wave == 5 || wave == 10 || wave == miniWave) {
      paused = true;
      callbacks.onUpgrade?.call();
      return;
    }
    audio.play('wave_clear');
    wave += 1;
    startWave();
  }

  /// Which sprite sheet and animation the player should show right now.
  ({String key, String name}) playerAnimation() {
    if (player.actionTimer > 0 && player.actionName.isNotEmpty) {
      return (key: skin.skillKey, name: player.actionName);
    }
    if (player.shootTimer > 0) return (key: skin.coreKey, name: 'shoot');
    if (!player.grounded) return (key: skin.coreKey, name: 'jump');
    final move = _movement();
    if (move.axis != 0 ||
        (move.target != null && (move.target! - player.x).abs() > 3)) {
      return (key: skin.coreKey, name: 'run');
    }
    return (key: skin.coreKey, name: 'idle');
  }

  HudState snapshot() {
    final boss = enemies
        .where((enemy) => enemy.tier == 'boss' && !enemy.dead)
        .firstOrNull;
    return HudState(
      areaIndex: areaIndex,
      areaName: area.name,
      wave: wave,
      totalWaves: area.waveCount,
      score: score,
      bestScore: bestScore,
      coins: coins,
      health: player.health,
      maxHealth: player.maxHealth,
      skinIndex: skinIndex,
      skill1: player.skill1Cooldown,
      skill2: player.skill2Cooldown,
      ultimate: player.ultimate,
      bossName: boss?.name,
      bossRatio: boss == null ? 0 : boss.hp / boss.maxHp,
      upgradeTokens: upgradeTokens,
    );
  }
}

class _CommonEntry {
  _CommonEntry(this.data, this.assetKey, this.index);
  final List<String> data;
  final String assetKey;
  final int index;
}
