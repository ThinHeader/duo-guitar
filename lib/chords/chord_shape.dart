/// One open-chord shape. [play] is false for a string the shape does not sound.
class ChordShape {
  const ChordShape({
    required this.name,
    required this.frets,
    required this.play,
  });

  final String name;
  final List<int> frets;
  final List<bool> play;

  static const ChordShape c = ChordShape(
    name: 'C',
    frets: [0, 3, 2, 0, 1, 0],
    play: [false, true, true, true, true, true],
  );

  static const ChordShape g = ChordShape(
    name: 'G',
    frets: [3, 2, 0, 0, 0, 3],
    play: [true, true, true, true, true, true],
  );

  static const ChordShape am = ChordShape(
    name: 'Am',
    frets: [0, 0, 2, 2, 1, 0],
    play: [true, true, true, true, true, true],
  );

  static const ChordShape em = ChordShape(
    name: 'Em',
    frets: [0, 2, 2, 0, 0, 0],
    play: [true, true, true, true, true, true],
  );

  static const ChordShape d = ChordShape(
    name: 'D',
    frets: [0, 0, 0, 2, 3, 2],
    play: [false, false, true, true, true, true],
  );

  static const List<ChordShape> hints = [c, g, am, em, d];
}
