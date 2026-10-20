import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// Must match DuoGuitar.openMidi.
const List<int> openMidi = [40, 45, 50, 55, 59, 64];

const int sampleRate = 22050;
const double durationSeconds = 0.70;
const double fadeSeconds = 0.05;

/// Writes 78 Karplus-Strong WAV samples under assets/samples/.
///
/// Run from the project root. Uses only dart:io, dart:math, and dart:typed_data.
void main() {
  Directory('assets/samples').createSync(recursive: true);

  final sampleCount = (sampleRate * durationSeconds).round();
  final fadeSamples = (sampleRate * fadeSeconds).round();
  var written = 0;

  for (var string = 0; string < openMidi.length; string++) {
    for (var fret = 0; fret <= 12; fret++) {
      final wav = _renderWav(
        string: string,
        fret: fret,
        sampleCount: sampleCount,
        fadeSamples: fadeSamples,
      );
      File('assets/samples/s${string}_f$fret.wav').writeAsBytesSync(wav);
      written++;
    }
  }

  stdout.writeln(written);
}

double _frequency(int string, int fret) {
  final midi = openMidi[string];
  return (440 * pow(2, (midi + fret - 69) / 12)).toDouble();
}

Uint8List _renderWav({
  required int string,
  required int fret,
  required int sampleCount,
  required int fadeSamples,
}) {
  final n = max<int>(2, (sampleRate / _frequency(string, fret)).round());
  final random = Random(string * 13 + fret);
  final buffer = Float64List(n);
  for (var i = 0; i < n; i++) {
    buffer[i] = random.nextDouble() * 2 - 1;
  }

  final pcm = Int16List(sampleCount);
  final fadeStart = sampleCount - fadeSamples;
  var idx = 0;
  for (var i = 0; i < sampleCount; i++) {
    final sample = buffer[idx];
    buffer[idx] = 0.996 * 0.5 * (buffer[idx] + buffer[(idx + 1) % n]);
    var value = sample * 0.55;
    if (i >= fadeStart) {
      final span = fadeSamples <= 1 ? 1 : fadeSamples - 1;
      value *= (sampleCount - 1 - i) / span;
    }
    final scaled = (value * 32767).round().clamp(-32768, 32767).toInt();
    pcm[i] = scaled;
    idx = (idx + 1) % n;
  }

  return _wavBytes(pcm);
}

/// Canonical 44-byte PCM header, 22050 Hz, mono, 16-bit little endian.
Uint8List _wavBytes(Int16List pcm) {
  final dataBytes = pcm.length * 2;
  final bytes = ByteData(44 + dataBytes);
  _setAscii(bytes, 0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  _setAscii(bytes, 8, 'WAVE');
  _setAscii(bytes, 12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  _setAscii(bytes, 36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < pcm.length; i++) {
    bytes.setInt16(44 + i * 2, pcm[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void _setAscii(ByteData bytes, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    bytes.setUint8(offset + i, text.codeUnitAt(i));
  }
}
