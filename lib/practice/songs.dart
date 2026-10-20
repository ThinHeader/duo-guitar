import 'package:duo_guitar/chords/chord_shape.dart';

class SongStep {
  const SongStep(this.chord, this.beats);

  final ChordShape chord;
  final int beats;
}

class PracticeSong {
  const PracticeSong({
    required this.id,
    required this.name,
    required this.defaultBpm,
    required this.steps,
  });

  final int id;
  final String name;
  final int defaultBpm;
  final List<SongStep> steps;

  int get cycleBeats => steps.fold(0, (sum, step) => sum + step.beats);
}

const List<int> practiceBpms = [60, 72, 90];

const List<PracticeSong> practiceSongs = [
  PracticeSong(
    id: 1,
    name: '循环一',
    defaultBpm: 72,
    steps: [
      SongStep(ChordShape.c, 4),
      SongStep(ChordShape.g, 4),
      SongStep(ChordShape.am, 4),
      SongStep(ChordShape.em, 4),
    ],
  ),
  PracticeSong(
    id: 2,
    name: '循环二',
    defaultBpm: 72,
    steps: [
      SongStep(ChordShape.g, 4),
      SongStep(ChordShape.d, 4),
      SongStep(ChordShape.em, 4),
      SongStep(ChordShape.c, 4),
    ],
  ),
  PracticeSong(
    id: 3,
    name: '慢换',
    defaultBpm: 60,
    steps: [
      SongStep(ChordShape.c, 4),
      SongStep(ChordShape.am, 4),
      SongStep(ChordShape.g, 4),
      SongStep(ChordShape.d, 4),
    ],
  ),
  PracticeSong(
    id: 4,
    name: '两拍换',
    defaultBpm: 72,
    steps: [
      SongStep(ChordShape.am, 2),
      SongStep(ChordShape.g, 2),
      SongStep(ChordShape.c, 2),
      SongStep(ChordShape.em, 2),
    ],
  ),
];

PracticeSong? songById(int id) {
  for (final song in practiceSongs) {
    if (song.id == id) {
      return song;
    }
  }
  return null;
}

ChordShape? chordForCue({required int songId, required int step}) {
  final song = songById(songId);
  if (song == null || song.steps.isEmpty) {
    return null;
  }
  return song.steps[step % song.steps.length].chord;
}
