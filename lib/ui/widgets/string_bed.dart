import 'package:duo_guitar/input/strum_detector.dart';
import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:flutter/material.dart';

const _wood = Color(0xFF1A120B);
const _string = Color(0xFFE6D3A3);
const _amber = Color(0xFFE0A100);
const _dim = Color(0xFF9A8874);

const _frettedLabel = TextStyle(
  color: _amber,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

const _openLabel = TextStyle(
  color: _dim,
  fontSize: 16,
);

/// Six horizontal strings. A vertical stroke strikes each string it crosses.
class StringBed extends StatefulWidget {
  const StringBed({super.key, required this.frets, required this.onStrike});

  final FretState frets;
  final ValueChanged<int> onStrike;

  @override
  State<StringBed> createState() => _StringBedState();
}

class _StringBedState extends State<StringBed> {
  final StrumDetector _detector = StrumDetector(
    stringCount: DuoGuitar.stringCount,
  );

  void _move(PointerEvent event, double height) {
    final hits = _detector.move(
      pointer: event.pointer,
      y: event.localPosition.dy,
      height: height,
    );
    for (final string in hits) {
      widget.onStrike(string);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        if (height <= 0 || width <= 0) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: width,
          height: height,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _move(event, height),
            onPointerMove: (event) => _move(event, height),
            onPointerUp: (event) => _detector.end(event.pointer),
            onPointerCancel: (event) => _detector.end(event.pointer),
            child: ColoredBox(
              color: _wood,
              child: CustomPaint(
                painter: _StringBedPainter(frets: widget.frets),
                child: Column(
                  children: [
                    for (var i = 0; i < DuoGuitar.stringCount; i++)
                      Expanded(child: _FretLabel(fret: widget.frets[i])),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FretLabel extends StatelessWidget {
  const _FretLabel({required this.fret});

  final int fret;

  @override
  Widget build(BuildContext context) {
    final fretted = fret > 0;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 48,
        child: Text(
          fretted ? '$fret' : '空',
          textAlign: TextAlign.center,
          style: fretted ? _frettedLabel : _openLabel,
        ),
      ),
    );
  }
}

class _StringBedPainter extends CustomPainter {
  const _StringBedPainter({required this.frets});

  final FretState frets;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) {
      return;
    }
    final paint = Paint()..strokeCap = StrokeCap.round;
    final start = size.width < 56 ? 0.0 : 56.0;
    final end = size.width <= start + 12 ? size.width : size.width - 12;
    for (var i = 0; i < DuoGuitar.stringCount; i++) {
      final y = (i + 0.5) / DuoGuitar.stringCount * size.height;
      paint
        ..color = frets[i] > 0 ? _amber : _string
        ..strokeWidth = 3.2 - i * 0.28;
      canvas.drawLine(Offset(start, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StringBedPainter oldDelegate) {
    return oldDelegate.frets != frets;
  }
}
