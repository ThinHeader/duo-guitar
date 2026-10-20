import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:duo_guitar/net/lan_ip.dart';
import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/protocol/packet.dart';
import 'package:flutter/foundation.dart';

/// Guitar-body UDP peer. Replies to discovery and tracks neck frets.
class UdpBodySession {
  UdpBodySession({String? roomCode, math.Random? random})
    : roomCode =
          roomCode ??
          (random ?? math.Random()).nextInt(10000).toString().padLeft(4, '0');

  /// Four-digit room code. A provided [roomCode] is kept as given.
  final String roomCode;

  final ValueNotifier<String> localIp = ValueNotifier('');
  final ValueNotifier<LinkStatus> status = ValueNotifier(LinkStatus.waiting);
  final ValueNotifier<FretState> frets = ValueNotifier(FretState.open);

  /// Bound UDP port. `0` until [start] finishes.
  int get boundPort => _boundPort;

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _timer;
  int _boundPort = 0;
  int _seq = 0;
  bool _closed = false;
  bool _seenPeer = false;
  bool _dropoutReported = false;
  DateTime? _lastPacketAt;
  int? _peerSeq;

  Future<void> start({
    int port = DuoGuitar.port,
    InternetAddress? bindAddress,
  }) async {
    final socket = await RawDatagramSocket.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
    _socket = socket;
    try {
      socket.broadcastEnabled = true;
      _boundPort = socket.port;
      localIp.value = await localLanIpv4();
      await acquireMulticastLock();
      _subscription = socket.listen(_onSocket, onError: (Object _) {});
      _timer = Timer.periodic(DuoGuitar.heartbeatInterval, _onTick);
    } on Object {
      await close();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    _socket?.close();
    _socket = null;
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
      _handleDatagram(socket, datagram);
      datagram = socket.receive();
    }
  }

  void _handleDatagram(RawDatagramSocket socket, Datagram datagram) {
    if (_closed) {
      return;
    }
    final packet = _tryDecode(datagram.data);
    if (packet == null || packet.roomCode != roomCode) {
      return;
    }
    switch (packet.type) {
      case PacketType.discover:
        _replyOffer(socket, datagram);
        return;
      case PacketType.fret:
      case PacketType.heartbeat:
        _acceptFrets(packet.frets, packet.seq);
        return;
      case PacketType.offer:
        return;
    }
  }

  void _replyOffer(RawDatagramSocket socket, Datagram datagram) {
    final reply = Packet(
      type: PacketType.offer,
      seq: _nextSeq(),
      roomCode: roomCode,
      frets: FretState.open,
    );
    socket.send(reply.encode(), datagram.address, datagram.port);
  }

  void _acceptFrets(FretState next, int seq) {
    if (!_isNewer(seq)) {
      return;
    }
    _peerSeq = seq;
    frets.value = next;
    status.value = LinkStatus.connected;
    _lastPacketAt = DateTime.now();
    _seenPeer = true;
    _dropoutReported = false;
  }

  /// Sequence numbers wrap at 16 bits. A gap of half the space or more is old.
  bool _isNewer(int seq) {
    final last = _peerSeq;
    if (last == null) {
      return true;
    }
    final delta = (seq - last) & 0xFFFF;
    return delta > 0 && delta < 0x8000;
  }

  /// One-shot: after a peer packet, drop the link once the silence exceeds
  /// [DuoGuitar.disconnectTimeout]. The next fret or heartbeat reconnects.
  void _onTick(Timer _) {
    if (_closed || !_seenPeer || _dropoutReported) {
      return;
    }
    final last = _lastPacketAt;
    if (last == null) {
      return;
    }
    if (DateTime.now().difference(last) > DuoGuitar.disconnectTimeout) {
      frets.value = FretState.open;
      status.value = LinkStatus.disconnected;
      _dropoutReported = true;
      _peerSeq = null;
    }
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
