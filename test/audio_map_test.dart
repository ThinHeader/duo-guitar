import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open low E is about 82.41 Hz', () {
    expect(frequencyFor(string: 0, fret: 0), closeTo(82.41, 0.05));
  });

  test('twelfth fret is one octave above the open string', () {
    final open = frequencyFor(string: 0, fret: 0);
    final octave = frequencyFor(string: 0, fret: 12);
    expect(octave, closeTo(open * 2, open * 2 * 0.01));
  });

  test('open high E is about 329.63 Hz', () {
    expect(frequencyFor(string: 5, fret: 0), closeTo(329.63, 0.05));
  });

  test('sample asset path for string 2 fret 7', () {
    expect(sampleAssetFor(string: 2, fret: 7), 'assets/samples/s2_f7.wav');
  });

  test('six strings and thirteen fret positions', () {
    expect(DuoGuitar.openMidi.length, 6);
    expect(DuoGuitar.fretCount, 13);
  });
}
