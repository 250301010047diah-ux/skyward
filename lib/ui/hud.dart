// Port of the HUD and touch controls from game js/game/ui.js + styles.css.
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/assets.dart';
import '../game/world.dart';
import 'game_ui.dart';
import 'style.dart';

class Hud extends StatelessWidget {
  const Hud({
    super.key,
    required this.state,
    required this.library,
    required this.hintVisible,
    required this.onJump,
    required this.onSkill,
    required this.volume,
    required this.onVolume,
    required this.onHelp,
    required this.onMenu,
    required this.onJoystick,
    required this.onFire,
    required this.onUpgrade,
  });

  final HudState state;
  final AssetLibrary library;
  final bool hintVisible;
  final VoidCallback onJump;
  final void Function(String type) onSkill;
  final double volume;
  final VoidCallback onVolume;
  final VoidCallback onHelp;
  final VoidCallback onMenu;
  final ValueChanged<double> onJoystick;
  final ValueChanged<bool> onFire;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cq = Cq.of(constraints);
        final s1Ready = state.skill1 <= 0;
        final s2Ready = state.skill2 <= 0;
        final ultReady = state.ultimate >= 100;
        final joy = cq.cw(116, 30, 140);
        final jump = cq.cw(64, 18, 92);
        final gap = cq.cmin(10, 2.5, 16);
        final jumpBottom = cq.ch(12, 3, 26);
        final edge = cq.cw(12, 4, 24);
        final skill = cq.cw(48, 12, 58);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Top stats (`.hud-layer`): non-interactive, so taps reach the canvas.
            IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Padding(
                      padding: EdgeInsets.all(cq.cmin(6, 1.8, 11)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopRow(state: state, cq: cq),
                          SizedBox(height: cq.cmin(4, 1.2, 8)),
                          _StatusRow(state: state, library: library, cq: cq),
                          if (state.bossName != null) ...[
                            SizedBox(height: cq.cmin(6, 1.4, 10)),
                            _BossBar(
                              name: state.bossName!,
                              ratio: state.bossRatio,
                              cq: cq,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: cq.ch(18, 4, 38),
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: hintVisible ? 1 : 0,
                        child: _GestureHint(cq: cq),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Joystick, bottom-left: moves the Sky Elf.
            Positioned(
              left: cq.cw(12, 4, 22),
              bottom: jumpBottom,
              child: Joystick(size: joy, onChanged: onJoystick),
            ),
            // Utilities above the joystick: menu, help, volume, upgrade.
            Positioned(
              left: cq.cw(12, 4, 22),
              bottom: jumpBottom + joy + gap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundButton(
                    icon: Icons.menu,
                    diameter: cq.cw(40, 10, 48),
                    onPressed: onMenu,
                  ),
                  SizedBox(height: cq.cmin(6, 1.6, 10)),
                  _RoundButton(
                    text: '?',
                    diameter: cq.cw(40, 10, 48),
                    onPressed: onHelp,
                  ),
                  SizedBox(height: cq.cmin(6, 1.6, 10)),
                  _RoundButton(
                    icon: volume <= 0
                        ? Icons.volume_off
                        : (volume < 1 ? Icons.volume_down : Icons.volume_up),
                    diameter: cq.cw(40, 10, 48),
                    onPressed: onVolume,
                  ),
                  SizedBox(height: cq.cmin(6, 1.6, 10)),
                  _RoundButton(
                    icon: Icons.upgrade,
                    diameter: cq.cw(40, 10, 48),
                    enabled: state.upgradeTokens > 0,
                    badge: state.upgradeTokens,
                    onPressed: onUpgrade,
                  ),
                ],
              ),
            ),
            // Fire, left of the jump button: shoots only while held.
            Positioned(
              right: edge + jump + gap,
              bottom: jumpBottom,
              child: _HoldButton(
                label: 'TEMBAK',
                diameter: cq.cw(60, 15, 76),
                onHold: onFire,
              ),
            ),
            // Skills stacked above the jump button.
            Positioned(
              right: edge,
              bottom: jumpBottom + jump + gap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UltimateButton(
                    charge: state.ultimate,
                    diameter: cq.cw(58, 14, 70),
                    enabled: ultReady,
                    percentLabel: '${state.ultimate.floor()}%',
                    onPressed: () => onSkill('ultimate'),
                  ),
                  SizedBox(height: gap * 0.6),
                  _SkillButton(
                    label: 'S2',
                    sub: state.skill2 > 0
                        ? state.skill2.toStringAsFixed(1)
                        : 'SIAP',
                    diameter: skill,
                    enabled: s2Ready,
                    onPressed: () => onSkill('skill2'),
                    colors: const [
                      Color(0xFF7BF6FF),
                      Color(0xFF5B4CDD),
                      Color(0xFF25194E),
                    ],
                    border: hex('#8FF6FF'),
                  ),
                  SizedBox(height: gap * 0.6),
                  _SkillButton(
                    label: 'S1',
                    sub: state.skill1 > 0
                        ? state.skill1.toStringAsFixed(1)
                        : 'SIAP',
                    diameter: skill,
                    enabled: s1Ready,
                    onPressed: () => onSkill('skill1'),
                    colors: const [
                      Color(0xFF7BF6FF),
                      Color(0xFF5B4CDD),
                      Color(0xFF25194E),
                    ],
                    border: hex('#8FF6FF'),
                  ),
                ],
              ),
            ),
            // Jump, bottom-right.
            Positioned(
              right: edge,
              bottom: jumpBottom,
              child: _JumpButton(diameter: jump, onPressed: onJump),
            ),
          ],
        );
      },
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.state, required this.cq});

  final HudState state;
  final Cq cq;

  @override
  Widget build(BuildContext context) {
    final areaNumber = 'A${state.areaIndex + 1}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cq.width * 0.58),
            child: _Badge(
              padding: EdgeInsets.fromLTRB(
                cq.cmin(3, 1, 6),
                cq.cmin(3, 1, 6),
                cq.cmin(4, 1.2, 8),
                cq.cmin(3, 1, 6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 34,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF35E9FF),
                          Color(0xFF5A72FF),
                          Color(0xFFB344FF),
                        ],
                        stops: [0, 0.6, 1],
                      ),
                    ),
                    child: Text(
                      areaNumber,
                      style: display(
                        size: cq.cmin(10, 2.5, 13),
                        color: hex('#FFF5AA'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      state.areaName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(
                        size: cq.cmin(11, 3, 16),
                        color: hex('#F7FBFF'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        _Badge(
          padding: EdgeInsets.symmetric(
            horizontal: cq.cw(8, 2, 12),
            vertical: cq.cmin(6, 1.6, 9),
          ),
          child: Text(
            '✦ ${formatId(state.score)}',
            style: display(size: cq.cw(12, 3.1, 17), color: hex('#FFE36F')),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.state,
    required this.library,
    required this.cq,
  });

  final HudState state;
  final AssetLibrary library;
  final Cq cq;

  @override
  Widget build(BuildContext context) {
    final pipSize = cq.cw(18, 5, 27);
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: cq.cw(4, 1.2, 8),
            vertical: cq.cmin(3, 1, 6),
          ),
          decoration: BoxDecoration(
            color: rgba(17, 11, 53, .84),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: rgba(255, 110, 172, .62), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < state.maxHealth; index += 1)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: cq.cw(1, 0.8, 6) / 2,
                  ),
                  child: SpriteIcon(
                    library: library,
                    name: 'heart',
                    size: pipSize,
                    grayscale: index >= state.health,
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        _Badge(
          borderColor: rgba(134, 240, 255, .72),
          padding: EdgeInsets.symmetric(
            horizontal: cq.cw(8, 2.5, 13),
            vertical: cq.cmin(5, 1.5, 9),
          ),
          child: RichText(
            text: TextSpan(
              style: display(size: cq.cw(11, 2.9, 16), color: hex('#9FF7FF')),
              children: [
                const TextSpan(text: 'WAVE '),
                TextSpan(
                  text: '${state.wave}/${state.totalWaves}',
                  style: display(size: cq.cw(11, 2.9, 16), color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _Badge(
          padding: EdgeInsets.symmetric(
            horizontal: cq.cw(6, 1.6, 10),
            vertical: cq.cmin(3, 1, 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpriteIcon(
                library: library,
                name: 'coin',
                size: cq.cw(20, 5.4, 30),
              ),
              const SizedBox(width: 4),
              Text(
                '${state.coins}',
                style: display(size: cq.cw(12, 3, 16), color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BossBar extends StatelessWidget {
  const _BossBar({required this.name, required this.ratio, required this.cq});

  final String name;
  final double ratio;
  final Cq cq;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: min(cq.width * 0.76, 430)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            cq.cw(3, 0.8, 6),
            cq.cmin(3, 1, 5),
            cq.cw(3, 0.8, 6),
            cq.cmin(5, 1.7, 7),
          ),
          decoration: BoxDecoration(
            color: rgba(18, 7, 45, .9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: rgba(255, 205, 91, .75), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: display(size: cq.cw(10, 2.7, 14), color: hex('#FFE884')),
              ),
              SizedBox(height: cq.cmin(2, 0.5, 4)),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: cq.cw(7, 1.8, 11),
                  color: hex('#241949'),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            hex('#FF4F96'),
                            hex('#FF914D'),
                            hex('#FFE56F'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestureHint extends StatelessWidget {
  const _GestureHint({required this.cq});

  final Cq cq;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: cq.cw(8, 2, 12),
        vertical: cq.cmin(6, 1.5, 9),
      ),
      decoration: BoxDecoration(
        color: rgba(16, 10, 48, .72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: rgba(127, 239, 255, .55)),
      ),
      child: Text(
        'GUNAKAN JOYSTICK, TAHAN TEMBAK',
        style: body(size: cq.cw(10, 2.6, 13), color: hex('#C3FBFF')),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    this.icon,
    this.text,
    required this.diameter,
    required this.onPressed,
    this.enabled = true,
    this.badge,
  });

  final IconData? icon;
  final String? text;
  final double diameter;
  final VoidCallback onPressed;
  final bool enabled;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: rgba(17, 11, 53, .9),
        border: Border.all(color: rgba(134, 240, 255, .8), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF141033),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: icon != null
          ? Icon(icon, color: hex('#FFE36F'), size: diameter * 0.55)
          : Text(
              text ?? '',
              style: display(size: diameter * 0.5, color: hex('#FFE36F')),
            ),
    );
    final badgeCount = badge;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (enabled) tapped(onPressed);
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: badgeCount == null
            ? button
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  button,
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: hex('#FF4F96'),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: display(size: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Fire button: reports true while pressed, false when released.
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.label,
    required this.diameter,
    required this.onHold,
  });

  final String label;
  final double diameter;
  final ValueChanged<bool> onHold;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onHold(true),
      onPointerUp: (_) => onHold(false),
      onPointerCancel: (_) => onHold(false),
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: hex('#FFD9A0'), width: 3),
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            radius: 0.9,
            colors: [Color(0xFFFFB347), Color(0xFFE0502A), Color(0xFF4A1A12)],
            stops: [0, 0.55, 0.57],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF2A0E0A),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: display(size: diameter * 0.17, color: Colors.white),
        ),
      ),
    );
  }
}

/// Virtual joystick. Reports -1..1 on the horizontal axis (0 in the dead zone).
class Joystick extends StatefulWidget {
  const Joystick({super.key, required this.size, required this.onChanged});

  final double size;
  final ValueChanged<double> onChanged;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;
  int? _pointer;

  double get _travel => widget.size * 0.3;

  void _update(Offset local) {
    final centre = Offset(widget.size / 2, widget.size / 2);
    var offset = local - centre;
    final length = offset.distance;
    if (length > _travel) offset = offset / length * _travel;
    setState(() => _knob = offset);
    final axis = (offset.dx / _travel).clamp(-1.0, 1.0).toDouble();
    widget.onChanged(axis.abs() < 0.15 ? 0 : axis);
  }

  void _release() {
    _pointer = null;
    setState(() => _knob = Offset.zero);
    widget.onChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointer = event.pointer;
        _update(event.localPosition);
      },
      onPointerMove: (event) {
        if (event.pointer == _pointer) _update(event.localPosition);
      },
      onPointerUp: (event) {
        if (event.pointer == _pointer) _release();
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointer) _release();
      },
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _JoystickPainter(knob: _knob, travel: _travel),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({required this.knob, required this.travel});

  final Offset knob;
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(centre, radius, Paint()..color = rgba(17, 11, 53, .55));
    canvas.drawCircle(
      centre,
      radius - 1.5,
      Paint()
        ..color = rgba(143, 246, 255, .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      centre,
      travel,
      Paint()
        ..color = rgba(143, 246, 255, .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final knobCentre = centre + knob;
    final knobRadius = size.width * 0.2;
    canvas.drawCircle(
      knobCentre,
      knobRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [hex('#7BF6FF'), hex('#5B4CDD'), hex('#25194E')],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: knobCentre, radius: knobRadius)),
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.knob != knob || oldDelegate.travel != travel;
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: rgba(17, 11, 53, .84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor ?? rgba(134, 240, 255, .72),
          width: 2,
        ),
      ),
      child: child,
    );
  }
}

class _SkillButton extends StatelessWidget {
  const _SkillButton({
    required this.label,
    required this.sub,
    required this.diameter,
    required this.enabled,
    required this.onPressed,
    required this.colors,
    required this.border,
  });

  final String label;
  final String sub;
  final double diameter;
  final bool enabled;
  final VoidCallback onPressed;
  final List<Color> colors;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return _CircleControl(
      diameter: diameter,
      enabled: enabled,
      onPressed: onPressed,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 0.9,
          colors: colors,
          stops: const [0, 0.55, 0.57],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF141033),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: _ControlLabel(
        label: label,
        sub: sub,
        labelSize: max(11, diameter * 0.22),
        subSize: max(7, diameter * 0.15),
      ),
    );
  }
}

class _UltimateButton extends StatelessWidget {
  const _UltimateButton({
    required this.charge,
    required this.diameter,
    required this.enabled,
    required this.percentLabel,
    required this.onPressed,
  });

  final double charge;
  final double diameter;
  final bool enabled;
  final String percentLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CircleControl(
      diameter: diameter,
      enabled: enabled,
      onPressed: onPressed,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: hex('#FFE873'), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF141033),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      painter: _ChargeRingPainter(charge.clamp(0, 100) / 100),
      child: _ControlLabel(
        label: 'ULT',
        sub: percentLabel,
        labelSize: max(11, diameter * 0.2),
        subSize: max(7, diameter * 0.14),
      ),
    );
  }
}

/// `conic-gradient(#ffe873 var(--charge), #32244f 0)` plus the inset ring.
class _ChargeRingPainter extends CustomPainter {
  _ChargeRingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect, Paint()..color = hex('#32244F'));
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * fraction,
      true,
      Paint()..color = hex('#FFE873'),
    );
    canvas.drawOval(
      rect.deflate(2.5),
      Paint()
        ..color = hex('#6442B0')
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant _ChargeRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.diameter,
    required this.enabled,
    required this.onPressed,
    required this.decoration,
    required this.child,
    this.painter,
  });

  final double diameter;
  final bool enabled;
  final VoidCallback onPressed;
  final BoxDecoration decoration;
  final Widget child;
  final CustomPainter? painter;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: diameter,
      height: diameter,
      decoration: painter == null
          ? decoration
          : decoration.copyWith(color: null),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (painter != null)
            Positioned.fill(child: CustomPaint(painter: painter)),
          child,
        ],
      ),
    );
    final control = Opacity(opacity: enabled ? 1 : 0.58, child: body);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (enabled) onPressed();
      },
      child: control,
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({
    required this.label,
    required this.sub,
    required this.labelSize,
    required this.subSize,
  });

  final String label;
  final String sub;
  final double labelSize;
  final double subSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: display(size: labelSize, color: Colors.white),
        ),
        Text(
          sub,
          style: body(size: subSize, color: Colors.white),
        ),
      ],
    );
  }
}

class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.diameter, required this.onPressed});

  final double diameter;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPressed(),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: hex('#91F8FF'), width: 3),
          gradient: const RadialGradient(
            center: Alignment(-0.24, -0.4),
            radius: 0.9,
            colors: [Color(0xFF5CF6FF), Color(0xFF5367E8), Color(0xFF34205F)],
            stops: [0, 0.52, 0.54],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF161139),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '↑',
              style: TextStyle(
                fontSize: diameter * 0.26,
                height: 0.8,
                color: Colors.white,
              ),
            ),
            Text(
              'LOMPAT',
              style: display(size: diameter * 0.12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
