/// Detects a vertical strum across horizontal string centers.
class StrumDetector {
  StrumDetector({this.stringCount = 6});

  final int stringCount;

  final Map<int, double> _y = {};

  /// First event for a pointer only records Y and returns an empty list.
  /// Later events return string indexes whose centers were crossed, in
  /// crossing order.
  List<int> move({
    required int pointer,
    required double y,
    required double height,
  }) {
    if (height <= 0 || stringCount <= 0) {
      return const [];
    }
    final previous = _y[pointer];
    _y[pointer] = y;
    if (previous == null || y == previous) {
      return const [];
    }

    final downward = y > previous;
    final hits = <int>[];
    if (downward) {
      for (var i = 0; i < stringCount; i++) {
        if (_crossed(previous, y, _center(i, height))) {
          hits.add(i);
        }
      }
    } else {
      for (var i = stringCount - 1; i >= 0; i--) {
        if (_crossed(previous, y, _center(i, height))) {
          hits.add(i);
        }
      }
    }
    if (hits.isEmpty) {
      return const [];
    }
    return hits;
  }

  void end(int pointer) {
    _y.remove(pointer);
  }

  double _center(int string, double height) {
    return (string + 0.5) / stringCount * height;
  }

  /// True when the segment passes strictly through [center].
  bool _crossed(double from, double to, double center) {
    return (from < center && to > center) || (from > center && to < center);
  }
}
