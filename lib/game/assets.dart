// Loads sprite sheets and their frame data from Dart metadata.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'asset_manifest.dart';
import 'data.dart';
import 'sprite_frames.dart';
import 'sprite_crop.dart';

class FrameInfo {
  FrameInfo({
    required this.name,
    required this.source,
    required this.content,
    required this.anchor,
  });

  factory FrameInfo.fromJson(Map<String, dynamic> json) {
    Rect rect(Map<String, dynamic> r) => Rect.fromLTWH(
      (r['x'] as num).toDouble(),
      (r['y'] as num).toDouble(),
      (r['w'] as num).toDouble(),
      (r['h'] as num).toDouble(),
    );
    final anchor = json['anchor'] as Map<String, dynamic>?;
    return FrameInfo(
      name: json['name'] as String,
      source: rect(json['source'] as Map<String, dynamic>),
      content: json['content'] == null
          ? null
          : rect(json['content'] as Map<String, dynamic>),
      anchor: anchor == null
          ? Offset.zero
          : Offset(
              (anchor['x'] as num).toDouble(),
              (anchor['y'] as num).toDouble(),
            ),
    );
  }

  final String name;
  final Rect source;
  final Rect? content;
  final Offset anchor;
  ui.Image? isolatedImage;
  Rect? isolatedBounds;

  /// Web `frame.content || frame.source`.
  Rect get crop => isolatedBounds ?? content ?? source;

  Rect get imageSource => isolatedImage == null
      ? crop
      : Rect.fromLTWH(0, 0, crop.width, crop.height);
}

class LoadedSheet {
  LoadedSheet({
    required this.image,
    required this.frames,
    required this.animations,
  });

  final ui.Image image;
  final Map<String, FrameInfo> frames; // by name, `frames.frames` in the JSON
  final Map<String, List<FrameInfo>> animations; // `frames.animations[].frames`
}

/// Notifies listeners whenever a sheet finishes loading, so previews can repaint.
class AssetLibrary extends ChangeNotifier {
  final Map<String, LoadedSheet> _items = {};
  final Map<String, Future<LoadedSheet>> _loading = {};

  String imagePath(String key) {
    final file = kAssetFiles[key];
    if (file == null) throw StateError('Asset $key tidak tersedia');
    return 'assets/images/$file';
  }

  Future<LoadedSheet> load(String key) {
    final existing = _items[key];
    if (existing != null) return Future.value(existing);
    final running = _loading[key];
    if (running != null) return running;
    final task = () async {
      final imageData = await rootBundle.load(imagePath(key));
      final codec = await ui.instantiateImageCodec(
        imageData.buffer.asUint8List(),
      );
      final image = (await codec.getNextFrame()).image;
      final frameData = kSpriteFrames[key];
      final frames = <String, FrameInfo>{};
      final animations = <String, List<FrameInfo>>{};
      if (frameData != null) {
        for (final entry
            in (frameData['frames'] as List<dynamic>? ?? const [])) {
          final frame = FrameInfo.fromJson(entry as Map<String, dynamic>);
          frames[frame.name] = frame;
        }
        for (final entry
            in (frameData['animations'] as List<dynamic>? ?? const [])) {
          final map = entry as Map<String, dynamic>;
          animations[map['name'] as String] = [
            for (final frame in (map['frames'] as List<dynamic>? ?? const []))
              frames[(frame as Map<String, dynamic>)['name']] ??
                  FrameInfo.fromJson(frame),
          ];
        }
      }
      if (key.startsWith('SKIN_') && key.endsWith('_CORE')) {
        await _isolateHeroFrames(key, image, frames.values);
      }
      final sheet = LoadedSheet(
        image: image,
        frames: frames,
        animations: animations,
      );
      _items[key] = sheet;
      notifyListeners();
      return sheet;
    }();
    _loading[key] = task;
    return task.whenComplete(() => _loading.remove(key));
  }

  Future<void> loadCore() async {
    await Future.wait(kCoreSheets.map(load));
  }

  Future<void> _isolateHeroFrames(
    String key,
    ui.Image image,
    Iterable<FrameInfo> frames,
  ) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return;
    final pixels = data.buffer.asUint8List();
    final bounds = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    for (final frame in frames) {
      var crop = frame.crop.inflate(2).intersect(bounds);
      if (key == 'SKIN_07_CORE' && frame.name == 'run_2') {
        // The original crop cuts seven pixels from the trailing cape.
        crop = Rect.fromLTRB(419, crop.top, crop.right, crop.bottom);
      }
      // Only shooting poses need island removal; keep floating accessories and
      // particles in movement poses. Padding restores antialiased crop edges.
      if (frame.name != 'shoot_1' && frame.name != 'shoot_2') {
        frame.isolatedBounds = crop;
        continue;
      }
      if (key == 'SKIN_04_CORE' && frame.name == 'shoot_2') {
        // The adjacent release pose starts at x=792 and touches this beam.
        crop = Rect.fromLTRB(crop.left, crop.top, 790, crop.bottom);
      }
      final width = crop.width.toInt(), height = crop.height.toInt();
      final rgba = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        final start =
            ((crop.top.toInt() + y) * image.width + crop.left.toInt()) * 4;
        rgba.setRange(y * width * 4, (y + 1) * width * 4, pixels, start);
      }
      final cleaned = isolateSprite(rgba, width, height);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        cleaned,
        width,
        height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      frame.isolatedImage = await completer.future;
      frame.isolatedBounds = crop;
    }
  }

  Future<void> loadArea(int index) async {
    final area = kAreas[index];
    final reinforcement = reinforcementFor(index);
    await Future.wait([
      load(area.bgKey),
      load(area.commonKey),
      load(area.eliteKey),
      if (reinforcement != null) load(reinforcement[0]),
    ]);
  }

  Future<void> loadSkin(int index) async {
    final skin = kSkins[index];
    await Future.wait([
      load(skin.coreKey),
      load(skin.skillKey),
      load(skin.effectKey),
    ]);
  }

  LoadedSheet? get(String key) => _items[key];

  List<FrameInfo> animation(String key, String name) =>
      _items[key]?.animations[name] ?? const [];

  FrameInfo? frame(String key, String name) => _items[key]?.frames[name];

  /// Web `iconDataUrl`: looks in HUD, powerup and relic atlases, in that order.
  ({LoadedSheet sheet, FrameInfo frame})? icon(String name) {
    const order = ['HUD_ICON_ATLAS', 'POWERUP_ATLAS', 'RELIC_ATLAS_3'];
    for (final key in order) {
      final sheet = _items[key];
      final found = sheet?.frames[name];
      if (sheet != null && found != null) return (sheet: sheet, frame: found);
    }
    return null;
  }
}
