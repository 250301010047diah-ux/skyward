import 'dart:typed_data';

/// Keeps the character connected to the largest opaque island, removing pieces
/// of adjacent atlas frames. Faint antialiased edge pixels are retained.
Uint8List isolateSprite(Uint8List rgba, int width, int height) {
  final count = width * height;
  final labels = Int32List(count);
  final queue = Int32List(count);
  var label = 0, largestLabel = 0, largestSize = 0;
  for (var seed = 0; seed < count; seed++) {
    if (labels[seed] != 0 || rgba[seed * 4 + 3] < 16) continue;
    label++;
    var head = 0, tail = 1;
    queue[0] = seed;
    labels[seed] = label;
    while (head < tail) {
      final p = queue[head++];
      final x = p % width, y = p ~/ width;
      void visit(int n) {
        if (labels[n] == 0 && rgba[n * 4 + 3] >= 16) {
          labels[n] = label;
          queue[tail++] = n;
        }
      }

      if (x > 0) visit(p - 1);
      if (x + 1 < width) visit(p + 1);
      if (y > 0) visit(p - width);
      if (y + 1 < height) visit(p + width);
    }
    if (tail > largestSize) {
      largestSize = tail;
      largestLabel = label;
    }
  }
  final output = Uint8List(rgba.length);
  if (largestLabel == 0) return output;
  for (var p = 0; p < count; p++) {
    var keep = labels[p] == largestLabel;
    // Preserve only the low-alpha fringe next to the selected silhouette.
    if (!keep && rgba[p * 4 + 3] < 16) {
      final x = p % width, y = p ~/ width;
      keep =
          (x > 0 && labels[p - 1] == largestLabel) ||
          (x + 1 < width && labels[p + 1] == largestLabel) ||
          (y > 0 && labels[p - width] == largestLabel) ||
          (y + 1 < height && labels[p + width] == largestLabel);
    }
    if (keep) output.setRange(p * 4, p * 4 + 4, rgba, p * 4);
  }
  return output;
}
