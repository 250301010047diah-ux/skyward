// Draws the arena on a Flame canvas.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'assets.dart';
import 'sprite_visuals.dart';
import 'world.dart';

Color _rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);

Color _hex(String hex) {
  final value = int.parse(hex.substring(1), radix: 16);
  return Color(0xFF000000 | value);
}

class _Metric {
  const _Metric(this.width, this.height);
  final double width;
  final double height;
}

class ArenaRenderer {
  ArenaRenderer(this.library);

  final AssetLibrary library;
  final Map<String, _Metric> _metrics = {};

  // Paint objects are created per draw call; only the alpha/colour differ.
  final Paint _paint = Paint();

  static Rect _cropRect(FrameInfo frame) => frame.crop;

  static FrameInfo? _frameAt(List<FrameInfo> frames, int index) =>
      index >= 0 && index < frames.length ? frames[index] : null;

  _Metric _animationMetric(String key, String name) {
    final cacheKey = '$key:$name';
    final cached = _metrics[cacheKey];
    if (cached != null) return cached;
    var width = 1.0;
    var height = 1.0;
    final frames = library.animation(key, name);
    final visibleFrames = name == 'shoot' ? frames.take(2) : frames;
    for (final frame in visibleFrames) {
      final crop = _cropRect(frame);
      width = max(width, crop.width);
      height = max(height, crop.height);
    }
    final metric = _Metric(width, height);
    _metrics[cacheKey] = metric;
    return metric;
  }

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect src,
    Rect dst,
    double alpha,
  ) {
    _paint
      ..color = _rgba(255, 255, 255, alpha.clamp(0.0, 1.0))
      ..blendMode = BlendMode.srcOver;
    canvas.drawImageRect(image, src, dst, _paint);
  }

  void _drawAnchored(
    Canvas canvas,
    String key,
    String name,
    int index,
    double x,
    double y,
    double targetHeight, {
    bool flip = false,
    double alpha = 1,
  }) {
    final sheet = library.get(key);
    final frames = library.animation(key, name);
    if (sheet == null || frames.isEmpty) return;
    final frame = frames[index % frames.length];
    final crop = _cropRect(frame);
    final metric = _animationMetric(key, name);
    final scale = targetHeight / metric.height;
    canvas.save();
    canvas.translate(x, y);
    if (flip) canvas.scale(-1, 1);
    _drawImage(
      canvas,
      frame.isolatedImage ?? sheet.image,
      frame.imageSource,
      Rect.fromLTWH(
        -(frame.anchor.dx - crop.left) * scale,
        -(frame.anchor.dy - crop.top) * scale,
        crop.width * scale,
        crop.height * scale,
      ),
      alpha,
    );
    canvas.restore();
  }

  void _drawFrameCentered(
    Canvas canvas,
    String key,
    FrameInfo? frame,
    double x,
    double y,
    double size, {
    double rotation = 0,
    double alpha = 1,
  }) {
    final sheet = library.get(key);
    if (sheet == null || frame == null) return;
    final crop = _cropRect(frame);
    final scale = min(size / crop.width, size / crop.height);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotation);
    _drawImage(
      canvas,
      sheet.image,
      crop,
      Rect.fromLTWH(
        -crop.width * scale * 0.5,
        -crop.height * scale * 0.5,
        crop.width * scale,
        crop.height * scale,
      ),
      alpha,
    );
    canvas.restore();
  }

  /// Used by the HUD and overlays: draws one atlas frame, fitted in a square.
  static void paintIconFrame(
    Canvas canvas,
    ui.Image image,
    FrameInfo frame,
    Size size,
  ) {
    final crop = _cropRect(frame);
    final scale = min(
      size.width * 0.9 / crop.width,
      size.height * 0.9 / crop.height,
    );
    final width = crop.width * scale;
    final height = crop.height * scale;
    canvas.drawImageRect(
      image,
      crop,
      Rect.fromLTWH(
        (size.width - width) / 2,
        (size.height - height) / 2,
        width,
        height,
      ),
      Paint(),
    );
  }

  void _drawBackdrop(Canvas canvas, GameWorld world) {
    final sheet = library.get(world.area.bgKey);
    final width = world.width;
    final height = world.height;
    if (sheet == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = _hex('#160d35'),
      );
      return;
    }
    final image = sheet.image;
    final scale = max(width / image.width, height / image.height);
    final drawWidth = image.width * scale;
    final drawHeight = image.height * scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        (width - drawWidth) * 0.5,
        (height - drawHeight) * 0.5,
        drawWidth,
        drawHeight,
      ),
      Paint(),
    );
    final wash = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, height),
        [_rgba(18, 5, 50, .08), _rgba(11, 9, 38, .02), _rgba(8, 6, 26, .48)],
        [0, 0.7, 1],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), wash);
  }

  void _drawTelegraphs(Canvas canvas, GameWorld world) {
    for (final enemy in world.enemies) {
      if (enemy.state != 'air') continue;
      final closeness = max(0.0, min(1.0, enemy.y / world.groundY));
      final color = closeness > 0.72 ? _hex('#ff4b7d') : _hex('#62e9ff');
      final alpha = 0.16 + closeness * 0.46;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(enemy.x, world.groundY - 2),
          width: (10 + closeness * 18) * 2,
          height: (4 + closeness * 5) * 2,
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  void _drawGround(Canvas canvas, GameWorld world) {
    final area = world.area;
    final groundKey = area.groundKey;
    final sheet = library.get(groundKey);
    final frame = library.frame(groundKey, area.ground);
    if (sheet == null || frame == null) return;
    final crop = _cropRect(frame);
    final width = world.width;
    final height = world.height;
    final groundY = world.groundY;
    final tileWidth = max(86.0, min(128.0, width / 4));
    final tileHeight = max(90.0, height - groundY + 28);
    for (
      var x = -tileWidth * 0.4;
      x < width + tileWidth;
      x += tileWidth * 0.92
    ) {
      canvas.drawImageRect(
        sheet.image,
        crop,
        Rect.fromLTWH(x, groundY - 4, tileWidth, tileHeight),
        Paint(),
      );
    }
    final edge = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, groundY - 7),
        Offset(0, groundY + 15),
        [
          _rgba(115, 248, 255, .72),
          _rgba(70, 128, 255, .34),
          _rgba(8, 5, 24, 0),
        ],
        [0, 0.25, 1],
      );
    canvas.drawRect(Rect.fromLTWH(0, groundY - 7, width, 24), edge);
  }

  void _drawAbilityZones(Canvas canvas, GameWorld world) {
    final skinColor = _hex(world.skin.color);
    for (final zone in world.abilityZones) {
      final progress = zone.age / zone.duration;
      final alpha = 0.35 + sin(world.time * 9) * 0.08;
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..color = skinColor.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..blendMode = BlendMode.plus
        ..color = skinColor.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      if (zone.type == 'crystalwall') {
        canvas.drawRect(Rect.fromLTWH(0, zone.y! - 8, world.width, 16), paint);
      } else if (zone.type == 'firetrail' || zone.type == 'bloodfloor') {
        canvas.drawRect(
          Rect.fromLTWH(0, world.groundY - 14, world.width, 18),
          paint,
        );
      } else if (zone.type == 'wolf') {
        final path = Path()
          ..moveTo(zone.x - 35, world.groundY - 18)
          ..lineTo(zone.x + 40, world.groundY - 42)
          ..lineTo(zone.x + 18, world.groundY - 4)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        final radius = zone.radius ?? 95;
        canvas.drawCircle(
          Offset(zone.x, zone.y ?? world.groundY - 90),
          radius * (0.9 + progress * 0.12),
          stroke,
        );
      }
    }
  }

  void _drawPickup(Canvas canvas, Pickup pickup, GameWorld world) {
    final key = pickup.kind == 'coin' ? 'HUD_ICON_ATLAS' : 'POWERUP_ATLAS';
    final frame = library.frame(key, pickup.kind);
    _drawFrameCentered(
      canvas,
      key,
      frame,
      pickup.x,
      pickup.y - 8 + sin(world.time * 6 + pickup.x) * 3,
      pickup.kind == 'coin' ? 26 : 38,
      rotation: world.time * 1.2,
    );
  }

  void _drawArrow(Canvas canvas, Arrow arrow, GameWorld world) {
    if (world.skinIndex == 19) {
      _drawGoldenArrow(canvas, arrow);
      return;
    }
    final effectKey = world.skin.effectKey;
    final frames = library.animation(effectKey, 'basic');
    final heading = arrowArtworkHeading(world.skinIndex);
    if (heading == null || frames.isEmpty) {
      _drawEnergyArrow(canvas, arrow, world);
      return;
    }
    final rotation = arrowRotation(arrow.vx, arrow.vy, heading);
    final frame = _frameAt(
      frames,
      // End frames contain impacts/disappearing arrows, not flight poses.
      (arrow.age * 18).floor() % min(3, frames.length),
    );
    canvas.drawCircle(
      Offset(arrow.x, arrow.y),
      world.skinIndex > 14 ? 13 : 8,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _hex(world.skin.color).withValues(alpha: 0.36),
    );
    _drawFrameCentered(
      canvas,
      effectKey,
      frame,
      arrow.x,
      arrow.y,
      arrow.critical ? 68 : 52,
      rotation: rotation,
      alpha: 0.95,
    );
  }

  /// The Alpha's arrow: a gold comet with a white core, fletching and sparkles.
  void _drawGoldenArrow(Canvas canvas, Arrow arrow) {
    final length = arrow.critical ? 84.0 : 66.0;
    final pulse = 0.85 + 0.15 * sin(arrow.age * 30);
    const gold = Color(0xFFFFC83D);
    const paleGold = Color(0xFFFFF1B0);
    const white = Color(0xFFFFFFFF);
    canvas.save();
    canvas.translate(arrow.x, arrow.y);
    canvas.rotate(atan2(arrow.vy, arrow.vx));

    // Comet trail, fading out behind the arrow.
    final tail = -length * 1.1;
    final head = length * 0.3;
    canvas.drawPath(
      Path()
        ..moveTo(head, -7 * pulse)
        ..lineTo(tail, 0)
        ..lineTo(head, 7 * pulse)
        ..close(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(Offset(tail, 0), Offset(head, 0), [
          gold.withValues(alpha: 0),
          gold.withValues(alpha: 0.75),
        ]),
    );

    // Glow around the tip.
    final tip = Offset(length * 0.34, 0);
    canvas.drawCircle(
      tip,
      17 * pulse,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          tip,
          17 * pulse,
          [
            white.withValues(alpha: 0.9),
            gold.withValues(alpha: 0.4),
            gold.withValues(alpha: 0),
          ],
          [0, 0.45, 1],
        ),
    );

    // Shaft.
    canvas.drawLine(
      Offset(-length * 0.45, 0),
      Offset(length * 0.3, 0),
      Paint()
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          Offset(-length * 0.45, 0),
          Offset(length * 0.3, 0),
          [gold, white],
        ),
    );

    // Fletching: two swept feathers at the tail.
    final feathers = Path();
    for (final side in [-1.0, 1.0]) {
      feathers
        ..moveTo(-length * 0.28, 0)
        ..lineTo(-length * 0.5, side * 9)
        ..lineTo(-length * 0.6, side * 9)
        ..lineTo(-length * 0.45, 0);
    }
    canvas.drawPath(feathers, Paint()..color = gold.withValues(alpha: 0.9));

    // Arrowhead.
    final headPath = Path()
      ..moveTo(length * 0.54, 0)
      ..lineTo(length * 0.26, -9)
      ..lineTo(length * 0.33, 0)
      ..lineTo(length * 0.26, 9)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(length * 0.26, 0),
          Offset(length * 0.54, 0),
          [gold, white],
        ),
    );
    canvas.drawPath(
      headPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFB8860B),
    );

    // Sparkles drifting in the trail.
    final sparkle = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 3; index += 1) {
      final flicker = 0.5 + 0.5 * sin(arrow.age * 22 + index * 2.1);
      final centre = Offset(
        -length * (0.35 + index * 0.28),
        sin(arrow.age * 14 + index * 2) * 6,
      );
      final reach = 2.5 + 2.5 * flicker;
      sparkle.color = paleGold.withValues(alpha: 0.35 + 0.55 * flicker);
      canvas.drawLine(
        centre.translate(-reach, 0),
        centre.translate(reach, 0),
        sparkle,
      );
      canvas.drawLine(
        centre.translate(0, -reach),
        centre.translate(0, reach),
        sparkle,
      );
    }
    canvas.restore();
  }

  void _drawEnergyArrow(Canvas canvas, Arrow arrow, GameWorld world) {
    final length = arrow.critical ? 52.0 : 40.0;
    final color = _hex(world.skin.color);
    canvas.save();
    canvas.translate(arrow.x, arrow.y);
    canvas.rotate(atan2(arrow.vy, arrow.vx));
    final path = Path()
      ..moveTo(length * .5, 0)
      ..lineTo(length * .06, -7)
      ..lineTo(length * .16, -2)
      ..lineTo(-length * .5, -2)
      ..lineTo(-length * .5, 2)
      ..lineTo(length * .16, 2)
      ..lineTo(length * .06, 7)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      Offset(-length * .3, 0),
      Offset(length * .3, 0),
      Paint()
        ..color = const Color(0xfff6ffff)
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  void _drawEffect(Canvas canvas, Effect effect, GameWorld world) {
    if (effect.sheetKey != null && effect.animation != null) {
      final frames = library.animation(effect.sheetKey!, effect.animation!);
      if (frames.isNotEmpty) {
        final progress = max(0.0, min(0.999, effect.age / effect.duration));
        _drawFrameCentered(
          canvas,
          effect.sheetKey!,
          _frameAt(frames, (progress * 5).floor()),
          effect.x,
          effect.y,
          effect.size,
          alpha: 1 - progress * 0.12,
        );
      }
      return;
    }
    if (effect.type.startsWith('skin_')) {
      final progress = max(0.0, min(1.0, effect.age / effect.duration));
      final radius = effect.size * (0.18 + progress * 0.5);
      final color = _hex(effect.color ?? '#8ff7ff');
      final alpha = (1 - progress) * 0.7;
      final ultimate = effect.type == 'skin_ultimate';
      final stroke = Paint()
        ..blendMode = BlendMode.plus
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(3, effect.size * 0.025);
      final rings = ultimate ? 4 : 2;
      for (var ring = 0; ring < rings; ring += 1) {
        canvas.drawCircle(
          Offset(effect.x, effect.y),
          radius * (1 + ring * 0.32),
          stroke,
        );
      }
      final rays = ultimate ? 14 : 6;
      for (var ray = 0; ray < rays; ray += 1) {
        final angle = ray * pi * 2 / rays + progress * 1.8;
        canvas.drawLine(
          Offset(
            effect.x + cos(angle) * radius * 0.4,
            effect.y + sin(angle) * radius * 0.4,
          ),
          Offset(
            effect.x + cos(angle) * radius * 1.35,
            effect.y + sin(angle) * radius * 1.35,
          ),
          stroke,
        );
      }
      return;
    }
    final key = effect.sheet == 'defeat'
        ? 'DEFEAT_EFFECT_SHEET'
        : 'ARROW_EFFECT_SHEET';
    final frames = library.animation(key, effect.type);
    if (frames.isEmpty) return;
    final progress = max(0.0, min(0.999, effect.age / effect.duration));
    _drawFrameCentered(
      canvas,
      key,
      _frameAt(frames, (progress * 5).floor()),
      effect.x,
      effect.y,
      effect.size,
      alpha: 1 - progress * 0.2,
    );
  }

  void _drawEnemy(Canvas canvas, Enemy enemy, GameWorld world) {
    final frame =
        ((world.time * (enemy.tier == 'boss' ? 7 : 9) + enemy.id * 0.7) % 5)
            .floor();
    final alpha =
        enemy.tier == 'rare' &&
            world.areaIndex == 4 &&
            sin(world.time * 3) < -0.4
        ? 0.35
        : 1.0;
    _drawAnchored(
      canvas,
      enemy.assetKey,
      enemy.animation,
      frame,
      enemy.x,
      enemy.y,
      enemy.size,
      flip: enemyFlipTowardHero(
        enemy.animation,
        frame,
        enemy.x,
        world.player.x,
      ),
      alpha: alpha,
    );
    if (enemy.tier != 'common') {
      final barWidth = enemy.tier == 'boss'
          ? enemy.size * 0.72
          : enemy.size * 0.58;
      final barY = enemy.y - enemy.size * 0.93;
      canvas.drawRect(
        Rect.fromLTWH(enemy.x - barWidth / 2, barY, barWidth, 5),
        Paint()..color = _rgba(10, 7, 28, .76),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          enemy.x - barWidth / 2,
          barY,
          barWidth * max(0, enemy.hp / enemy.maxHp),
          5,
        ),
        Paint()
          ..color = enemy.tier == 'boss' ? _hex('#ffca55') : _hex('#8ff7ff'),
      );
    }
    if (enemy.tier == 'boss' &&
        world.areaIndex == 6 &&
        sin(world.time * 2.1) < -0.1) {
      canvas.drawCircle(
        Offset(enemy.x, enemy.y - enemy.size * 0.48),
        enemy.size * 0.48,
        Paint()
          ..color = _rgba(111, 243, 255, .75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }

  void _drawProjectile(Canvas canvas, Projectile projectile, GameWorld world) {
    if (projectile.type == 'beam') {
      final active = projectile.age > 0.68;
      final rect = Rect.fromLTWH(
        projectile.x - (active ? projectile.size : 3),
        0,
        active ? projectile.size * 2 : 6,
        world.height,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = active
              ? _rgba(118, 247, 255, .72)
              : _rgba(255, 84, 177, .26),
      );
      return;
    }
    if (projectile.type == 'wave') {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(projectile.x, projectile.y + 20),
          radius: projectile.size,
        ),
        pi,
        pi,
        false,
        Paint()
          ..color = _hex('#b07bff')
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
      return;
    }
    final radius = projectile.size * 1.8;
    final center = Offset(projectile.x, projectile.y);
    final acid = projectile.type == 'acid';
    final gradient = ui.Gradient.radial(
      center,
      radius,
      [
        acid ? _hex('#d8ff61') : _hex('#ffffff'),
        acid ? _hex('#73ef7f') : _hex('#e56cff'),
        _rgba(83, 49, 210, 0),
      ],
      [0, 0.25, 1],
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = gradient,
    );
  }

  void draw(Canvas canvas, GameWorld world) {
    final width = world.width;
    final height = world.height;
    final player = world.player;
    final animation = world.playerAnimation();

    _drawBackdrop(canvas, world);
    _drawTelegraphs(canvas, world);
    _drawGround(canvas, world);
    _drawAbilityZones(canvas, world);
    for (final pickup in world.pickups) {
      _drawPickup(canvas, pickup, world);
    }
    for (final arrow in world.arrows) {
      _drawArrow(canvas, arrow, world);
    }
    for (final enemy in world.enemies) {
      _drawEnemy(canvas, enemy, world);
    }
    for (final projectile in world.projectiles) {
      _drawProjectile(canvas, projectile, world);
    }

    // Player.
    final frame = animation.name == 'shoot'
        ? heroShootFrame(player.shootTimer)
        : (world.time * (animation.name == 'run' ? 12 : 9)).floor();
    final playerHeight = min(104.0, max(78.0, height * 0.13));
    final blink =
        player.invulnerable > 0 && (player.invulnerable * 14).floor() % 2 == 0;
    _drawAnchored(
      canvas,
      animation.key,
      animation.name,
      frame,
      player.x,
      player.y,
      playerHeight,
      flip: player.facing < 0,
      alpha: blink ? 0.45 : 1,
    );

    for (final effect in world.effects) {
      _drawEffect(canvas, effect, world);
    }

    final full = Rect.fromLTWH(0, 0, width, height);
    if (world.skinIndex == 8 && world.damageModeTimer > 0) {
      canvas.drawRect(full, Paint()..color = _rgba(2, 0, 12, .64));
    }
    if (world.skinIndex == 18 &&
        player.actionName == 'ultimate' &&
        player.actionTimer > 0) {
      final flash = (world.time * 24).floor() % 2 == 1;
      canvas.drawRect(
        full,
        Paint()
          ..color = flash ? _rgba(255, 0, 190, .18) : _rgba(0, 255, 255, .16),
      );
    }
    if (world.skinIndex == 19 &&
        player.actionName == 'ultimate' &&
        player.actionTimer > 0) {
      canvas.drawRect(
        full,
        Paint()..color = _rgba(255, 255, 255, min(0.92, player.actionTimer)),
      );
    }
    if (world.areaIndex == 3) {
      final paint = Paint()..color = _rgba(155, 255, 218, .055);
      for (var index = 0; index < 3; index += 1) {
        final y = (world.time * 18 + index * height * 0.36) % height;
        canvas.drawRect(
          Rect.fromLTWH(0, y, width, max(18, height * 0.04)),
          paint,
        );
      }
    }
  }
}
