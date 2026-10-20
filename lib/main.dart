// Skyfall Bowguard — Flutter + Flame port of the web game in "game js".
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/skyfall_game.dart';
import 'game/world.dart';
import 'ui/game_ui.dart';
import 'ui/hud.dart';
import 'ui/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SkyfallApp());
}

class SkyfallApp extends StatelessWidget {
  const SkyfallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skyward Magic Arrow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: kBodyColor),
      home: const SkyfallScreen(),
    );
  }
}

class SkyfallScreen extends StatefulWidget {
  const SkyfallScreen({super.key});

  @override
  State<SkyfallScreen> createState() => _SkyfallScreenState();
}

class _SkyfallScreenState extends State<SkyfallScreen>
    with WidgetsBindingObserver {
  final GameUi _ui = GameUi();
  late final SkyfallGame _game = SkyfallGame(ui: _ui);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ui.overlay.addListener(_restoreGameFocus);
  }

  void _restoreGameFocus() {
    if (_ui.overlay.value != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ui.overlay.value == null) _focus.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save whenever the app leaves the foreground, so progress survives a kill.
    if (state != AppLifecycleState.resumed) _game.saveNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ui.overlay.removeListener(_restoreGameFocus);
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      _game.keyUp(event.logicalKey);
      return KeyEventResult.ignored;
    }
    final handled = _game.keyDown(
      event.logicalKey,
      repeat: event is KeyRepeatEvent,
    );
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold gives the overlays a Material ancestor (no stray text underlines).
    return Scaffold(
      backgroundColor: kBodyColor,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        // Sees every tap, even those the overlays absorb, to unlock audio.
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _game.unlockAudio(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The canvas fills the whole screen; pointer input is read here.
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  _focus.requestFocus();
                  _game.pointerDown(event.pointer, event.localPosition);
                },
                onPointerMove: (event) =>
                    _game.pointerMove(event.pointer, event.localPosition),
                onPointerUp: (event) => _game.pointerUp(event.pointer),
                onPointerCancel: (event) => _game.pointerUp(event.pointer),
                child: GameWidget(game: _game),
              ),
              // HUD, controls and overlays stay inside the phone's safe area (notch, gesture bar).
              SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ValueListenableBuilder<HudState?>(
                      valueListenable: _ui.hud,
                      builder: (context, hud, _) {
                        if (hud == null) return const SizedBox.shrink();
                        return ValueListenableBuilder<bool>(
                          valueListenable: _ui.hintVisible,
                          builder: (context, hintVisible, _) => Hud(
                            state: hud,
                            library: _game.library,
                            hintVisible: hintVisible,
                            volume: _game.saved.volume,
                            onJump: _game.touchJump,
                            onSkill: _game.touchSkill,
                            onVolume: _game.cycleVolume,
                            onHelp: _game.openHelp,
                            onMenu: _game.openMenu,
                            onJoystick: _game.setJoystick,
                            onFire: _game.setFire,
                            onUpgrade: _game.openUpgradeMenu,
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<Widget?>(
                      valueListenable: _ui.overlay,
                      builder: (context, overlay, _) =>
                          overlay ?? const SizedBox.shrink(),
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
