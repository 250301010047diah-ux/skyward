import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyfall/game/sprite_crop.dart';
import 'package:skyfall/game/sprite_visuals.dart';

void main() {
  test(
    'enemies face inward from either side, including left-facing artwork',
    () {
      // Beetle faces right in its source; the crow faces left.
      expect(enemyFlipTowardHero('horn_beetle_bounce', 0, 80, 200), isFalse);
      expect(enemyFlipTowardHero('horn_beetle_bounce', 0, 320, 200), isTrue);
      expect(enemyFlipTowardHero('storm_crow_circle', 0, 80, 200), isTrue);
      expect(enemyFlipTowardHero('storm_crow_circle', 0, 320, 200), isFalse);
      // A frame in which the beetle turns must also be corrected.
      expect(enemyFlipTowardHero('horn_beetle_bounce', 2, 80, 200), isTrue);
      expect(enemyFlipTowardHero('horn_beetle_bounce', 2, 320, 200), isFalse);
    },
  );

  test('diagonal shadow and lightning arrows point up when travelling up', () {
    expect(
      arrowRotation(0, -600, arrowArtworkHeading(4)!),
      closeTo(-3 * pi / 4, 1e-9),
    );
    expect(
      arrowRotation(0, -600, arrowArtworkHeading(8)!),
      closeTo(-5 * pi / 4, 1e-9),
    );
    // Turning/homing uses the current velocity, including a downward shot.
    expect(arrowRotation(600, 0, 0), 0);
    expect(arrowRotation(0, 600, 0), closeTo(pi / 2, 1e-9));
    expect(
      arrowArtworkHeading(7),
      isNull,
    ); // Ground impact, not a flight arrow.
    expect(arrowArtworkHeading(16), isNull); // Portal opening has no arrow.
  });

  test(
    'shooting starts on the intact bow pose and recovers without atlas bleed',
    () {
      expect(heroShootFrame(.18), 1);
      expect(heroShootFrame(.12), 1);
      expect(heroShootFrame(.04), 0);
      expect(heroShootFrame(0), 0);
    },
  );

  test(
    'crop removes neighbouring fragments while retaining translucent edges',
    () {
      final pixels = Uint8List(8 * 6 * 4);
      void pixel(int x, int y, int alpha) {
        final i = (y * 8 + x) * 4;
        pixels.setRange(i, i + 4, [alpha, 0, 0, alpha]);
      }

      // A fragment appears before the main character in scan order.
      pixel(0, 0, 255);
      for (var y = 2; y <= 4; y++) {
        for (var x = 2; x <= 4; x++) {
          pixel(x, y, 255);
        }
      }
      pixel(5, 3, 8); // antialiased character edge
      pixel(7, 3, 255); // neighbouring hair
      final cleaned = isolateSprite(pixels, 8, 6);
      expect(cleaned[3], 0);
      expect(cleaned[(3 * 8 + 7) * 4 + 3], 0);
      expect(cleaned[(3 * 8 + 3) * 4 + 3], 255);
      expect(cleaned[(3 * 8 + 5) * 4 + 3], 8);
      expect(pixels[3], 255, reason: 'Do not mutate the shared atlas');
      expect(isolateSprite(Uint8List(16), 2, 2), everyElement(0));
    },
  );
}
