import 'package:duo_guitar/chords/chord_shape.dart';
import 'package:duo_guitar/practice/songs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open chord shapes match the planned frets and mutes', () {
    expect(ChordShape.c.frets, [0, 3, 2, 0, 1, 0]);
    expect(ChordShape.c.play, [false, true, true, true, true, true]);
    expect(ChordShape.g.frets, [3, 2, 0, 0, 0, 3]);
    expect(ChordShape.g.play, [true, true, true, true, true, true]);
    expect(ChordShape.am.frets, [0, 0, 2, 2, 1, 0]);
    expect(ChordShape.em.frets, [0, 2, 2, 0, 0, 0]);
    expect(ChordShape.d.frets, [0, 0, 0, 2, 3, 2]);
    expect(ChordShape.d.play, [false, false, true, true, true, true]);
    expect(ChordShape.hints.map((shape) => shape.name), ['C', 'G', 'Am', 'Em', 'D']);
  });

  test('an unknown song id is ignored', () {
    expect(chordForCue(songId: 99, step: 0), isNull);
    expect(chordForCue(songId: 1, step: 1)?.name, 'G');
  });
}
