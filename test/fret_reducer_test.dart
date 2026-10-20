import 'package:duo_guitar/input/fret_reducer.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const board = Size(130, 60);

  test('origin of a 130x60 board is string 0 fret 0', () {
    final touch = fretAt(localPosition: Offset.zero, size: board);
    expect(touch?.string, 0);
    expect(touch?.fret, 0);
  });

  test('far bottom-right inside a 130x60 board is string 5 fret 12', () {
    final touch = fretAt(
      localPosition: const Offset(129.999, 59.999),
      size: board,
    );
    expect(touch?.string, 5);
    expect(touch?.fret, 12);
  });

  test('positions outside the board are null', () {
    expect(fretAt(localPosition: const Offset(-1, 10), size: board), isNull);
    expect(fretAt(localPosition: const Offset(10, -0.1), size: board), isNull);
    expect(fretAt(localPosition: const Offset(130, 30), size: board), isNull);
    expect(fretAt(localPosition: const Offset(40, 60), size: board), isNull);
    expect(fretAt(localPosition: const Offset(140, 80), size: board), isNull);
    expect(fretAt(localPosition: Offset.zero, size: Size.zero), isNull);
    expect(
      fretAt(localPosition: const Offset(10, 10), size: const Size(0, 60)),
      isNull,
    );
  });

  test('two touches on string 1 keep fret 5 and leave the rest open', () {
    final state = reduceFrets(const [
      FretTouch(1, 2),
      FretTouch(1, 5),
    ]);
    expect(state, const FretState([0, 5, 0, 0, 0, 0]));
  });

  test('a later lower fret does not replace a higher one', () {
    final state = reduceFrets(const [
      FretTouch(1, 5),
      FretTouch(1, 2),
    ]);
    expect(state, const FretState([0, 5, 0, 0, 0, 0]));
  });

  test('touches outside the string or fret range are ignored', () {
    final state = reduceFrets(const [
      FretTouch(-1, 4),
      FretTouch(6, 1),
      FretTouch(2, -1),
      FretTouch(2, 13),
      FretTouch(4, 12),
    ]);
    expect(state, const FretState([0, 0, 0, 0, 12, 0]));
  });

  test('empty touches reduce to FretState.open', () {
    expect(reduceFrets(const <FretTouch>[]), FretState.open);
  });
}
