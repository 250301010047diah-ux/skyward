// Unit checks for the data ported from game js and the number formatting used by the HUD.

import 'package:flutter_test/flutter_test.dart';

import 'package:skyfall/game/data.dart';
import 'package:skyfall/ui/style.dart';

void main() {
  test('ported data matches the web game', () {
    expect(kAreas.length, 30);
    expect(kSkins.length, 20);
    expect(kReinforcements.length, 20);
    expect(kCoreSheets, contains('HUD_ICON_ATLAS'));
  });

  test('numbers are grouped like toLocaleString("id-ID")', () {
    expect(formatId(0), '0');
    expect(formatId(1234), '1.234');
    expect(formatId(1234567.9), '1.234.567');
  });
}
