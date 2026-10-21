import 'dart:async';

import 'package:duo_guitar/audio/strum_engine.dart';
import 'package:duo_guitar/ble/discovery.dart';
import 'package:duo_guitar/net/udp_body_session.dart';
import 'package:duo_guitar/ui/practice_page.dart';
import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/ui/widgets/string_bed.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _wood = Color(0xFF1A120B);
const _ink = Color(0xFFF3E6C8);
const _amber = Color(0xFFE0A100);
const _errorColor = Color(0xFFFFAB91);

/// Strumming page. A standalone page owns the UDP session and the synth.
class BodyPage extends StatefulWidget {
  const BodyPage({
    super.key,
    this.embedded = false,
    this.fretListenable,
    this.onStrum,
  });

  final bool embedded;
  final ValueListenable<FretState>? fretListenable;
  final void Function(FretState state, int stringIndex)? onStrum;

  @override
  State<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends State<BodyPage> {
  late final UdpBodySession _session;
  late final StrumEngine _engine;
  final BodyAdvertiser _advertiser = BodyAdvertiser();
  var _live = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.embedded) {
      return;
    }
    _live = true;
    _session = UdpBodySession();
    _engine = StrumEngine();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await _session.start();
      if (!mounted) {
        return;
      }
      await _advertiser.start(
        roomCode: _session.roomCode,
        ip: _session.localIp.value,
      );
      await _engine.init();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    if (_live) {
      unawaited(_session.close());
      unawaited(_advertiser.stop());
      unawaited(_engine.dispose());
    }
    super.dispose();
  }

  void _onStrike(int string) {
    final state = _session.frets.value;
    unawaited(_strum(state, string));
    widget.onStrum?.call(state, string);
  }

  Future<void> _strum(FretState state, int string) async {
    try {
      await _engine.strum(state, string);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    }
  }

  void _onEmbeddedStrike(int string) {
    final frets = widget.fretListenable?.value ?? FretState.open;
    widget.onStrum?.call(frets, string);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildEmbedded();
    }
    return Scaffold(
      backgroundColor: _wood,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _session.localIp,
            _session.status,
            _session.frets,
          ]),
          builder: (context, _) => _buildLive(),
        ),
      ),
    );
  }

  Widget _buildLive() {
    final ip = _session.localIp.value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: _ink),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Text(
                  _session.roomCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _ipLabel(ip),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _ink, fontSize: 11, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  _linkLabel(_session.status.value),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _linkColor(_session.status.value),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _errorColor, fontSize: 11),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PracticePage(
                          session: _session,
                          engine: _engine,
                          showStrings: true,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('练习', style: TextStyle(color: _amber)),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF3D2B1C)),
        Expanded(
          child: StringBed(
            frets: _session.frets.value,
            onStrike: _onStrike,
          ),
        ),
      ],
    );
  }

  Widget _buildEmbedded() {
    return ColoredBox(
      color: _wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              '琴身',
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: _embeddedBed()),
        ],
      ),
    );
  }

  Widget _embeddedBed() {
    final listenable = widget.fretListenable;
    if (listenable == null) {
      return StringBed(
        frets: FretState.open,
        onStrike: _onEmbeddedStrike,
      );
    }
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        return StringBed(
          frets: listenable.value,
          onStrike: _onEmbeddedStrike,
        );
      },
    );
  }
}

String _ipLabel(String ip) {
  if (ip.isEmpty || ip == '0.0.0.0') {
    return '无局域网 IP';
  }
  return ip;
}

String _linkLabel(LinkStatus status) {
  switch (status) {
    case LinkStatus.waiting:
      return '等待琴颈';
    case LinkStatus.connected:
      return '已连接';
    case LinkStatus.disconnected:
      return '琴颈已断开';
  }
}

Color _linkColor(LinkStatus status) {
  switch (status) {
    case LinkStatus.waiting:
      return _amber;
    case LinkStatus.connected:
      return const Color(0xFFC6E2A0);
    case LinkStatus.disconnected:
      return const Color(0xFFE7A090);
  }
}
