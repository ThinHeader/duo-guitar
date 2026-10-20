import 'dart:math' as math;

import 'constants.dart';

/// Twelve-tone equal temperament, A4 = 440 Hz.
double frequencyFor({required int string, required int fret}) {
  final midi = DuoGuitar.openMidi[string] + fret;
  return (440 * math.pow(2, (midi - 69) / 12)).toDouble();
}

String sampleAssetFor({required int string, required int fret}) {
  return 'assets/samples/s${string}_f$fret.wav';
}
