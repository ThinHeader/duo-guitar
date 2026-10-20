import 'dart:typed_data';

import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/protocol/packet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fret packet roundtrip', () {
    const packet = Packet(
      type: PacketType.fret,
      seq: 7,
      roomCode: '1234',
      frets: FretState([0, 1, 2, 3, 4, 5]),
    );
    final bytes = packet.encode();
    expect(bytes.length, DuoGuitar.packetLength);
    final decoded = Packet.decode(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.type, PacketType.fret);
    expect(decoded.seq, 7);
    expect(decoded.roomCode, '1234');
    expect(decoded.frets, const FretState([0, 1, 2, 3, 4, 5]));
  });

  test('discover packet roundtrip', () {
    const packet = Packet(
      type: PacketType.discover,
      seq: 1,
      roomCode: '4321',
      frets: FretState.open,
    );
    final decoded = Packet.decode(packet.encode());
    expect(decoded, isNotNull);
    expect(decoded!.type, PacketType.discover);
    expect(decoded.seq, 1);
    expect(decoded.roomCode, '4321');
    expect(decoded.frets, FretState.open);
  });

  test('decode rejects malformed datagrams', () {
    final valid = const Packet(
      type: PacketType.fret,
      seq: 1,
      roomCode: '1234',
      frets: FretState.open,
    ).encode();

    expect(Packet.decode(Uint8List.sublistView(valid, 0, 15)), isNull);

    final badMagic = Uint8List.fromList(valid);
    badMagic[0] = 0x00;
    expect(Packet.decode(badMagic), isNull);

    final badVersion = Uint8List.fromList(valid);
    badVersion[2] = 0;
    expect(Packet.decode(badVersion), isNull);

    final badFret = Uint8List.fromList(valid);
    badFret[13] = 13;
    expect(Packet.decode(badFret), isNull);

    final badRoom = Uint8List.fromList(valid);
    badRoom[6] = 0x41;
    expect(Packet.decode(badRoom), isNull);
  });

  test('encode throws on short room code', () {
    const packet = Packet(
      type: PacketType.discover,
      seq: 0,
      roomCode: '12',
      frets: FretState.open,
    );
    expect(packet.encode, throwsArgumentError);
  });
}
