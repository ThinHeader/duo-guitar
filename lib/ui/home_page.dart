import 'package:duo_guitar/ui/body_page.dart';
import 'package:duo_guitar/ui/debug_duo_page.dart';
import 'package:duo_guitar/ui/neck_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _wood = Color(0xFF1A120B);
const _ink = Color(0xFFF3E6C8);
const _muted = Color(0xFFD9C7A6);
const _amber = Color(0xFFE0A100);

/// Picks the neck phone, the body phone, or a single-screen debug pair.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _wood,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '双琴',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '左边按品，右边扫弦。同一 Wi-Fi 下用房间码配对。',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 16),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _RoleButton(
                        title: '琴颈',
                        subtitle: '按住品位',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NeckPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleButton(
                        title: '琴身',
                        subtitle: '扫弦发声',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const BodyPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DebugDuoPage(),
                      ),
                    );
                  },
                  child: const Text(
                    '分屏调试',
                    style: TextStyle(color: _amber, fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2A2118),
        foregroundColor: _ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF5C4033)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _amber,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 16)),
        ],
      ),
    );
  }
}
