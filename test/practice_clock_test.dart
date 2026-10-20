import 'package:duo_guitar/practice/practice_clock.dart';
import 'package:duo_guitar/practice/songs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('60 bpm and 4 beats advances to the next chord after 4 seconds', () {
    final start = DateTime(2026, 1, 1);
    final clock = PracticeClock(now: () => start);
    final song = practiceSongs.first;
    final first = clock.start(song, bpm: 60, at: start);

    expect(first, isNotNull);
    expect(first!.chord.name, 'C');
    expect(first.accent, isTrue);
    expect(first.beatInChord, 0);
    expect(
      clock.poll(at: start.add(const Duration(milliseconds: 500))),
      isNull,
    );

    final next = clock.poll(at: start.add(const Duration(seconds: 4)));
    expect(next, isNotNull);
    expect(next!.chord.name, 'G');
    expect(next.beatInChord, 0);
    expect(next.accent, isTrue);
  });
}
