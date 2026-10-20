import 'dart:io';

import 'package:duo_guitar/net/udp_body_session.dart';
import 'package:duo_guitar/net/udp_neck_session.dart';
import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual ip delivers frets then disconnects', () async {
    final body = UdpBodySession();
    final neck = UdpNeckSession();
    try {
      await body.start(bindAddress: InternetAddress('127.0.0.1'), port: 0);
      expect(neck.status.value, LinkStatus.waiting);
      await neck.join(
        roomCode: body.roomCode,
        manualIp: '127.0.0.1',
        port: body.boundPort,
      );
      neck.send(const FretState([3, 0, 0, 0, 0, 0]));
      await _pollUntil(
        () =>
            body.frets.value[0] == 3 &&
            body.status.value == LinkStatus.connected,
      );
      expect(body.frets.value[0], 3);
      expect(body.status.value, LinkStatus.connected);

      await neck.close();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(body.frets.value, FretState.open);
      expect(body.status.value, LinkStatus.disconnected);
    } finally {
      await neck.close();
      await body.close();
    }
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('discovery connects for the matching room', () async {
    final body = UdpBodySession();
    final neck = UdpNeckSession();
    try {
      await body.start(bindAddress: InternetAddress('127.0.0.1'), port: 0);
      expect(neck.status.value, LinkStatus.waiting);
      await neck.join(
        roomCode: body.roomCode,
        port: body.boundPort,
        broadcastAddress: InternetAddress('127.0.0.1'),
      );
      expect(neck.status.value, LinkStatus.connected);
    } finally {
      await body.close();
      await neck.close();
    }
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('wrong room code discover does not connect', () async {
    final body = UdpBodySession();
    final neck = UdpNeckSession();
    Object? caught;
    try {
      await body.start(bindAddress: InternetAddress('127.0.0.1'), port: 0);
      final wrong = body.roomCode == '0000' ? '0001' : '0000';
      try {
        await neck.join(
          roomCode: wrong,
          port: body.boundPort,
          broadcastAddress: InternetAddress('127.0.0.1'),
        );
      } catch (error) {
        caught = error;
      }
    } finally {
      await neck.close();
      await body.close();
    }
    expect(caught, isA<StateError>());
    expect((caught! as StateError).message, '未找到琴身');
  }, timeout: const Timeout(Duration(seconds: 10)));
}

Future<void> _pollUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (true) {
    if (done()) {
      return;
    }
    if (!DateTime.now().isBefore(deadline)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
