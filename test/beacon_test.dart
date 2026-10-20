import 'dart:typed_data';

import 'package:duo_guitar/ble/room_beacon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beacon roundtrip keeps the room code and ip', () {
    const beacon = RoomBeacon(roomCode: '1357', ip: '192.168.1.20');
    final decoded = RoomBeacon.decode(beacon.encode());
    expect(decoded, isNotNull);
    expect(decoded!.roomCode, '1357');
    expect(decoded.ip, '192.168.1.20');
  });

  test('beacon decode rejects a bad magic or short buffer', () {
    final bytes = const RoomBeacon(roomCode: '1357', ip: '10.0.0.2').encode();
    expect(RoomBeacon.decode(bytes.sublist(0, 9)), isNull);
    final badMagic = Uint8List.fromList(bytes);
    badMagic[0] = 0;
    expect(RoomBeacon.decode(badMagic), isNull);
  });
}
