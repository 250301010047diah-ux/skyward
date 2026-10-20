// Sound manager. Sound effects and music are mp3 files in assets/audio:
//   assets/audio/sfx/<name>.mp3   (see kSfxNames)
//   assets/audio/bgm/<name>.mp3   (see kBgmNames)
// The files are empty placeholders for now; replace them with real audio.
// Empty or missing files are ignored silently, so the game keeps running.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'world.dart';

/// Every sound effect the game can play. Names are unique; similar events share one sound.
const List<String> kSfxNames = [
  'jump',
  'land',
  'melee',
  'bow',
  'hit',
  'defeat',
  'explode',
  'beam',
  'skill',
  'ultimate',
  'shield',
  'hurt',
  'coin',
  'powerup',
  'warning',
  'upgrade',
  'wave_clear',
  'relic',
  'area_clear',
  'game_over',
  'victory',
  'click',
];

/// Background music: one track plays at a time.
const List<String> kBgmNames = [
  'bgm_menu', // main menu, tutorial, selection
  'bgm_battle', // normal waves
  'bgm_boss', // mini boss and boss waves
  'bgm_gameover', // after the player falls
  'bgm_victory', // campaign finished
];

const int _maxSfxPlayers = 16;

class GameAudio implements SoundSink {
  final List<AudioPlayer> _sfxPlayers = [];
  AudioPlayer? _bgm;
  String? _currentBgm;
  String? _wantedBgm;
  bool _blocked = false;
  bool _unlocked = false;
  double _volume = 1;

  /// Master volume from the in-game and menu button (1, 0.5 or 0).
  Future<void> setVolume(double value) async {
    _volume = value;
    await _bgm?.setVolume(value);
  }

  @override
  void play(String name) {
    if (_volume <= 0 || !kSfxNames.contains(name)) return;
    if (_sfxPlayers.length >= _maxSfxPlayers) {
      final oldest = _sfxPlayers.removeAt(0);
      unawaited(oldest.dispose());
    }
    final player = AudioPlayer();
    _sfxPlayers.add(player);
    // listen (not first): a disposed player closes this stream without an event.
    player.onPlayerComplete.listen(
      (_) => _release(player),
      onError: (_) {},
      onDone: () {},
    );
    unawaited(_startSfx(player, name).catchError((_) => _release(player)));
  }

  Future<void> _startSfx(AudioPlayer player, String name) async {
    await _setMixContext(player);
    await player.play(AssetSource('audio/sfx/$name.mp3'), volume: _volume);
  }

  /// Switches the background track; the same name twice does nothing.
  Future<void> playBgm(String name) async {
    if (!kBgmNames.contains(name)) return;
    _wantedBgm = name;
    if (name == _currentBgm || _blocked) return;
    _currentBgm = name;
    try {
      final player = _bgm ??= AudioPlayer();
      await _setMixContext(player);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_volume);
      await player.play(AssetSource('audio/bgm/$name.mp3'), volume: _volume);
    } catch (_) {
      // Refused (browsers need a tap first) or no audio device: keep the game
      // running and try again from unlock().
      _currentBgm = null;
      _blocked = true;
    }
  }

  /// Call on a tap or key press. The menu music is requested before the first
  /// gesture, which browsers refuse, so it is started again here.
  void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    if (!kIsWeb && !_blocked) return;
    _blocked = false;
    _currentBgm = null;
    final wanted = _wantedBgm;
    if (wanted != null) unawaited(playBgm(wanted));
  }

  Future<void> destroy() async {
    for (final player in _sfxPlayers) {
      await player.dispose();
    }
    _sfxPlayers.clear();
    await _bgm?.dispose();
    _bgm = null;
    _currentBgm = null;
  }

  void _release(AudioPlayer player) {
    if (_sfxPlayers.remove(player)) unawaited(player.dispose());
  }

  /// Players must not take audio focus: on Android a focused player pauses the
  /// others, so the BGM would stop whenever a sound effect plays.
  AudioContext _mixContext() => AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const <AVAudioSessionOptions>{
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
  );

  Future<void> _setMixContext(AudioPlayer player) async {
    try {
      await player.setAudioContext(_mixContext());
    } catch (_) {
      // Not supported on every platform (e.g. Windows): play without it.
    }
  }
}
