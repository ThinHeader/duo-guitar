import 'package:duo_guitar/chords/chord_shape.dart';
import 'package:duo_guitar/practice/songs.dart';

class PracticeBeat {
  const PracticeBeat({
    required this.song,
    required this.stepIndex,
    required this.beatInChord,
    required this.chord,
    required this.bpm,
  });

  final PracticeSong song;
  final int stepIndex;
  final int beatInChord;
  final ChordShape chord;
  final int bpm;

  bool get accent => beatInChord == 0;
}

/// Beat clock. [now] is injectable so tests can move time without waiting.
class PracticeClock {
  PracticeClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  PracticeSong? _song;
  int _bpm = 72;
  DateTime? _started;
  int? _lastBeat;

  bool get running => _started != null && _song != null;

  PracticeBeat? start(PracticeSong song, {int? bpm, DateTime? at}) {
    _song = song;
    _bpm = bpm ?? song.defaultBpm;
    _started = at ?? _now();
    _lastBeat = null;
    return poll(at: _started);
  }

  void stop() {
    _started = null;
    _song = null;
    _lastBeat = null;
  }

  /// Returns a beat only when the beat index changes.
  PracticeBeat? poll({DateTime? at}) {
    final song = _song;
    final started = _started;
    if (song == null || started == null || song.cycleBeats <= 0 || _bpm <= 0) {
      return null;
    }
    final elapsed = (at ?? _now()).difference(started);
    final beatUs = (60000000 / _bpm).round();
    if (beatUs <= 0) {
      return null;
    }
    final total = elapsed.isNegative ? 0 : elapsed.inMicroseconds ~/ beatUs;
    if (_lastBeat == total) {
      return null;
    }
    _lastBeat = total;
    final located = _locate(song, total);
    return PracticeBeat(
      song: song,
      stepIndex: located.$1,
      beatInChord: located.$2,
      chord: song.steps[located.$1].chord,
      bpm: _bpm,
    );
  }

  (int, int) _locate(PracticeSong song, int totalBeats) {
    final pos = totalBeats % song.cycleBeats;
    var left = pos;
    for (var i = 0; i < song.steps.length; i++) {
      final beats = song.steps[i].beats;
      if (left < beats) {
        return (i, left);
      }
      left -= beats;
    }
    return (0, 0);
  }
}
