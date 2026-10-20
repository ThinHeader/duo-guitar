import 'dart:async';

import 'package:duo_guitar/net/udp_neck_session.dart';
import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/ui/widgets/fretboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _wood = Color(0xFF1A120B);
const _ink = Color(0xFFF3E6C8);
const _fieldFill = Color(0xFF2A2118);
const _fieldLabel = Color(0xFFD9C7A6);
const _amber = Color(0xFFE0A100);
const _errorColor = Color(0xFFFFAB91);

const _fieldRadius = BorderRadius.all(Radius.circular(8));

/// Phone neck role, or the fretboard half of a debug split screen.
///
/// [embedded] draws only the fretboard and forwards [onFret]. Otherwise the
/// page joins a room and sends fret changes through [UdpNeckSession].
class NeckPage extends StatefulWidget {
  const NeckPage({super.key, this.embedded = false, this.onFret});

  final bool embedded;
  final ValueChanged<FretState>? onFret;

  @override
  State<NeckPage> createState() => _NeckPageState();
}

class _NeckPageState extends State<NeckPage> {
  final TextEditingController _roomCode = TextEditingController();
  final TextEditingController _bodyIp = TextEditingController();

  UdpNeckSession? _session;
  var _joining = false;
  var _joined = false;
  String? _error;

  bool get _busy => _joining || _joined;

  Future<void> _join() async {
    if (widget.embedded || _joining || _joined) {
      return;
    }

    final roomCode = _roomCode.text.trim();
    final ip = _bodyIp.text.trim();
    _joining = true;
    if (mounted) {
      setState(() => _error = null);
    }

    try {
      final session = UdpNeckSession();
      _session = session;
      if (ip.isEmpty) {
        await session.join(roomCode: roomCode);
      } else {
        await session.join(roomCode: roomCode, manualIp: ip);
      }
      if (!mounted) {
        final pending = _session;
        _session = null;
        if (pending != null) {
          await _closeQuietly(pending);
        }
        return;
      }
      setState(() => _joined = true);
    } catch (e) {
      final failed = _session;
      _session = null;
      _joined = false;
      if (failed != null) {
        await _closeQuietly(failed);
      }
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      _joining = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onFret(FretState state) {
    if (!widget.embedded && _joined) {
      _session?.send(state);
    }
    widget.onFret?.call(state);
  }

  Future<void> _closeQuietly(UdpNeckSession session) async {
    try {
      await session.close();
    } catch (_) {
      // Keep the join error on screen.
    }
  }

  @override
  void dispose() {
    _joined = false;
    final session = _session;
    _session = null;
    if (session != null) {
      unawaited(session.close());
    }
    _roomCode.dispose();
    _bodyIp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = Fretboard(onChanged: _onFret);
    if (widget.embedded) {
      return board;
    }

    final session = _session;
    return Scaffold(
      backgroundColor: _wood,
      appBar: AppBar(
        title: const Text('琴颈'),
        backgroundColor: _wood,
        foregroundColor: _ink,
        surfaceTintColor: _wood,
        titleTextStyle: const TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: _ink),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        flex: 2,
                        child: _NeckField(
                          controller: _roomCode,
                          label: '房间码',
                          enabled: !_busy,
                          digits: true,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 3,
                        child: _NeckField(
                          controller: _bodyIp,
                          label: '琴身 IP',
                          enabled: !_busy,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _join(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy ? null : _join,
                        style: FilledButton.styleFrom(
                          backgroundColor: _amber,
                          foregroundColor: _wood,
                          disabledBackgroundColor: const Color(0xFF3D3128),
                          disabledForegroundColor: const Color(0xFF9A8874),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: _fieldRadius,
                          ),
                        ),
                        child: const Text('加入'),
                      ),
                    ],
                  ),
                  if (_joined && session != null) ...[
                    const SizedBox(height: 6),
                    _LinkStatusText(status: session.status),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _errorColor, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: board),
          ],
        ),
      ),
    );
  }
}

class _LinkStatusText extends StatelessWidget {
  const _LinkStatusText({required this.status});

  final ValueNotifier<LinkStatus> status;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LinkStatus>(
      valueListenable: status,
      builder: (context, value, _) {
        return Text(
          switch (value) {
            LinkStatus.waiting => '等待连接',
            LinkStatus.connected => '已连接',
            LinkStatus.disconnected => '已断开',
          },
          style: TextStyle(
            color: switch (value) {
              LinkStatus.waiting => _amber,
              LinkStatus.connected => const Color(0xFFC6E2A0),
              LinkStatus.disconnected => const Color(0xFFE7A090),
            },
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

class _NeckField extends StatelessWidget {
  const _NeckField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.digits = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool digits;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: digits ? TextInputType.number : TextInputType.text,
      textInputAction: textInputAction,
      textAlign: digits ? TextAlign.center : TextAlign.start,
      autocorrect: false,
      enableSuggestions: false,
      cursorColor: _amber,
      style: const TextStyle(color: _ink, fontSize: 16),
      inputFormatters: digits
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ]
          : null,
      decoration: _decoration(label),
      onSubmitted: onSubmitted,
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: _fieldFill,
      labelStyle: const TextStyle(color: _fieldLabel),
      floatingLabelStyle: const TextStyle(color: _amber),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: Color(0xFF5C4033)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: Color(0xFF5C4033)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: _amber, width: 1.4),
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: Color(0xFF3A2C22)),
      ),
    );
  }
}
