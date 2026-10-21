import 'dart:async';

import 'package:duo_guitar/audio/strum_engine.dart';
import 'package:duo_guitar/chords/chord_shape.dart';
import 'package:duo_guitar/net/udp_body_session.dart';
import 'package:duo_guitar/practice/practice_clock.dart';
import 'package:duo_guitar/practice/songs.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/protocol/guide_cue.dart';
import 'package:duo_guitar/ui/widgets/fretboard.dart';
import 'package:duo_guitar/ui/widgets/string_bed.dart';
import 'package:flutter/material.dart';

const _wood = Color(0xFF1A120B);
const _ink = Color(0xFFF3E6C8);
const _muted = Color(0xFFD9C7A6);
const _amber = Color(0xFFE0A100);

/// Song list with a beat clock. The body sends each beat to the neck.
class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    this.session,
    this.engine,
    this.showFretboard = false,
    this.showStrings = false,
    this.onCue,
  });

  final UdpBodySession? session;
  final StrumEngine? engine;
  final bool showFretboard;
  final bool showStrings;
  final ValueChanged<GuideCue>? onCue;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final PracticeClock _clock = PracticeClock();
  Timer? _timer;
  PracticeSong _song = practiceSongs.first;
  int _bpm = practiceSongs.first.defaultBpm;
  ChordShape? _chord;
  var _running = false;
  StrumEngine? _ownedEngine;

  StrumEngine? get _engine => widget.engine ?? _ownedEngine;

  ChordShape get _guide => _chord ?? _song.steps.first.chord;

  @override
  void initState() {
    super.initState();
    if (widget.engine == null) {
      final engine = StrumEngine();
      _ownedEngine = engine;
      unawaited(engine.init());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    final owned = _ownedEngine;
    if (owned != null) {
      unawaited(owned.dispose());
    }
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    final beat = _clock.start(_song, bpm: _bpm);
    setState(() {
      _running = true;
      _chord = beat?.chord;
    });
    if (beat != null) {
      _emit(beat);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final next = _clock.poll();
      if (next == null) {
        return;
      }
      if (mounted) {
        setState(() => _chord = next.chord);
      }
      _emit(next);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    if (mounted) {
      setState(() => _running = false);
    }
  }

  void _emit(PracticeBeat beat) {
    final cue = GuideCue(
      songId: beat.song.id,
      step: beat.stepIndex,
      beatInChord: beat.beatInChord,
      bpm: beat.bpm,
      accent: beat.accent,
    );
    widget.session?.sendGuide(cue);
    widget.onCue?.call(cue);
    final engine = _engine;
    if (engine != null) {
      unawaited(engine.playClick(accent: beat.accent));
    }
  }

  void _strum(int string) {
    final engine = _engine;
    final session = widget.session;
    if (engine == null) {
      return;
    }
    final frets = session?.frets.value ?? FretState.open;
    unawaited(engine.strum(frets, string));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _wood,
      appBar: AppBar(
        toolbarHeight: 44,
        title: Text(_guide.name),
        backgroundColor: _wood,
        foregroundColor: _ink,
        surfaceTintColor: _wood,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: practiceSongs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final song = practiceSongs[index];
                        final selected = song.id == _song.id;
                        return ChoiceChip(
                          label: Text(song.name),
                          selected: selected,
                          visualDensity: VisualDensity.compact,
                          onSelected: _running
                              ? null
                              : (_) => setState(() {
                                  _song = song;
                                  _bpm = song.defaultBpm;
                                }),
                          selectedColor: _amber,
                          labelStyle: TextStyle(
                            color: selected ? _wood : _ink,
                            fontSize: 13,
                          ),
                          backgroundColor: const Color(0xFF2A2118),
                        );
                      },
                    ),
                  ),
                  for (final bpm in practiceBpms) ...[
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: Text('$bpm'),
                      selected: _bpm == bpm,
                      visualDensity: VisualDensity.compact,
                      onSelected: _running
                          ? null
                          : (_) => setState(() => _bpm = bpm),
                      selectedColor: _amber,
                      labelStyle: TextStyle(
                        color: _bpm == bpm ? _wood : _ink,
                        fontSize: 13,
                      ),
                      backgroundColor: const Color(0xFF2A2118),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _running ? _stop : _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: _wood,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(_running ? '停止' : '开始'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final step in _song.steps)
                      TextSpan(
                        text: '${step.chord.name}   ',
                        style: TextStyle(
                          color: step.chord.name == _guide.name
                              ? _amber
                              : _muted,
                          fontWeight: step.chord.name == _guide.name
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.showFretboard)
              Expanded(
                child: Fretboard(onChanged: (_) {}, guide: _guide),
              ),
            if (widget.showStrings)
              Expanded(
                child: widget.session == null
                    ? StringBed(frets: FretState.open, onStrike: _strum)
                    : ListenableBuilder(
                        listenable: widget.session!.frets,
                        builder: (context, _) {
                          return StringBed(
                            frets: widget.session!.frets.value,
                            onStrike: _strum,
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
