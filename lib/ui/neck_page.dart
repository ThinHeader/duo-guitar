import 'dart:async';
import 'dart:io';

import 'package:duo_guitar/ble/discovery.dart';

import 'package:duo_guitar/chords/chord_shape.dart';
import 'package:duo_guitar/net/udp_neck_session.dart';
import 'package:duo_guitar/practice/songs.dart';
import 'package:duo_guitar/protocol/constants.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/protocol/guide_cue.dart';
import 'package:duo_guitar/ui/practice_page.dart';
import 'package:duo_guitar/ui/widgets/fretboard.dart';
import 'package:flutter/foundation.dart';
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
  const NeckPage({
    super.key,
    this.embedded = false,
    this.onFret,
    this.cueListenable,
  });

  final bool embedded;
  final ValueChanged<FretState>? onFret;
  final ValueListenable<GuideCue?>? cueListenable;

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
  ChordShape? _hint;
  ChordShape? _practice;

  bool get _busy => _joining || _joined;

  @override
  void initState() {
    super.initState();
    widget.cueListenable?.addListener(_onExternalCue);
  }

  @override
  void didUpdateWidget(NeckPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cueListenable == widget.cueListenable) {
      return;
    }
    oldWidget.cueListenable?.removeListener(_onExternalCue);
    widget.cueListenable?.addListener(_onExternalCue);
  }

  void _onExternalCue() {
    _applyCue(widget.cueListenable?.value);
  }

  void _onSessionGuide() {
    _applyCue(_session?.guide.value);
  }

  void _applyCue(GuideCue? cue) {
    if (!mounted) {
      return;
    }
    if (cue == null) {
      if (_practice != null) {
        setState(() => _practice = null);
      }
      return;
    }
    final chord = chordForCue(songId: cue.songId, step: cue.step);
    if (chord == null) {
      return;
    }
    setState(() => _practice = chord);
  }

  void _toggleHint(ChordShape shape) {
    setState(() {
      _hint = _hint?.name == shape.name ? null : shape;
    });
  }

  Future<void> _join({bool bluetooth = false}) async {
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
      if (bluetooth) {
        if (!Platform.isAndroid) {
          throw StateError('蓝牙发现仅支持 Android');
        }
        final found = await findBodyIp(roomCode: roomCode);
        if (found == null) {
          throw StateError('未找到琴身');
        }
        await session.join(roomCode: roomCode, manualIp: found);
      } else if (ip.isEmpty) {
        try {
          await session.join(roomCode: roomCode);
        } on StateError {
          await _closeQuietly(session);
          _session = null;
          if (!Platform.isAndroid) {
            rethrow;
          }
          final found = await findBodyIp(roomCode: roomCode);
          if (found == null) {
            throw StateError('未找到琴身');
          }
          final retry = UdpNeckSession();
          _session = retry;
          await retry.join(roomCode: roomCode, manualIp: found);
        }
      } else {
        await session.join(roomCode: roomCode, manualIp: ip);
      }
      final joined = _session;
      if (joined == null) {
        return;
      }
      if (!mounted) {
        final pending = _session;
        _session = null;
        if (pending != null) {
          pending.guide.removeListener(_onSessionGuide);
          await _closeQuietly(pending);
        }
        return;
      }
      joined.guide.addListener(_onSessionGuide);
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
      session.guide.removeListener(_onSessionGuide);
      unawaited(session.close());
    }
    widget.cueListenable?.removeListener(_onExternalCue);
    _roomCode.dispose();
    _bodyIp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = Fretboard(
      onChanged: _onFret,
      guide: _practice ?? _hint,
    );
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
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy || !Platform.isAndroid
                            ? null
                            : () => _join(bluetooth: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2118),
                          foregroundColor: _ink,
                          disabledBackgroundColor: const Color(0xFF3D3128),
                          disabledForegroundColor: const Color(0xFF9A8874),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: _fieldRadius,
                          ),
                        ),
                        child: Text(
                          Platform.isAndroid ? '用蓝牙找琴身' : '蓝牙发现仅支持 Android',
                        ),
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
            const SizedBox(height: 4),
            _ChordChips(selected: _hint, onToggle: _toggleHint),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PracticePage(showFretboard: true),
                    ),
                  );
                },
                child: const Text(
                  '本地跟弹',
                  style: TextStyle(color: _amber),
                ),
              ),
            ),
            if (_practice != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  '跟弹 ${_practice!.name}',
                  style: const TextStyle(color: _amber, fontSize: 14),
                ),
              ),
            Expanded(child: board),
          ],
        ),
      ),
    );
  }
}

class _ChordChips extends StatelessWidget {
  const _ChordChips({required this.selected, required this.onToggle});

  final ChordShape? selected;
  final ValueChanged<ChordShape> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          for (final shape in ChordShape.hints) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(shape.name),
                  selected: selected?.name == shape.name,
                  onSelected: (_) => onToggle(shape),
                  selectedColor: _amber,
                  backgroundColor: _fieldFill,
                  labelStyle: TextStyle(
                    color: selected?.name == shape.name ? _wood : _ink,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
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
