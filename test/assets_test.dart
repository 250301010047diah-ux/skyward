// Loads every area and skin the same way game.js does, to catch missing or broken assets.

import 'package:flutter_test/flutter_test.dart';

import 'package:skyfall/game/asset_manifest.dart';
import 'package:skyfall/game/assets.dart';
import 'package:skyfall/game/data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every area and skin loads except the known gaps in the source assets',
    () async {
      final library = AssetLibrary();
      await library.loadCore();
      final failures = <String>[];
      for (var area = 0; area < kAreas.length; area++) {
        try {
          await library.loadArea(area);
        } catch (error) {
          failures.add('area ${area + 1}: $error');
        }
      }
      for (var skin = 0; skin < kSkins.length; skin++) {
        try {
          await library.loadSkin(skin);
        } catch (error) {
          failures.add('skin ${skin + 1}: $error');
        }
      }
      // These keys are referenced by game js/game/data.js but are missing from
      // game js/assets.json, so the web build cannot load them either.
      const knownGaps = [
        'ENEMIES_AREA_19_COMMON',
        'ENEMIES_AREA_21_COMMON',
        'SKIN_11_CORE',
        'SKIN_12_EFFECTS',
      ];
      for (final key in knownGaps) {
        expect(kAssetFiles.containsKey(key), isFalse, reason: key);
      }
      expect(failures, hasLength(knownGaps.length));
      for (final key in knownGaps) {
        expect(
          failures.any((failure) => failure.contains(key)),
          isTrue,
          reason: key,
        );
      }

      await library.loadSkin(0);
      expect(library.get('SKIN_01_CORE'), isNotNull);
      expect(library.animation('SKIN_01_CORE', 'run'), isNotEmpty);
      final bow = library.animation('SKIN_01_CORE', 'shoot')[1];
      expect(bow, same(library.frame('SKIN_01_CORE', 'shoot_2')));
      expect(bow.isolatedImage, isNotNull);
      expect(bow.imageSource.left, 0);
      expect(bow.imageSource.width, bow.isolatedImage!.width.toDouble());
      final cape = library.frame('SKIN_07_CORE', 'run_2')!;
      expect(
        cape.crop.left,
        lessThanOrEqualTo(421),
        reason: 'Preserve the trailing cape outside the old crop',
      );
      expect(library.icon('coin'), isNotNull);
    },
  );
}
