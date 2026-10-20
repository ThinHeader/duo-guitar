/// Detects a vertical strum across horizontal string centers, and a tap on one string.
class StrumDetector {
  StrumDetector({this.stringCount = 6});

  final int stringCount;

  final Map<int, _Track> _tracks = {};

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
    final track = _tracks[pointer];
    if (track == null) {
      _tracks[pointer] = _Track(y);
      return const [];
    }
    final previous = track.y;
    track.travel += (y - previous).abs();
    track.y = y;
    if (y == previous) {
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
    if (hits.isNotEmpty) {
      track.crossed = true;
    }
    return hits;
  }

  /// A lift that never crossed a string and barely moved plucks that string.
  int? end(int pointer, {required double height}) {
    final track = _tracks.remove(pointer);
    if (track == null || height <= 0 || stringCount <= 0) {
      return null;
    }
    if (track.crossed) {
      return null;
    }
    final slop = height * 0.03 < 12 ? 12.0 : height * 0.03;
    if (track.travel > slop) {
      return null;
    }
    final string = (track.y / height * stringCount).floor();
    if (string < 0 || string >= stringCount) {
      return null;
    }
    return string;
  }

  double _center(int string, double height) {
    return (string + 0.5) / stringCount * height;
  }

  /// True when the segment passes strictly through [center].
  bool _crossed(double from, double to, double center) {
    return (from < center && to > center) || (from > center && to < center);
  }
}

class _Track {
  _Track(this.y);

  double y;
  double travel = 0;
  bool crossed = false;
}
