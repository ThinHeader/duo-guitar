import 'package:flutter_soloud/flutter_soloud.dart';

import '../protocol/constants.dart';
import '../protocol/fret_state.dart';
import '../protocol/tuning.dart';

/// One preloaded sample voice per string. A new strum replaces that string.
class StrumEngine {
  final SoLoud _soloud = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};
  final Map<int, SoundHandle> _handles = {};

  bool _started = false;
  bool _disposed = false;

  /// Loads all 78 fret samples, keyed by `$string:$fret`.
  Future<void> init() async {
    if (_disposed || _started) {
      return;
    }
    await _soloud.init();
    _started = true;
    for (var string = 0; string < DuoGuitar.stringCount; string++) {
      for (var fret = 0; fret < DuoGuitar.fretCount; fret++) {
        final asset = sampleAssetFor(string: string, fret: fret);
        _sources['$string:$fret'] = await _soloud.loadAsset(asset);
      }
    }
  }

  /// Stops the previous voice on [stringIndex], then plays [state]'s fret.
  Future<void> strum(FretState state, int stringIndex) async {
    if (_disposed ||
        stringIndex < 0 ||
        stringIndex >= DuoGuitar.stringCount) {
      return;
    }
    final previous = _handles.remove(stringIndex);
    if (previous != null) {
      await _stopQuietly(previous);
    }
    final source = _sources['$stringIndex:${state[stringIndex]}'];
    if (source == null) {
      return;
    }
    _handles[stringIndex] = await _soloud.play(source);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final handle in _handles.values) {
      await _stopQuietly(handle);
    }
    _handles.clear();
    for (final source in _sources.values) {
      await _soloud.disposeSource(source);
    }
    _sources.clear();
    if (_started) {
      _soloud.deinit();
    }
  }

  Future<void> _stopQuietly(SoundHandle handle) async {
    try {
      await _soloud.stop(handle);
    } on SoLoudException {
      // The voice may already have stopped.
    }
  }
}
