/// Six fret numbers, index 0 is the low E string.
///
/// `0` is an open string. `1` through `12` are fretted positions.
class FretState {
  const FretState(this.frets);

  static const FretState open = FretState([0, 0, 0, 0, 0, 0]);

  final List<int> frets;

  int operator [](int string) => frets[string];

  FretState copyWithString(int string, int fret) {
    final next = List<int>.of(frets);
    next[string] = fret;
    return FretState(next);
  }

  @override
  bool operator ==(Object other) {
    if (other is! FretState || other.frets.length != frets.length) {
      return false;
    }
    for (var i = 0; i < frets.length; i++) {
      if (other.frets[i] != frets[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(frets);

  @override
  String toString() => 'FretState($frets)';
}
