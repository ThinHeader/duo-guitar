import 'dart:async';

import 'package:duo_guitar/audio/strum_engine.dart';
import 'package:duo_guitar/protocol/fret_state.dart';
import 'package:duo_guitar/ui/body_page.dart';
import 'package:duo_guitar/ui/neck_page.dart';
import 'package:flutter/material.dart';

const _wood = Color(0xFF1A120B);
const _ink = Color(0xFFF3E6C8);

/// One window: neck touches update an in-memory fret state, body strums it.
class DebugDuoPage extends StatefulWidget {
  const DebugDuoPage({super.key});

  @override
  State<DebugDuoPage> createState() => _DebugDuoPageState();
}

class _DebugDuoPageState extends State<DebugDuoPage> {
  final ValueNotifier<FretState> _frets = ValueNotifier(FretState.open);
  final StrumEngine _engine = StrumEngine();
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
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
    _frets.dispose();
    unawaited(_engine.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _wood,
      appBar: AppBar(
        title: const Text('分屏调试'),
        backgroundColor: _wood,
        foregroundColor: _ink,
        surfaceTintColor: _wood,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFFAB91)),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: NeckPage(
                    embedded: true,
                    onFret: (state) => _frets.value = state,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFF5C4033),
                ),
                Expanded(
                  child: BodyPage(
                    embedded: true,
                    fretListenable: _frets,
                    onStrum: (state, string) {
                      unawaited(_engine.strum(state, string));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
