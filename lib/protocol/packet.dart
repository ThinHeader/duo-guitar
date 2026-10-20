import 'dart:convert';
import 'dart:typed_data';

import 'constants.dart';
import 'fret_state.dart';

/// 16-byte UDP payload.
///
/// ```
/// 0     magic 0xD6
/// 1     magic 0x17
/// 2     version 1
/// 3     packet type
/// 4-5   uint16 sequence, big endian
/// 6-9   four ASCII room-code digits
/// 10-15 six fret bytes, each 0-12
/// ```
class Packet {
  const Packet({
    required this.type,
    required this.seq,
    required this.roomCode,
    required this.frets,
  });

  final PacketType type;
  final int seq;
  final String roomCode;
  final FretState frets;

  Uint8List encode() {
    if (!_isRoomCode(roomCode)) {
      throw ArgumentError.value(roomCode, 'roomCode', 'expected 4 digits');
    }
    final bytes = Uint8List(DuoGuitar.packetLength);
    final data = ByteData.sublistView(bytes);
    bytes[0] = DuoGuitar.magic0;
    bytes[1] = DuoGuitar.magic1;
    bytes[2] = DuoGuitar.version;
    bytes[3] = type.code;
    data.setUint16(4, seq & 0xFFFF);
    bytes.setRange(6, 10, ascii.encode(roomCode));
    for (var i = 0; i < DuoGuitar.stringCount; i++) {
      final fret = frets[i];
      if (fret < 0 || fret > DuoGuitar.maxFret) {
        throw ArgumentError.value(fret, 'frets[$i]', 'expected 0-12');
      }
      bytes[10 + i] = fret;
    }
    return bytes;
  }

  /// Returns null when the datagram is not a packet this app understands.
  static Packet? decode(Uint8List bytes) {
    if (bytes.length < DuoGuitar.packetLength) {
      return null;
    }
    if (bytes[0] != DuoGuitar.magic0 || bytes[1] != DuoGuitar.magic1) {
      return null;
    }
    if (bytes[2] != DuoGuitar.version) {
      return null;
    }
    final type = PacketType.fromCode(bytes[3]);
    if (type == null) {
      return null;
    }
    final seq = ByteData.sublistView(bytes).getUint16(4);
    final roomCode = ascii.decode(bytes.sublist(6, 10));
    if (!_isRoomCode(roomCode)) {
      return null;
    }
    final frets = List<int>.filled(DuoGuitar.stringCount, 0);
    for (var i = 0; i < DuoGuitar.stringCount; i++) {
      final fret = bytes[10 + i];
      if (fret > DuoGuitar.maxFret) {
        return null;
      }
      frets[i] = fret;
    }
    return Packet(type: type, seq: seq, roomCode: roomCode, frets: FretState(frets));
  }
}

bool _isRoomCode(String value) {
  return RegExp(r'^\d{4}$').hasMatch(value);
}
