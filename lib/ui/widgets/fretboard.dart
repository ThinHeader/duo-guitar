import 'dart:math' as math;

import 'package:duo_guitar/chords/chord_shape.dart';
import 'package:duo_guitar/input/fret_reducer.dart';
import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:flutter/material.dart';

const _wood = Color(0xFF1A120B);
const _fretLine = Color(0xFF5C4033);
const _stringColor = Color(0xFFE6D3A3);
const _pressed = Color(0xB3E0A100);
const _finger = Color(0xFFFFF4D0);
const _label = Color(0xFFF3E6C8);

const _labeledFrets = <int>{0, 3, 5, 7, 9, 12};

/// Room left of the nut for open-string circles and mute marks.
const _markerGutter = 28.0;

double _gutterFor(double width) {
  if (width <= _markerGutter + 40) {
    return 0;
  }
  return _markerGutter;
}

/// Low E (top) down to high E. Thicker strings sit toward the top of the neck.
const _stringGauge = <double>[2.4, 2.1, 1.8, 1.5, 1.25, 1.05];

/// Landscape fretboard. Reports the reduced [FretState] as fingers move.
class Fretboard extends StatelessWidget {
  const Fretboard({super.key, required this.onChanged, this.guide});

  final ValueChanged<FretState> onChanged;
  final ChordShape? guide;

  @override
  Widget build(BuildContext context) {
    return _FretboardSurface(onChanged: onChanged, guide: guide);
  }
}

class _FretboardSurface extends StatefulWidget {
  const _FretboardSurface({required this.onChanged, required this.guide});

  final ValueChanged<FretState> onChanged;
  final ChordShape? guide;

  @override
  State<_FretboardSurface> createState() => _FretboardSurfaceState();
}

class _FretboardSurfaceState extends State<_FretboardSurface> {
  final Map<int, FretTouch> _touches = {};
  FretState _state = FretState.open;

  void _put(PointerEvent event, Size size) {
    final gutter = _gutterFor(size.width);
    final playableWidth = size.width - gutter;
    if (playableWidth <= 0 ||
        size.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }
    final touch = fretAt(
      localPosition: Offset(
        event.localPosition.dx - gutter,
        event.localPosition.dy,
      ),
      size: Size(playableWidth, size.height),
    );
    if (touch == null) {
      _clear(event.pointer);
      return;
    }
    final previous = _touches[event.pointer];
    if (previous != null &&
        previous.string == touch.string &&
        previous.fret == touch.fret) {
      return;
    }
    _touches[event.pointer] = touch;
    _publish();
  }

  void _clear(int pointer) {
    if (_touches.remove(pointer) == null) {
      return;
    }
    _publish();
  }

  void _publish() {
    final next = reduceFrets(_touches.values);
    final changed = next != _state;
    if (changed) {
      _state = next;
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    if (changed) {
      widget.onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _wood,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) => _put(event, size),
                    onPointerMove: (event) => _put(event, size),
                    onPointerUp: (event) => _clear(event.pointer),
                    onPointerCancel: (event) => _clear(event.pointer),
                    child: ClipRect(
                      child: CustomPaint(
                        painter: _FretboardPainter(
                          touches: _touches.values.toList(growable: false),
                          guide: widget.guide,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            const _FretLabels(),
          ],
        ),
      ),
    );
  }
}

class _FretLabels extends StatelessWidget {
  const _FretLabels();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              SizedBox(width: _gutterFor(constraints.maxWidth)),
              const Expanded(child: _FretLabelRow()),
            ],
          );
        },
      ),
    );
  }
}

class _FretLabelRow extends StatelessWidget {
  const _FretLabelRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var fret = 0; fret < DuoGuitar.fretCount; fret++)
          Expanded(child: _FretLabel(fret)),
      ],
    );
  }
}

class _FretLabel extends StatelessWidget {
  const _FretLabel(this.fret);

  final int fret;

  @override
  Widget build(BuildContext context) {
    if (!_labeledFrets.contains(fret)) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Text(
        '$fret',
        style: const TextStyle(
          color: _label,
          fontSize: 12,
          height: 1,
        ),
      ),
    );
  }
}

class _FretboardPainter extends CustomPainter {
  _FretboardPainter({required List<FretTouch> touches, required this.guide})
    : touches = List<FretTouch>.unmodifiable(touches);

  final List<FretTouch> touches;
  final ChordShape? guide;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final left = _gutterFor(size.width);
    final fretWidth = (size.width - left) / DuoGuitar.fretCount;
    final bandHeight = size.height / DuoGuitar.stringCount;
    final cellPaint = Paint()..color = _pressed;

    for (final touch in touches) {
      if (!_onBoard(touch)) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTWH(
          left + touch.fret * fretWidth,
          touch.string * bandHeight,
          fretWidth,
          bandHeight,
        ),
        cellPaint,
      );
    }

    final wirePaint = Paint()
      ..color = _fretLine
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 1.5;
    for (var wire = 0; wire <= DuoGuitar.fretCount; wire++) {
      final x = wire == DuoGuitar.fretCount
          ? size.width - 0.75
          : left + wire * fretWidth;
      wirePaint.strokeWidth = wire == 0 ? 3 : 1.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), wirePaint);
    }

    final stringPaint = Paint()
      ..color = _stringColor
      ..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeCap = StrokeCap.round;
    for (var string = 0; string < DuoGuitar.stringCount; string++) {
      final y = (string + 0.5) * bandHeight;
      final gauge = _stringGauge[string];
      shadowPaint.strokeWidth = gauge;
      stringPaint.strokeWidth = gauge;
      canvas.drawLine(
        Offset(left, y + 0.7),
        Offset(size.width, y + 0.7),
        shadowPaint,
      );
      canvas.drawLine(Offset(left, y), Offset(size.width, y), stringPaint);
    }

    final dotPaint = Paint()..color = _finger;
    final fingerRadius = _markRadius(bandHeight, fretWidth);
    for (final touch in touches) {
      if (!_onBoard(touch)) {
        continue;
      }
      final center = Offset(
        left + (touch.fret + 0.5) * fretWidth,
        (touch.string + 0.5) * bandHeight,
      );
      canvas.drawCircle(center, fingerRadius, dotPaint);
    }

    final shape = guide;
    if (shape == null) {
      return;
    }
    final hollow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFE0A100);
    final mute = Paint()
      ..color = const Color(0xFFE7A090)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final hintRadius = _markRadius(bandHeight, fretWidth);
    final markerX = left * 0.45;
    for (var string = 0; string < DuoGuitar.stringCount; string++) {
      final y = (string + 0.5) * bandHeight;
      if (!shape.play[string]) {
        final arm = math.min(5.0, bandHeight * 0.22);
        canvas.drawLine(
          Offset(markerX - arm, y - arm),
          Offset(markerX + arm, y + arm),
          mute,
        );
        canvas.drawLine(
          Offset(markerX - arm, y + arm),
          Offset(markerX + arm, y - arm),
          mute,
        );
        continue;
      }
      final fret = shape.frets[string];
      if (fret <= 0) {
        canvas.drawCircle(Offset(markerX, y), hintRadius * 0.72, hollow);
        continue;
      }
      canvas.drawCircle(
        Offset(left + (fret + 0.5) * fretWidth, y),
        hintRadius,
        hollow,
      );
    }
  }

  double _markRadius(double bandHeight, double fretWidth) {
    final radius = math.min(bandHeight * 0.32, fretWidth * 0.28);
    return radius.clamp(4.0, 16.0);
  }

  bool _onBoard(FretTouch touch) {
    return touch.string >= 0 &&
        touch.string < DuoGuitar.stringCount &&
        touch.fret >= 0 &&
        touch.fret < DuoGuitar.fretCount;
  }

  @override
  bool shouldRepaint(covariant _FretboardPainter oldDelegate) {
    if (oldDelegate.touches.length != touches.length) {
      return true;
    }
    for (var i = 0; i < touches.length; i++) {
      final previous = oldDelegate.touches[i];
      final next = touches[i];
      if (previous.string != next.string || previous.fret != next.fret) {
        return true;
      }
    }
    if (oldDelegate.guide?.name != guide?.name) {
      return true;
    }
    return false;
  }
}
