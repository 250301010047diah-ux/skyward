// Run with: flutter test tool/sprite_audit.dart
// Exports actual renderer output for visual inspection; not part of unit tests.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyfall/game/asset_manifest.dart';
import 'package:skyfall/game/assets.dart';
import 'package:skyfall/game/renderer.dart';
import 'package:skyfall/game/world.dart';

class _SilentAudio implements SoundSink {
  @override
  void play(String name) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export sprite review', () async {
    final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
    if (fontFile.existsSync()) {
      final loader = FontLoader('Audit')
        ..addFont(
          Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
        );
      await loader.load();
    }
    final directory = Directory('build/sprite_audit')
      ..createSync(recursive: true);
    final library = AssetLibrary();
    final renderer = ArenaRenderer(library);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    void label(String text, double x, double y) {
      final paragraph =
          (ui.ParagraphBuilder(
              ui.ParagraphStyle(fontFamily: 'Audit', fontSize: 13),
            )..addText(text)).build()
            ..layout(const ui.ParagraphConstraints(width: 300));
      canvas.drawParagraph(paragraph, ui.Offset(x, y));
    }

    for (var skin = 0; skin < 20; skin++) {
      final world = GameWorld(
        areaIndex: 0,
        skinIndex: skin,
        relics: const [],
        tuning: const Tuning(),
        audio: _SilentAudio(),
        callbacks: const WorldCallbacks(),
        random: Random(1),
      );
      for (final key in [world.skin.coreKey, world.skin.effectKey]) {
        if (kAssetFiles.containsKey(key)) await library.load(key);
      }
      world.player.x = 200;
      world.player.y = 590;
      world.player.shootTimer = .18;
      final x = skin % 4 * 300.0, y = skin ~/ 4 * 290.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 300, 290));
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 300, 290),
        ui.Paint()..color = const ui.Color(0xff273546),
      );
      // Render three upward flight frames, plus diagonal and horizontal shots.
      for (var f = 0; f < 3; f++) {
        world.arrows.add(
          Arrow(x: 70 + f * 120, y: 220, vx: 0, vy: -600, damage: 1)
            ..age = f / 18,
        );
      }
      world.arrows.add(Arrow(x: 100, y: 370, vx: -400, vy: -400, damage: 1));
      world.arrows.add(Arrow(x: 300, y: 370, vx: 600, vy: 0, damage: 1));
      canvas.scale(.75);
      world.height = 380;
      world.groundY = 360;
      world.player.y = 360;
      for (final arrow in world.arrows) {
        arrow.y *= .5;
      }
      renderer.draw(canvas, world);
      canvas.restore();
      label('Skin ${skin + 1}: UP / diagonal / RIGHT', x + 6, y + 4);
    }
    final image = await recorder.endRecording().toImage(1200, 1450);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${directory.path}/renderer_after.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());

    // Paired enemies must look inward toward the hero between them.
    await library.load('ENEMIES_AREA_1_COMMON');
    await library.load('ENEMIES_AREA_3_COMMON');
    final world = GameWorld(
      areaIndex: 0,
      relics: const [],
      tuning: const Tuning(),
      audio: _SilentAudio(),
      callbacks: const WorldCallbacks(),
      random: Random(1),
    );
    await library.loadSkin(0);
    world.player.x = 200;
    world.player.y = 590;
    for (final x in [80.0, 320.0]) {
      world.spawnEnemy('common', commonIndex: 1)
        ..x = x
        ..y = 590;
    }
    final enemiesRecorder = ui.PictureRecorder();
    renderer.draw(ui.Canvas(enemiesRecorder), world);
    final enemiesImage = await enemiesRecorder.endRecording().toImage(400, 700);
    final enemiesBytes = await enemiesImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    File(
      '${directory.path}/enemies_after.png',
    ).writeAsBytesSync(enemiesBytes!.buffer.asUint8List());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
