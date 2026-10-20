import 'dart:async';
import 'dart:io';

import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/protocol/guide_cue.dart';
import 'package:duo_guitar/protocol/packet.dart';
import 'package:flutter/foundation.dart';

/// Guitar-neck UDP peer. Finds a body, then streams frets and heartbeats.
class UdpNeckSession {
  final ValueNotifier<LinkStatus> status = ValueNotifier(LinkStatus.waiting);
  final ValueNotifier<GuideCue?> guide = ValueNotifier(null);

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _heartbeat;
  Completer<void>? _offerCompleter;
  InternetAddress? _remote;
  int? _remotePort;
  String? _roomCode;
  FretState _latest = FretState.open;
  int _seq = 0;
  bool _closed = false;

  Future<void> join({
    required String roomCode,
    String? manualIp,
    int port = DuoGuitar.port,
    InternetAddress? broadcastAddress,
  }) async {
    if (!RegExp(r'^[0-9]{4}$').hasMatch(roomCode)) {
      throw ArgumentError.value(roomCode, 'roomCode', 'expected 4 digits');
    }
    _roomCode = roomCode;
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket = socket;
      socket.broadcastEnabled = true;
      _subscription = socket.listen(_onSocket, onError: (Object _) {});
      if (manualIp != null && manualIp.isNotEmpty) {
        _remote = InternetAddress(manualIp);
        _remotePort = port;
        status.value = LinkStatus.connected;
      } else {
        await _discover(
          socket,
          broadcastAddress ?? InternetAddress('255.255.255.255'),
          port,
        );
      }
      _heartbeat = Timer.periodic(
        DuoGuitar.heartbeatInterval,
        (_) => _sendHeartbeat(),
      );
    } on Object {
      await close();
      rethrow;
    }
  }

  /// Stores [state]. Sends it immediately once a body address is known.
  void send(FretState state) {
    _latest = state;
    final socket = _socket;
    final remote = _remote;
    final remotePort = _remotePort;
    if (_closed || socket == null || remote == null || remotePort == null) {
      return;
    }
    _write(socket, PacketType.fret, state, remote, remotePort);
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    _socket?.close();
    _socket = null;
  }

  Future<void> _discover(
    RawDatagramSocket socket,
    InternetAddress broadcastAddress,
    int port,
  ) async {
    final completer = Completer<void>();
    _offerCompleter = completer;
    final timeout = Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.completeError(StateError('未找到琴身'));
      }
    });
    Timer? resend;
    try {
      void ping() {
        if (_closed || completer.isCompleted) {
          return;
        }
        _write(
          socket,
          PacketType.discover,
          FretState.open,
          broadcastAddress,
          port,
        );
      }

      ping();
      resend = Timer.periodic(const Duration(milliseconds: 200), (_) {
        ping();
      });
      await completer.future;
    } finally {
      timeout.cancel();
      resend?.cancel();
      if (identical(_offerCompleter, completer)) {
        _offerCompleter = null;
      }
    }
  }

  void _onSocket(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _closed) {
      return;
    }
    final socket = _socket;
    if (socket == null) {
      return;
    }
    Datagram? datagram = socket.receive();
    while (datagram != null) {
      _handleDatagram(datagram);
      datagram = socket.receive();
    }
  }

  void _handleDatagram(Datagram datagram) {
    final packet = _tryDecode(datagram.data);
    if (packet == null || packet.roomCode != _roomCode) {
      return;
    }
    if (packet.type == PacketType.guide) {
      guide.value = packet.guide;
      return;
    }
    final pending = _offerCompleter;
    if (pending == null || pending.isCompleted) {
      return;
    }
    if (packet.type != PacketType.offer) {
      return;
    }
    _remote = datagram.address;
    _remotePort = datagram.port;
    status.value = LinkStatus.connected;
    pending.complete();
  }

  void _sendHeartbeat() {
    if (_closed) {
      return;
    }
    final socket = _socket;
    final remote = _remote;
    final remotePort = _remotePort;
    if (socket == null || remote == null || remotePort == null) {
      return;
    }
    _write(socket, PacketType.heartbeat, _latest, remote, remotePort);
  }

  void _write(
    RawDatagramSocket socket,
    PacketType type,
    FretState frets,
    InternetAddress address,
    int port,
  ) {
    final roomCode = _roomCode;
    if (_closed || roomCode == null) {
      return;
    }
    final packet = Packet(
      type: type,
      seq: _nextSeq(),
      roomCode: roomCode,
      frets: frets,
    );
    socket.send(packet.encode(), address, port);
  }

  int _nextSeq() {
    final current = _seq;
    _seq = (_seq + 1) & 0xFFFF;
    return current;
  }
}

Packet? _tryDecode(Uint8List bytes) {
  try {
    return Packet.decode(bytes);
  } on Object {
    return null;
  }
}
