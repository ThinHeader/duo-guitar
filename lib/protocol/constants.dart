/// Shared wire and instrument constants. Do not change without updating both peers.
abstract final class DuoGuitar {
  static const int port = 47821;

  static const int magic0 = 0xD6;
  static const int magic1 = 0x17;
  static const int version = 1;

  static const int stringCount = 6;
  static const int maxFret = 12;
  static const int fretCount = maxFret + 1;

  static const int packetLength = 16;

  static const Duration heartbeatInterval = Duration(milliseconds: 100);
  static const Duration disconnectTimeout = Duration(milliseconds: 500);

  /// Low E, A, D, G, B, high E.
  static const List<int> openMidi = [40, 45, 50, 55, 59, 64];
}

enum PacketType {
  discover(1),
  offer(2),
  fret(3),
  heartbeat(4),
  guide(5);

  const PacketType(this.code);

  final int code;

  static PacketType? fromCode(int code) {
    for (final type in PacketType.values) {
      if (type.code == code) {
        return type;
      }
    }
    return null;
  }
}

enum LinkStatus { waiting, connected, disconnected }
