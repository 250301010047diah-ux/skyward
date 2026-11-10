// Overlay cards (start, selection, upgrade,
// relic, game over, victory, loading and load error), styled from styles.css.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/assets.dart';
import '../game/data.dart';
import '../game/renderer.dart';
import '../game/world.dart';
import 'game_ui.dart';
import 'style.dart';

/// `.overlay`: full-screen scrim that blocks taps from reaching the canvas.
class OverlayScreen extends StatelessWidget {
  const OverlayScreen({super.key, required this.card, this.wide = false});

  final Widget card;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cq = Cq.of(constraints);
        final padding = cq.cmin(14, 4, 28);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: rgba(8, 5, 29, .62),
              padding: EdgeInsets.all(padding),
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide
                      ? min(cq.width * 0.96, 620)
                      : min(cq.width * 0.92, 470),
                  maxHeight: constraints.maxHeight * (wide ? 0.92 : 0.86),
                ),
                child: SingleChildScrollView(
                  child: _Card(cq: cq, child: card),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.cq, required this.child});

  final Cq cq;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = cq.cmin(16, 5, 28);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cq.cmin(16, 5, 28)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: hex('#6EEEFF'), width: 3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rgba(36, 22, 92, .98), rgba(19, 13, 57, .98)],
        ),
        boxShadow: [
          BoxShadow(
            color: rgba(8, 4, 31, .8),
            offset: const Offset(0, 8),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.text,
    required this.cq,
    this.children = const [],
  });

  final String title;
  final String text;
  final Cq cq;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            textAlign: TextAlign.center,
            style: display(
              size: cq.cmin(8.5, 2.6, 26),
              color: hex('#FFF3A0'),
              height: 1.08,
            ),
          ),
          SizedBox(height: cq.cmin(9, 2.5, 16)),
        ],
        if (text.isNotEmpty) ...[
          Text(
            text,
            textAlign: TextAlign.center,
            style: body(
              size: cq.cw(13, 3.7, 18),
              color: hex('#CCEFFF'),
              weight: FontWeight.w800,
            ),
          ),
          SizedBox(height: cq.cmin(9, 2.5, 16)),
        ],
        ...children,
      ],
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => tapped(onPressed),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: primary ? hex('#FFF09A') : hex('#8EEFFF'),
                width: 2,
              ),
              color: primary ? null : hex('#31275F'),
              gradient: primary
                  ? LinearGradient(
                      colors: [hex('#4A4CE0'), hex('#8D39D8')],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              boxShadow: primary
                  ? const [
                      BoxShadow(
                        color: Color(0xFF19103D),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: display(size: 15, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `.loading-gem`: a spinning ring under the loading text.
class _Gem extends StatefulWidget {
  const _Gem();

  @override
  State<_Gem> createState() => _GemState();
}

class _GemState extends State<_Gem> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: CustomPaint(size: const Size.square(52), painter: _GemPainter()),
    );
  }
}

class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2.5);
    canvas.drawArc(
      rect,
      0,
      6.2831853,
      false,
      Paint()
        ..color = rgba(115, 236, 255, .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      rect,
      -1.5708,
      1.5708,
      false,
      Paint()
        ..color = hex('#72EFFF')
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      rect,
      0,
      1.5708,
      false,
      Paint()
        ..color = hex('#FFF080')
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget loadingOverlay(String text) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Gem(),
          SizedBox(height: cq.cmin(9, 2.5, 16)),
          Text(
            text,
            textAlign: TextAlign.center,
            style: body(
              size: cq.cw(13, 3.7, 18),
              color: hex('#CCEFFF'),
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  },
);

Widget loadErrorOverlay(VoidCallback onRetry) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: _Panel(
        title: 'ARENA BELUM TERBUKA',
        text: 'Aset area tidak berhasil dimuat. Coba sekali lagi.',
        cq: cq,
        children: [_PanelButton(label: 'COBA MUAT ULANG', onPressed: onRetry)],
      ),
    );
  },
);

Widget startOverlay({
  required AreaData area,
  required int areaIndex,
  required SkinData skin,
  required VoidCallback onStart,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: _Panel(
        title: 'AREA ${areaIndex + 1}',
        text: '${area.subtitle} · ${area.name}',
        cq: cq,
        children: [
          Text(
            '${skin.name} · ${skin.skill1} · ${skin.skill2} · ${skin.ultimate}',
            textAlign: TextAlign.center,
            style: body(size: cq.cw(12, 3.3, 16), color: hex('#D9D2FF')),
          ),
          _PanelButton(label: 'MULAI BERTAHAN', onPressed: onStart),
        ],
      ),
    );
  },
);

Widget areaSelectOverlay({
  required AssetLibrary library,
  required int selected,
  required int unlockedArea,
  required void Function(int index) onPick,
  required VoidCallback onBack,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      wide: true,
      card: _Panel(
        title: 'PILIH AREA',
        text: 'Selesaikan area untuk membuka area berikutnya.',
        cq: cq,
        children: [
          _Grid(
            columns: 2,
            gap: cq.cw(8, 2, 12),
            children: [
              for (var index = 0; index < kAreas.length; index++)
                Opacity(
                  opacity: index <= unlockedArea ? 1 : 0.45,
                  child: _SelectButton(
                    selected: index == selected,
                    onPressed: () {
                      if (index <= unlockedArea) onPick(index);
                    },
                    cq: cq,
                    leading: _AreaThumb(
                      library: library,
                      index: index,
                      width: cq.cw(64, 17, 84),
                    ),
                    title:
                        '${index <= unlockedArea ? '' : '🔒 '}${(index + 1).toString().padLeft(2, '0')} · ${kAreas[index].name}',
                    subtitle: index <= unlockedArea
                        ? kAreas[index].subtitle
                        : 'TERKUNCI',
                  ),
                ),
            ],
          ),
          _PanelButton(
            label: 'KEMBALI KE MENU',
            onPressed: onBack,
            primary: false,
          ),
        ],
      ),
    );
  },
);

/// Small picture of an area's background, so the theme can be seen before picking.
class _AreaThumb extends StatelessWidget {
  const _AreaThumb({
    required this.library,
    required this.index,
    required this.width,
  });

  final AssetLibrary library;
  final int index;
  final double width;

  @override
  Widget build(BuildContext context) {
    final path = library.imagePath(kAreas[index].bgKey);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: width * 0.62,
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          cacheWidth: 240,
          errorBuilder: (context, error, stack) =>
              ColoredBox(color: rgba(22, 13, 53)),
        ),
      ),
    );
  }
}

Widget skinSelectOverlay({
  required AssetLibrary library,
  required int selected,
  required String Function() gold,
  required bool Function(int index) owns,
  required bool Function(int index) onBuy,
  required void Function(int index) onPick,
  required VoidCallback onBack,
}) => LayoutBuilder(
  builder: (context, constraints) => OverlayScreen(
    wide: true,
    card: _SkinSelect(
      library: library,
      initial: selected,
      gold: gold,
      owns: owns,
      onBuy: onBuy,
      cq: Cq.of(constraints),
      onPick: onPick,
      onBack: onBack,
    ),
  ),
);

/// Tapping a skin only highlights it and shows it large; PILIH confirms.
class _SkinSelect extends StatefulWidget {
  const _SkinSelect({
    required this.library,
    required this.initial,
    required this.cq,
    required this.onPick,
    required this.onBack,
    required this.gold,
    required this.owns,
    required this.onBuy,
  });

  final String Function() gold;
  final bool Function(int index) owns;
  final bool Function(int index) onBuy;
  final AssetLibrary library;
  final int initial;
  final Cq cq;
  final void Function(int index) onPick;
  final VoidCallback onBack;

  @override
  State<_SkinSelect> createState() => _SkinSelectState();
}

class _SkinSelectState extends State<_SkinSelect> {
  late int _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final cq = widget.cq;
    final library = widget.library;
    final skin = kSkins[_selected];
    final owns = widget.owns;
    final owned = owns(_selected);
    final price = skinPrice(_selected);
    return _Panel(
      title: 'PILIH SKY ELF',
      text: 'Emas: ${widget.gold()} · Skin terkunci dibeli pakai emas.',
      cq: cq,
      children: [
        // Large preview of the highlighted skin.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkinPreview(library: library, skin: skin, size: cq.cw(96, 26, 130)),
            SizedBox(width: cq.cw(8, 2.5, 14)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    skin.name,
                    style: display(
                      size: cq.cw(12, 3.4, 17),
                      color: hex('#FFE77A'),
                    ),
                  ),
                  Text(
                    '${skin.skill1} · ${skin.skill2}',
                    style: body(
                      size: cq.cw(10, 2.6, 13),
                      color: hex('#B9DDFF'),
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Ultimate: ${skin.ultimate}',
                    style: body(
                      size: cq.cw(10, 2.6, 13),
                      color: hex('#B9DDFF'),
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _Grid(
          columns: 2,
          gap: cq.cw(8, 2, 12),
          children: [
            for (
              var position = 0;
              position < kSelectableSkins.length;
              position++
            )
              _SelectButton(
                selected: kSelectableSkins[position].index == _selected,
                onPressed: () => setState(
                  () => _selected = kSelectableSkins[position].index,
                ),
                cq: cq,
                leading: SkinPreview(
                  library: library,
                  skin: kSelectableSkins[position],
                  size: cq.cw(38, 9, 48),
                ),
                title:
                    '${owns(kSelectableSkins[position].index) ? '' : '🔒 '}${(position + 1).toString().padLeft(2, '0')} · ${kSelectableSkins[position].name}',
                subtitle: owns(kSelectableSkins[position].index)
                    ? kSelectableSkins[position].skill1
                    : 'Harga ${skinPrice(kSelectableSkins[position].index)} emas',
                extra:
                    'Power ×${kSelectableSkins[position].power.toStringAsFixed(2)}',
              ),
          ],
        ),
        _PanelButton(
          label: owned
              ? 'PILIH ${skin.name.toUpperCase()}'
              : 'BELI $price EMAS',
          onPressed: () {
            if (owned) {
              widget.onPick(_selected);
            } else if (widget.onBuy(_selected)) {
              setState(() {});
            } else {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Emas tidak cukup')),
              );
            }
          },
        ),
        _PanelButton(
          label: 'KEMBALI KE AREA',
          onPressed: widget.onBack,
          primary: false,
        ),
      ],
    );
  }
}

/// Draws the skin's idle sprite on a glow of its colour; a plain orb if the sprite is missing.
class SkinPreview extends StatelessWidget {
  const SkinPreview({
    super.key,
    required this.library,
    required this.skin,
    required this.size,
  });

  final AssetLibrary library;
  final SkinData skin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SkinPainter(library, skin),
    );
  }
}

class _SkinPainter extends CustomPainter {
  // Repaints when a sheet finishes loading, so previews fill in.
  _SkinPainter(this.library, this.skin) : super(repaint: library);

  final AssetLibrary library;
  final SkinData skin;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final color = hex(skin.color);
    canvas.drawCircle(
      centre,
      size.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .45), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centre, radius: size.width / 2)),
    );
    final sheet = library.get(skin.coreKey);
    final frames = library.animation(skin.coreKey, 'idle');
    if (sheet != null && frames.isNotEmpty) {
      ArenaRenderer.paintIconFrame(canvas, sheet.image, frames.first, size);
      return;
    }
    canvas.drawCircle(
      centre,
      size.width * 0.3,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.3, -0.4),
              colors: [Colors.white, color, rgba(39, 19, 64)],
              stops: const [0, 0.42, 0.72],
            ).createShader(
              Rect.fromCircle(center: centre, radius: size.width * 0.3),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant _SkinPainter oldDelegate) =>
      oldDelegate.skin != skin;
}

Widget upgradeOverlay({
  required AssetLibrary library,
  required void Function(String key) onPick,
  VoidCallback? onBack,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: _Panel(
        title: 'PILIH PENINGKATAN',
        text: onBack == null
            ? 'Emas gelombang ini memperkuatmu sampai boss tumbang.'
            : 'Pakai token dari wave yang selesai. Peningkatan bersifat permanen.',
        cq: cq,
        children: [
          _Grid(
            columns: 3,
            gap: cq.cw(8, 2.4, 14),
            children: [
              for (final entry in kUpgradeCopy.entries)
                _UpgradeButton(
                  cq: cq,
                  icon: entry.value[2],
                  library: library,
                  title: entry.value[0],
                  description: entry.value[1],
                  onPressed: () => onPick(entry.key),
                ),
            ],
          ),
          if (onBack != null)
            _PanelButton(label: 'TUTUP', onPressed: onBack, primary: false),
        ],
      ),
    );
  },
);

Widget relicOverlay({
  required AssetLibrary library,
  required AreaData area,
  required AreaData? next,
  required VoidCallback onContinue,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: _Panel(
        title: 'RELIK DIDAPAT',
        text: area.relic[0],
        cq: cq,
        children: [
          FloatingIcon(
            child: SpriteIcon(
              library: library,
              name: area.relic[1],
              size: cq.cw(84, 25, 140),
            ),
          ),
          Text(
            area.relic[2],
            textAlign: TextAlign.center,
            style: body(size: cq.cw(12, 3.3, 16), color: hex('#D9D2FF')),
          ),
          _PanelButton(
            label: next != null ? 'LANJUT KE ${next.name}' : 'LIHAT KEMENANGAN',
            onPressed: onContinue,
          ),
        ],
      ),
    );
  },
);

Widget gameOverOverlay({
  required HudState state,
  required double bestScore,
  required VoidCallback onRetry,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: _Panel(
        title: 'PERTAHANAN RUNTUH',
        text: 'Berhenti di Area ${state.areaIndex + 1}, Wave ${state.wave}.',
        cq: cq,
        children: [
          _ResultScore(
            label: 'SKOR',
            value: formatId(state.score),
            footer: 'Terbaik ${formatId(bestScore)}',
            cq: cq,
          ),
          _PanelButton(label: 'COBA WAVE INI LAGI', onPressed: onRetry),
        ],
      ),
    );
  },
);

Widget victoryOverlay({
  required AssetLibrary library,
  required double score,
  required VoidCallback onReplay,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: _Panel(
        title: 'REALITAS DISELAMATKAN',
        text: 'Tiga puluh arena telah tunduk pada Sky Elf.',
        cq: cq,
        children: [
          FloatingIcon(
            child: SpriteIcon(
              library: library,
              name: 'dawn_bow',
              size: cq.cw(84, 25, 140),
            ),
          ),
          _ResultScore(label: 'SKOR KAMPANYE', value: formatId(score), cq: cq),
          _PanelButton(label: 'MAIN LAGI DARI AREA 1', onPressed: onReplay),
        ],
      ),
    );
  },
);

class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final rowChildren = <Widget>[];
      for (var col = 0; col < columns; col++) {
        final index = start + col;
        rowChildren.add(
          Expanded(
            child: index < children.length ? children[index] : const SizedBox(),
          ),
        );
        if (col < columns - 1) rowChildren.add(SizedBox(width: gap));
      }
      // IntrinsicHeight gives the stretched row a bounded height.
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );
      if (start + columns < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({
    required this.selected,
    required this.onPressed,
    required this.cq,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.extra,
  });

  final bool selected;
  final VoidCallback onPressed;
  final Cq cq;
  final Widget leading;
  final String title;
  final String subtitle;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => tapped(onPressed),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? hex('#FFE77A') : hex('#605AB2'),
              width: 2,
            ),
            color: selected ? rgba(81, 54, 157, .96) : rgba(49, 35, 101, .88),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(size: cq.cw(11, 3, 15), color: Colors.white),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(
                        size: cq.cw(9, 2.3, 12),
                        color: hex('#B9DDFF'),
                        weight: FontWeight.w700,
                      ),
                    ),
                    if (extra != null)
                      Text(
                        extra!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(
                          size: cq.cw(9, 2.3, 12),
                          color: hex('#B9DDFF'),
                          weight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    required this.cq,
    required this.icon,
    required this.library,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final Cq cq;
  final String icon;
  final AssetLibrary library;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => tapped(onPressed),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: EdgeInsets.all(cq.cw(7, 2, 12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hex('#706CF0'), width: 2),
            color: rgba(68, 44, 133, .78),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SpriteIcon(library: library, name: icon, size: cq.cw(42, 13, 68)),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: display(size: cq.cw(10, 2.7, 14), color: hex('#FFF2A1')),
              ),
              Text(
                description,
                textAlign: TextAlign.center,
                style: body(
                  size: cq.cw(10, 2.5, 13),
                  color: hex('#C8EDFF'),
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultScore extends StatelessWidget {
  const _ResultScore({
    required this.label,
    required this.value,
    required this.cq,
    this.footer,
  });

  final String label;
  final String value;
  final String? footer;
  final Cq cq;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: display(size: 14, color: hex('#8EEFFF'))),
        Text(
          value,
          style: display(size: cq.cmin(11, 3.6, 36), color: hex('#FFE86D')),
        ),
        if (footer != null)
          Text(
            footer!,
            style: body(size: cq.cw(12, 3.2, 15), color: hex('#C9C3FF')),
          ),
      ],
    );
  }
}

/// Full-screen main menu drawn over the saved area's background.
class MainMenu extends StatelessWidget {
  const MainMenu({
    super.key,
    required this.background,
    required this.progress,
    required this.volumeLabel,
    this.resumable = false,
    required this.onPlay,
    required this.onSelect,
    required this.onTutorial,
    required this.onVolume,
    required this.onReset,
    this.cheatActive = false,
    this.onCheat,
  });

  final bool cheatActive;
  final VoidCallback? onCheat;

  final ui.Image? background;
  final String progress;
  final String volumeLabel;
  final bool resumable;
  final VoidCallback onPlay;
  final VoidCallback onSelect;
  final VoidCallback onTutorial;
  final VoidCallback onVolume;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cq = Cq.of(constraints);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (background != null)
              CustomPaint(painter: _CoverPainter(background!)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    rgba(18, 5, 50, .72),
                    rgba(8, 6, 26, .35),
                    rgba(8, 6, 26, .9),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(cq.cmin(16, 4, 28)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: min(cq.width * 0.9, 420),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SKYWARD',
                        textAlign: TextAlign.center,
                        style: display(
                          size: cq.cmin(12, 11, 48),
                          color: hex('#FFF3A0'),
                          height: 1,
                        ),
                      ),
                      Text(
                        'MAGIC ARROW',
                        textAlign: TextAlign.center,
                        style: display(
                          size: cq.cmin(5, 4.4, 20),
                          color: hex('#8FF7FF'),
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: cq.cmin(6, 2, 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: rgba(17, 11, 53, .84),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: rgba(134, 240, 255, .6),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          progress,
                          style: body(
                            size: cq.cw(11, 3, 14),
                            color: hex('#C9C3FF'),
                          ),
                        ),
                      ),
                      SizedBox(height: cq.cmin(14, 4, 26)),
                      _MenuButton(
                        label: resumable ? 'LANJUTKAN' : 'MAIN',
                        onPressed: onPlay,
                        primary: true,
                      ),
                      _MenuButton(
                        label: 'PILIH AREA & SKY ELF',
                        onPressed: onSelect,
                      ),
                      _MenuButton(label: 'TUTORIAL', onPressed: onTutorial),
                      _MenuButton(label: volumeLabel, onPressed: onVolume),
                      if (onCheat != null)
                        _MenuButton(
                          label: cheatActive
                              ? 'EMAS 999++ AKTIF'
                              : 'EMAS 999++ & BUKA SEMUA',
                          onPressed: onCheat!,
                        ),
                      _MenuButton(
                        label: 'RESET PROGRES',
                        onPressed: onReset,
                        danger: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final border = primary
        ? hex('#FFF09A')
        : danger
        ? hex('#FF7A7A')
        : hex('#8EEFFF');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => tapped(onPressed),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border, width: 2),
              color: primary
                  ? null
                  : (danger ? rgba(70, 18, 36, .9) : rgba(49, 39, 95, .92)),
              gradient: primary
                  ? const LinearGradient(
                      colors: [Color(0xFF4A4CE0), Color(0xFF8D39D8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              boxShadow: primary
                  ? const [
                      BoxShadow(
                        color: Color(0xFF19103D),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: display(size: 15, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = max(size.width / image.width, size.height / image.height);
    final w = image.width * scale;
    final h = image.height * scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _CoverPainter oldDelegate) =>
      oldDelegate.image != image;
}

/// Confirmation card (used for reset progress).
Widget confirmOverlay({
  required String title,
  required String text,
  required String yesLabel,
  required VoidCallback onYes,
  required VoidCallback onNo,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final cq = Cq.of(constraints);
    return OverlayScreen(
      card: _Panel(
        title: title,
        text: text,
        cq: cq,
        children: [
          _PanelButton(label: yesLabel, onPressed: onYes),
          _PanelButton(label: 'BATAL', onPressed: onNo, primary: false),
        ],
      ),
    );
  },
);

/// Tutorial pages. Shown before every new run and from help; can be skipped.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  static const pages = <(String, String)>[
    ('JOYSTICK', 'Gerakkan Sky Elf dengan joystick di kiri bawah.'),
    (
      'TEMBAK',
      'Panah hanya keluar saat tombol TEMBAK ditahan, dan otomatis mengarah ke musuh terdekat.',
    ),
    (
      'LOMPAT & SKILL',
      'LOMPAT menghindari serangan darat dan proyektil. S1 dan S2 punya cooldown; ULT terisi dari musuh yang kalah.',
    ),
    (
      'UPGRADE & WAVE',
      'Setiap wave yang selesai memberi 1 token. Tekan tombol UPGRADE untuk membeli peningkatan. Kalahkan boss untuk mendapat relik.',
    ),
  ];

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pages = TutorialOverlay.pages;
    final last = _page == pages.length - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cq = Cq.of(constraints);
        final page = pages[_page];
        return OverlayScreen(
          card: _Panel(
            title: page.$1,
            text: page.$2,
            cq: cq,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? hex('#FFE77A')
                            : rgba(255, 255, 255, .25),
                      ),
                    ),
                ],
              ),
              _PanelButton(
                label: last ? 'MULAI' : 'LANJUT',
                onPressed: () {
                  if (last) {
                    widget.onDone();
                  } else {
                    setState(() => _page += 1);
                  }
                },
              ),
              _PanelButton(
                label: 'LEWATI',
                onPressed: widget.onDone,
                primary: false,
              ),
            ],
          ),
        );
      },
    );
  }
}
