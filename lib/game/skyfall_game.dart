// Port of game js/game/game.js (flow, save, input) on top of a Flame game.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/game_ui.dart';
import '../ui/overlays.dart';
import '../ui/style.dart';
import 'assets.dart';
import 'audio.dart';
import 'data.dart';
import 'renderer.dart';
import 'world.dart';

const int _saveVersion = 3;
const String _saveKey = 'skyfall.save';

/// Master volume steps for the volume button: 100%, 50%, 0%.
const List<double> kVolumeLevels = [1.0, 0.5, 0.0];

/// Web `safeSavedState`: the same clamps, including `unlockedArea` always 29.
class SaveData {
  SaveData({
    required this.currentArea,
    required this.unlockedArea,
    required this.skinIndex,
    required this.relics,
    required this.bestScore,
    this.volume = 1,
  });

  factory SaveData.defaults() => SaveData(
    currentArea: 0,
    unlockedArea: 29,
    skinIndex: 0,
    relics: [],
    bestScore: 0,
  );

  factory SaveData.fromJson(Map<String, dynamic>? value) {
    if (value == null) return SaveData.defaults();
    num numberOr0(Object? raw) => raw is num && raw.isFinite ? raw : 0;
    final rawVolume = value['volume'];
    return SaveData(
      currentArea: numberOr0(value['currentArea']).clamp(0, 29).toInt(),
      unlockedArea: 29,
      skinIndex: selectableSkinIndex(
        numberOr0(value['skinIndex']).clamp(0, 19).toInt(),
      ),
      relics: value['relics'] is List
          ? [
              for (final entry in value['relics'] as List)
                if (entry is String) entry,
            ]
          : <String>[],
      bestScore: numberOr0(
        value['bestScore'],
      ).clamp(0, double.infinity).toDouble(),
      volume: rawVolume is num && rawVolume.isFinite
          ? rawVolume.toDouble().clamp(0.0, 1.0)
          : 1,
    );
  }

  int currentArea;
  int unlockedArea;
  int skinIndex;
  List<String> relics;
  double bestScore;
  double volume;

  Map<String, dynamic> toJson() => {
    'version': _saveVersion,
    'currentArea': currentArea,
    'unlockedArea': unlockedArea,
    'skinIndex': skinIndex,
    'relics': relics,
    'bestScore': bestScore,
    'volume': volume,
  };
}

class SkyfallGame extends FlameGame implements MovementSource {
  SkyfallGame({required this.ui});

  final GameUi ui;
  final AssetLibrary library = AssetLibrary();
  late final ArenaRenderer renderer = ArenaRenderer(library);
  final GameAudio audio = GameAudio();
  final Tuning tuning = const Tuning();

  SaveData saved = SaveData.defaults();
  GameWorld? arena;
  SharedPreferences? _prefs;
  Size _viewport = Size.zero;
  double _joyAxis = 0;
  bool _touchFire = false;
  final Set<LogicalKeyboardKey> _keys = {};
  final Random _random = Random();
  bool _tutorialOpen = false;
  bool _pausedByUi = false;
  bool _victoryShown = false;
  bool _menuResumable = false;
  double _saveTimer = 0;

  static final Set<LogicalKeyboardKey> _gameKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.keyR,
    LogicalKeyboardKey.keyF,
  };

  @override
  Color backgroundColor() => kShellColor;

  @override
  Future<void> onLoad() async {
    // Boot runs in the background; Flame keeps drawing while assets load.
    _boot();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _viewport = Size(size.x, size.y);
    arena?.resize(size.x, size.y);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final current = arena;
    if (current == null) return;
    // The tutorial pauses the run while it is open.
    _syncBgm();
    if (!_tutorialOpen && !_pausedByUi) current.update(dt);
    ui.hud.value = current.snapshot();
    // Auto-save every couple of seconds while a run is going.
    _saveTimer += dt;
    if (_saveTimer >= 2) {
      _saveTimer = 0;
      if (current.started) _saveProgress();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final current = arena;
    if (current == null) return;
    renderer.draw(canvas, current);
  }

  // ---- Input (MovementSource, plus the handlers called by the Flutter layer) ----

  @override
  MoveIntent movement() {
    final left =
        _keys.contains(LogicalKeyboardKey.arrowLeft) ||
        _keys.contains(LogicalKeyboardKey.keyA);
    final right =
        _keys.contains(LogicalKeyboardKey.arrowRight) ||
        _keys.contains(LogicalKeyboardKey.keyD);
    final fire = _touchFire || _keys.contains(LogicalKeyboardKey.keyF);
    if (left != right) return MoveIntent(left ? -1 : 1, null, fire: fire);
    return MoveIntent(_joyAxis, null, fire: fire);
  }

  /// Joystick from the HUD: -1 (left) .. 1 (right), 0 when released.
  void setJoystick(double axis) {
    _joyAxis = axis;
  }

  /// Fire button from the HUD: shoots while held.
  void setFire(bool held) {
    _touchFire = held;
  }

  void pointerDown(int pointer, Offset local) {
    _engage();
  }

  void pointerMove(int pointer, Offset local) {}

  void pointerUp(int pointer) {}

  /// Returns true when the key is one the game uses (so the event is consumed).
  bool keyDown(LogicalKeyboardKey key, {required bool repeat}) {
    unlockAudio();
    if (!_gameKeys.contains(key)) return false;
    _engage();
    if (key == LogicalKeyboardKey.space && !repeat) jump();
    if (key == LogicalKeyboardKey.keyQ && !repeat) skill('skill1');
    if (key == LogicalKeyboardKey.keyE && !repeat) skill('skill2');
    if (key == LogicalKeyboardKey.keyR && !repeat) skill('ultimate');
    _keys.add(key);
    return true;
  }

  void keyUp(LogicalKeyboardKey key) => _keys.remove(key);

  void jump() => arena?.jump();

  void skill(String type) => arena?.useSkill(type);

  /// Touch controls: same as the web buttons, which engage before acting.
  void touchJump() {
    _engage();
    jump();
  }

  void touchSkill(String type) {
    _engage();
    skill(type);
  }

  void _engage() {
    ui.hideHint();
  }

  // ---- Settings and save ----

  String get volumeLabel => 'VOLUME ${(saved.volume * 100).round()}%';

  void cycleVolume() {
    final index = kVolumeLevels.indexWhere(
      (level) => (level - saved.volume).abs() < 0.001,
    );
    final next = kVolumeLevels[(index + 1) % kVolumeLevels.length];
    saved.volume = next;
    audio.setVolume(next);
    _saveProgress();
  }

  /// Called when the app is hidden or paused, so progress is never lost.
  void saveNow() {
    _saveProgress();
  }

  Future<SaveData> _loadSave() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_saveKey);
      return SaveData.fromJson(
        raw == null ? null : jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return SaveData.defaults();
    }
  }

  Future<void> _saveProgress() async {
    final current = arena;
    if (current == null) return;
    saved = SaveData(
      currentArea: current.areaIndex,
      unlockedArea: max(saved.unlockedArea, current.areaIndex),
      skinIndex: current.skinIndex,
      relics: current.relics.toList(),
      bestScore: max(saved.bestScore, max(current.bestScore, current.score)),
      volume: saved.volume,
    );
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_saveKey, jsonEncode(saved.toJson()));
    } catch (_) {
      // Saving is best-effort, as in the web build.
    }
  }

  // ---- Flow (web game.js) ----

  Future<void> _boot() async {
    // Wait until the first frame is built; overlays cannot change during build.
    await Future<void>.delayed(Duration.zero);
    _showLoading();
    try {
      final results = await Future.wait<Object?>([
        _loadSave(),
        library.loadCore(),
      ]);
      saved = results[0] as SaveData;
      await audio.setVolume(saved.volume);
      await library.loadArea(saved.currentArea);
      await library.loadSkin(saved.skinIndex);
      _wireWorld();
      _showMenu();
    } catch (_) {
      ui.overlay.value = loadErrorOverlay(() => _boot());
    }
  }

  void _wireWorld() {
    UiSound.click = () => audio.play('click');
    final created = GameWorld(
      areaIndex: saved.currentArea,
      skinIndex: saved.skinIndex,
      relics: saved.relics,
      tuning: tuning,
      audio: audio,
      random: _random,
      callbacks: WorldCallbacks(
        onHit: () => HapticFeedback.mediumImpact(),
        onUltimate: () => HapticFeedback.heavyImpact(),
        onUpgrade: () {
          ui.overlay.value = upgradeOverlay(
            library: library,
            onPick: (key) {
              _engage();
              _hideOverlay();
              arena?.chooseUpgrade(key);
            },
          );
        },
        onAreaComplete: (state) {
          saved.unlockedArea = max(
            saved.unlockedArea,
            min(29, state.areaIndex + 1),
          );
          saved.relics = arena!.relics.toList();
          saved.bestScore = max(saved.bestScore, state.score);
          _saveProgress();
          audio.play('area_clear');
          Future<void>.delayed(
            const Duration(milliseconds: 700),
            () => audio.play('relic'),
          );
          if (state.areaIndex == kAreas.length - 1) {
            _victoryShown = true;
            audio.play('victory');
            ui.overlay.value = victoryOverlay(
              library: library,
              score: state.score,
              onReplay: () {
                _engage();
                _moveToArea(0);
              },
            );
            return;
          }
          ui.overlay.value = relicOverlay(
            library: library,
            area: kAreas[state.areaIndex],
            next: kAreas[state.areaIndex + 1],
            onContinue: () {
              _engage();
              _moveToArea(state.areaIndex + 1);
            },
          );
        },
        onGameOver: (state) {
          audio.play('game_over');
          saved.bestScore = max(saved.bestScore, state.score);
          ui.overlay.value = gameOverOverlay(
            state: state,
            bestScore: saved.bestScore,
            onRetry: () {
              _engage();
              _hideOverlay();
              arena?.retryWave();
            },
          );
          _saveProgress();
        },
      ),
    );
    created.bestScore = saved.bestScore;
    created.setInput(this);
    arena = created;
    if (_viewport != Size.zero) {
      created.resize(_viewport.width, _viewport.height);
    }
  }

  /// Picks the background track for the current state; playBgm ignores repeats.
  void _syncBgm() {
    final current = arena;
    final String target;
    if (_victoryShown) {
      target = 'bgm_victory';
    } else if (current == null || !current.started) {
      target = 'bgm_menu';
    } else if (current.ended) {
      target = 'bgm_gameover';
    } else if (current.wave == current.area.waveCount ||
        current.wave == current.area.waveCount - 5) {
      target = 'bgm_boss';
    } else {
      target = 'bgm_battle';
    }
    audio.playBgm(target);
  }

  void _showLoading([String text = 'Memanggil penjaga langit…']) {
    ui.overlay.value = loadingOverlay(text);
  }

  void _hideOverlay() {
    ui.overlay.value = null;
  }

  void _openTutorial(VoidCallback onDone) {
    _tutorialOpen = true;
    ui.overlay.value = TutorialOverlay(
      onDone: () {
        _tutorialOpen = false;
        onDone();
      },
    );
  }

  /// The menu button in the HUD: pauses the run and offers LANJUTKAN.
  void openMenu() {
    if (arena?.started != true) {
      _showMenu();
      return;
    }
    _pausedByUi = true;
    _menuResumable = true;
    _showMenu();
  }

  void _resumeRun() {
    _engage();
    _pausedByUi = false;
    _menuResumable = false;
    _hideOverlay();
  }

  Future<void> _showMenu() async {
    try {
      await library.loadArea(saved.currentArea);
    } catch (_) {
      // The menu still works without the background picture.
    }
    final area = kAreas[saved.currentArea];
    ui.overlay.value = MainMenu(
      background: library.get(area.bgKey)?.image,
      progress:
          'Area ${saved.currentArea + 1} · ${area.name} · ${kSkins[saved.skinIndex].name}',
      volumeLabel: volumeLabel,
      resumable: _menuResumable,
      onPlay: () {
        if (_menuResumable) {
          _resumeRun();
          return;
        }
        _engage();
        _prepareSelection(saved.currentArea, saved.skinIndex);
      },
      onSelect: _showSelection,
      onTutorial: () => _openTutorial(() => _showMenu()),
      onVolume: () {
        cycleVolume();
        _showMenu();
      },
      onReset: _confirmReset,
    );
  }

  void _confirmReset() {
    ui.overlay.value = confirmOverlay(
      title: 'RESET PROGRES?',
      text: 'Semua progres, skor terbaik, dan relik akan dihapus.',
      yesLabel: 'YA, RESET',
      onYes: () => _resetProgress(),
      onNo: () => _showMenu(),
    );
  }

  Future<void> _resetProgress() async {
    _pausedByUi = false;
    _menuResumable = false;
    _showLoading('Mereset progres…');
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_saveKey);
    } catch (_) {
      // Nothing saved yet; the in-memory reset below still applies.
    }
    final volume = saved.volume;
    saved = SaveData.defaults()..volume = volume;
    await library.loadArea(0);
    await library.loadSkin(0);
    _wireWorld();
    _showMenu();
  }

  void _showSelection() {
    ui.overlay.value = areaSelectOverlay(
      library: library,
      selected: saved.currentArea,
      onPick: _showSkinSelect,
    );
  }

  void _showSkinSelect(int areaIndex) {
    // Show the screen at once; the previews fill in as each sheet loads.
    unawaited(_preloadSkinPreviews());
    ui.overlay.value = skinSelectOverlay(
      library: library,
      selected: saved.skinIndex,
      onPick: (skinIndex) {
        _engage();
        _prepareSelection(areaIndex, skinIndex);
      },
      onBack: _showSelection,
    );
  }

  /// One sheet at a time, so loading never freezes the selection screen.
  Future<void> _preloadSkinPreviews() async {
    for (final skin in kSelectableSkins) {
      await library.load(skin.coreKey).then((_) {}, onError: (_) {});
      // Give the frame a break between sheets; each one decodes and isolates
      // its pixels, which otherwise stalls the menu.
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Browsers only start audio after a tap or key press.
  void unlockAudio() => audio.unlock();

  /// The UPGRADE button in the HUD: spends one token on a permanent upgrade.
  void openUpgradeMenu() {
    final current = arena;
    if (current == null ||
        !current.started ||
        current.paused ||
        current.ended ||
        current.upgradeTokens <= 0) {
      return;
    }
    _pausedByUi = true;
    ui.overlay.value = upgradeOverlay(
      library: library,
      onPick: (key) {
        current.buyUpgrade(key);
        _pausedByUi = false;
        _hideOverlay();
      },
      onBack: () {
        _pausedByUi = false;
        _hideOverlay();
      },
    );
  }

  Future<void> _prepareSelection(int areaIndex, int skinIndex) async {
    _pausedByUi = false;
    _menuResumable = false;
    _showLoading(
      'Menyiapkan ${kSkins[skinIndex].name} di ${kAreas[areaIndex].name}…',
    );
    try {
      await Future.wait([
        library.loadArea(areaIndex),
        library.loadSkin(skinIndex),
      ]);
      final current = arena!;
      current.setSkin(skinIndex);
      current.resetArea(
        areaIndex,
        score: 0,
        bestScore: max(saved.bestScore, current.bestScore),
      );
      saved.currentArea = areaIndex;
      saved.skinIndex = skinIndex;
      await _saveProgress();
      // Both direct play and area/skin selection introduce each new run.
      _openTutorial(_showAreaStart);
    } catch (_) {
      ui.overlay.value = loadErrorOverlay(
        () => _prepareSelection(areaIndex, skinIndex),
      );
    }
  }

  void _showAreaStart() {
    final current = arena!;
    ui.overlay.value = startOverlay(
      area: kAreas[current.areaIndex],
      areaIndex: current.areaIndex,
      skin: kSkins[current.skinIndex],
      onStart: () {
        _engage();
        _hideOverlay();
        current.begin();
        if (current.areaIndex < kAreas.length - 1) {
          library.loadArea(current.areaIndex + 1).catchError((_) {});
        }
      },
    );
  }

  Future<void> _moveToArea(int index) async {
    _victoryShown = false;
    _showLoading('Membuka ${kAreas[index].name}…');
    try {
      await library.loadArea(index);
      final current = arena!;
      current.resetArea(
        index,
        score: current.score,
        bestScore: max(saved.bestScore, current.bestScore),
      );
      saved.currentArea = index;
      saved.unlockedArea = max(saved.unlockedArea, index);
      await _saveProgress();
      _showAreaStart();
    } catch (_) {
      ui.overlay.value = loadErrorOverlay(() => _moveToArea(index));
    }
  }

  // ---- Buttons in the HUD ----

  /// The "?" button: opens the tutorial on top of a run; the run is paused meanwhile.
  void openHelp() {
    _openTutorial(_hideOverlay);
  }

  @override
  void onRemove() {
    saveNow();
    audio.destroy();
    ui.dispose();
    super.onRemove();
  }
}
