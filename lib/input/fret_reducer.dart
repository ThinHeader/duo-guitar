import 'dart:ui';

import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';

/// A finger on one string and fret of the neck.
class FretTouch {
  const FretTouch(this.string, this.fret);

  /// 0 low E (top band) through 5 high E (bottom band).
  final int string;

  /// 0 nut (left column) through 12 (right column, toward the body).
  final int fret;

  @override
  String toString() => 'FretTouch(string: $string, fret: $fret)';
}

/// Maps a point in the fretboard rect to a string band and fret column.
///
/// String 0 is the top band. Fret 0 is the left column. Returns null when
/// [size] is empty or [localPosition] lies outside the rect.
FretTouch? fretAt({required Offset localPosition, required Size size}) {
  if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
    return null;
  }
  final dx = localPosition.dx;
  final dy = localPosition.dy;
  if (dx < 0 || dy < 0 || dx >= size.width || dy >= size.height) {
    return null;
  }

  final string = (dy / size.height * DuoGuitar.stringCount)
      .floor()
      .clamp(0, DuoGuitar.stringCount - 1);
  final fret = (dx / size.width * DuoGuitar.fretCount)
      .floor()
      .clamp(0, DuoGuitar.fretCount - 1);
  return FretTouch(string, fret);
}

/// Collapses simultaneous touches into one fret per string.
///
/// Starts from [FretState.open]. When several touches share a string, the
/// highest in-range fret wins. Touches outside 0..5 / 0..12 are ignored.
FretState reduceFrets(Iterable<FretTouch> touches) {
  final frets = List<int>.filled(DuoGuitar.stringCount, 0);
  for (final touch in touches) {
    final onBoard = touch.string >= 0 &&
        touch.string < DuoGuitar.stringCount &&
        touch.fret >= 0 &&
        touch.fret < DuoGuitar.fretCount;
    if (!onBoard) {
      continue;
    }
    if (touch.fret > frets[touch.string]) {
      frets[touch.string] = touch.fret;
    }
  }
  return FretState(frets);
}
