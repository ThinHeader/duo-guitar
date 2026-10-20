import 'dart:async';

import 'package:duo_guitar/audio/strum_engine.dart';
import 'package:duo_guitar/practice/practice_clock.dart';
import 'package:duo_guitar/practice/songs.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/protocol/guide_cue.dart';
import 'package:duo_guitar/ui/body_page.dart';
import 'package:duo_guitar/ui/neck_page.dart';
import 'package:flutter/material.dart';

const _wood = Color(0xFF1A120B);
const _ink = Color(0xFFF3E6C8);

/// One window: neck touches update an in-memory fret state, body strums it.
class DebugDuoPage extends StatefulWidget {
  const DebugDuoPage({super.key});

  @override
  State<DebugDuoPage> createState() => _DebugDuoPageState();
}

class _DebugDuoPageState extends State<DebugDuoPage> {
  final ValueNotifier<FretState> _frets = ValueNotifier(FretState.open);
  final ValueNotifier<GuideCue?> _cue = ValueNotifier(null);
  final PracticeClock _clock = PracticeClock();
  final StrumEngine _engine = StrumEngine();
  Timer? _practiceTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await _engine.init();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    _practiceTimer?.cancel();
    _clock.stop();
    _frets.dispose();
    _cue.dispose();
    unawaited(_engine.dispose());
    super.dispose();
  }

  void _togglePractice() {
    if (_clock.running) {
      _practiceTimer?.cancel();
      _clock.stop();
      _cue.value = null;
      setState(() {});
      return;
    }
    final song = practiceSongs.first;
    final beat = _clock.start(song, bpm: song.defaultBpm);
    if (beat != null) {
      _publish(beat);
    }
    _practiceTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final next = _clock.poll();
      if (next != null) {
        _publish(next);
      }
    });
    setState(() {});
  }

  void _publish(PracticeBeat beat) {
    final cue = GuideCue(
      songId: beat.song.id,
      step: beat.stepIndex,
      beatInChord: beat.beatInChord,
      bpm: beat.bpm,
      accent: beat.accent,
    );
    _cue.value = cue;
    unawaited(_engine.playClick(accent: beat.accent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _wood,
      appBar: AppBar(
        title: const Text('分屏调试'),
        backgroundColor: _wood,
        foregroundColor: _ink,
        surfaceTintColor: _wood,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFFAB91)),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: NeckPage(
                    embedded: true,
                    cueListenable: _cue,
                    onFret: (state) => _frets.value = state,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFF5C4033),
                ),
                Expanded(
                  child: BodyPage(
                    embedded: true,
                    fretListenable: _frets,
                    onStrum: (state, string) {
                      unawaited(_engine.strum(state, string));
                    },
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _togglePractice,
            child: Text(
              _clock.running ? '停止跟弹' : '跟弹',
              style: const TextStyle(color: Color(0xFFE0A100)),
            ),
          ),
        ],
      ),
    );
  }
}
