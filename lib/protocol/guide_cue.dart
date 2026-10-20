import 'dart:typed_data';

/// Practice step carried in the six payload bytes of a guide packet.
class GuideCue {
  const GuideCue({
    required this.songId,
    required this.step,
    required this.beatInChord,
    required this.bpm,
    required this.accent,
  });

  final int songId;
  final int step;
  final int beatInChord;
  final int bpm;
  final bool accent;

  Uint8List get bytes {
    final data = ByteData(6);
    data.setUint8(0, songId & 0xFF);
    data.setUint16(1, step & 0xFFFF);
    data.setUint8(3, beatInChord & 0xFF);
    data.setUint8(4, bpm & 0xFF);
    data.setUint8(5, accent ? 1 : 0);
    return data.buffer.asUint8List();
  }

  static GuideCue fromBytes(List<int> bytes) {
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return GuideCue(
      songId: data.getUint8(0),
      step: data.getUint16(1),
      beatInChord: data.getUint8(3),
      bpm: data.getUint8(4),
      accent: data.getUint8(5) == 1,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GuideCue &&
        other.songId == songId &&
        other.step == step &&
        other.beatInChord == beatInChord &&
        other.bpm == bpm &&
        other.accent == accent;
  }

  @override
  int get hashCode => Object.hash(songId, step, beatInChord, bpm, accent);
}
