// Colours, fonts and sizing helpers.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/world.dart';

/// Web `.game-shell`: `#160c39`; `body`: `#0e0e10`.
const kShellColor = Color(0xFF160C39);
const kBodyColor = Color(0xFF0E0E10);

Color rgba(int r, int g, int b, [double a = 1]) => Color.fromRGBO(r, g, b, a);

Color hex(String value) =>
    Color(0xFF000000 | int.parse(value.substring(1), radix: 16));

/// Bungee is the display face used throughout the CSS.
TextStyle display({
  double size = 14,
  Color color = Colors.white,
  double? height,
}) => GoogleFonts.bungee(fontSize: size, color: color, height: height);

/// Nunito Sans is the body face (weight 900 for badges).
TextStyle body({
  double size = 14,
  Color color = Colors.white,
  FontWeight weight = FontWeight.w900,
}) => GoogleFonts.nunitoSans(fontSize: size, color: color, fontWeight: weight);

/// Converts CSS `cqw`, `cqh`, `cqmin` values against the game frame size.
class Cq {
  const Cq(this.width, this.height);

  factory Cq.of(BoxConstraints constraints) =>
      Cq(constraints.maxWidth, constraints.maxHeight);

  final double width;
  final double height;

  double w(double percent) => width * percent / 100;
  double h(double percent) => height * percent / 100;
  double min(double percent) =>
      (width < height ? width : height) * percent / 100;

  /// `clamp(low, percent cqw, high)`.
  double cw(double low, double percent, double high) =>
      clampd(w(percent), low, high);
  double ch(double low, double percent, double high) =>
      clampd(h(percent), low, high);
  double cmin(double low, double percent, double high) =>
      clampd(min(percent), low, high);
}

/// Button click sound. The game sets [click]; widgets call it through [tapped].
class UiSound {
  UiSound._();

  static void Function()? click;
}

void tapped(VoidCallback action) {
  UiSound.click?.call();
  action();
}

/// Formats numbers like `toLocaleString("id-ID")`: dots as thousand separators.
String formatId(num value) {
  final digits = value.floor().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
