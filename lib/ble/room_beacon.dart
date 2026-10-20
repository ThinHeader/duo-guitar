import 'dart:typed_data';

/// Advertisement payload: magic, four room-code digits, four IPv4 octets.
class RoomBeacon {
  const RoomBeacon({required this.roomCode, required this.ip});

  static const int magic0 = 0xD6;
  static const int magic1 = 0x17;
  static const int length = 10;

  final String roomCode;
  final String ip;

  Uint8List encode() {
    final octets = _octets(ip);
    if (octets == null) {
      throw ArgumentError.value(ip, 'ip', 'expected IPv4');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(roomCode)) {
      throw ArgumentError.value(roomCode, 'roomCode', 'expected 4 digits');
    }
    final bytes = Uint8List(length);
    bytes[0] = magic0;
    bytes[1] = magic1;
    for (var i = 0; i < 4; i++) {
      bytes[2 + i] = roomCode.codeUnitAt(i);
    }
    bytes.setRange(6, 10, octets);
    return bytes;
  }

  static RoomBeacon? decode(List<int> bytes) {
    if (bytes.length < length) {
      return null;
    }
    if (bytes[0] != magic0 || bytes[1] != magic1) {
      return null;
    }
    final room = String.fromCharCodes(bytes.sublist(2, 6));
    if (!RegExp(r'^\d{4}$').hasMatch(room)) {
      return null;
    }
    final ip = '${bytes[6]}.${bytes[7]}.${bytes[8]}.${bytes[9]}';
    return RoomBeacon(roomCode: room, ip: ip);
  }
}

List<int>? _octets(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) {
    return null;
  }
  final octets = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) {
      return null;
    }
    octets.add(value);
  }
  return octets;
}
