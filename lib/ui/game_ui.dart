// Shared UI state (the web `createUi`), plus small widgets that draw atlas icons.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/assets.dart';
import '../game/renderer.dart';
import '../game/world.dart';

/// What the Flutter layer shows on top of the canvas.
class GameUi {
  final ValueNotifier<HudState?> hud = ValueNotifier(null);
  final ValueNotifier<Widget?> overlay = ValueNotifier(null);
  final ValueNotifier<bool> hintVisible = ValueNotifier(true);

  void hideOverlay() => overlay.value = null;

  void hideHint() => hintVisible.value = false;

  void dispose() {
    hud.dispose();
    overlay.dispose();
    hintVisible.dispose();
  }
}

/// Draws one frame of an atlas (HUD icon, powerup or relic) — the web `iconDataUrl`.
class SpriteIcon extends StatelessWidget {
  const SpriteIcon({
    super.key,
    required this.library,
    required this.name,
    required this.size,
    this.grayscale = false,
  });

  final AssetLibrary library;
  final String name;
  final double size;
  final bool grayscale;

  @override
  Widget build(BuildContext context) {
    final icon = library.icon(name);
    final child = SizedBox.square(
      dimension: size,
      child: icon == null
          ? null
          : CustomPaint(painter: _SpritePainter(icon.sheet.image, icon.frame)),
    );
    if (!grayscale) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: child,
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.frame);

  final ui.Image image;
  final FrameInfo frame;

  @override
  void paint(Canvas canvas, Size size) {
    ArenaRenderer.paintIconFrame(canvas, image, frame, size);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.frame != frame;
}

/// Web `.relic-icon`: gentle float and tilt, 2 s loop.
class FloatingIcon extends StatefulWidget {
  const FloatingIcon({super.key, required this.child});

  final Widget child;

  @override
  State<FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<FloatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eased = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: eased,
      child: widget.child,
      builder: (context, child) {
        final t = eased.value;
        return Transform.translate(
          offset: Offset(0, -7 * t),
          child: Transform.rotate(
            angle: (-2 + 4 * t) * 3.1415926535 / 180,
            child: child,
          ),
        );
      },
    );
  }
}
