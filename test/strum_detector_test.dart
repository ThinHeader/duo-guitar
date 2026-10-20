import 'package:duo_guitar/input/strum_detector.dart';
import 'package:flutter_test/flutter_test.dart';

// Height 600 puts string centers at 50, 150, 250, 350, 450, and 550.
const _height = 600.0;

void main() {
  group('StrumDetector', () {
    test('first move at y=0 returns empty, then y=600 crosses every string', () {
      final detector = StrumDetector();
      expect(detector.move(pointer: 1, y: 0, height: _height), isEmpty);
      expect(
        detector.move(pointer: 1, y: 600, height: _height),
        [0, 1, 2, 3, 4, 5],
      );
    });

    test('new pointer from y=0 to y=100 returns [0]', () {
      final detector = StrumDetector();
      detector.move(pointer: 1, y: 600, height: _height);
      expect(detector.move(pointer: 2, y: 0, height: _height), isEmpty);
      expect(detector.move(pointer: 2, y: 100, height: _height), [0]);
    });

    test('moves that stay between y=10 and y=20 return empty', () {
      final detector = StrumDetector();
      expect(detector.move(pointer: 1, y: 10, height: _height), isEmpty);
      expect(detector.move(pointer: 1, y: 20, height: _height), isEmpty);
      expect(detector.move(pointer: 1, y: 10, height: _height), isEmpty);
      expect(detector.move(pointer: 1, y: 18, height: _height), isEmpty);
    });

    test('upward move from y=600 to y=0 returns strings from high to low', () {
      final detector = StrumDetector();
      expect(detector.move(pointer: 1, y: 600, height: _height), isEmpty);
      expect(
        detector.move(pointer: 1, y: 0, height: _height),
        [5, 4, 3, 2, 1, 0],
      );
    });

    test('crossing the same center again triggers that string again', () {
      final detector = StrumDetector();
      detector.move(pointer: 1, y: 0, height: _height);
      expect(detector.move(pointer: 1, y: 100, height: _height), [0]);
      expect(detector.move(pointer: 1, y: 0, height: _height), [0]);
      expect(detector.move(pointer: 1, y: 100, height: _height), [0]);
    });

    test('end makes the next event a new first sample', () {
      final detector = StrumDetector();
      detector.move(pointer: 1, y: 0, height: _height);
      detector.end(1);
      expect(detector.move(pointer: 1, y: 600, height: _height), isEmpty);
    });

    test('non-positive height returns empty', () {
      final detector = StrumDetector();
      detector.move(pointer: 1, y: 0, height: _height);
      expect(detector.move(pointer: 1, y: 600, height: 0), isEmpty);
      expect(detector.move(pointer: 1, y: 600, height: -5), isEmpty);
    });
  });
}
