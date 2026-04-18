// ─────────────────────────────────────────────
// widgets/language_selector.dart
// Compact language switcher shown in AppBar.
// Also exports LanguageSelectorDialog for
// full-screen language selection.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';

const Map<String, Map<String, String>> _languageInfo = {
  'en': {'label': 'English',  'native': 'English',  'flag': '🇮🇳'},
  'hi': {'label': 'Hindi',    'native': 'हिंदी',     'flag': '🇮🇳'},
  'pa': {'label': 'Punjabi',  'native': 'ਪੰਜਾਬੀ',    'flag': '🇮🇳'},
  'mr': {'label': 'Marathi',  'native': 'मराठी',     'flag': '🇮🇳'},
  'te': {'label': 'Telugu',   'native': 'తెలుగు',    'flag': '🇮🇳'},
};

// ── Compact icon button for AppBar ────────────
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final current  = provider.languageCode;

    return PopupMenuButton<String>(
      tooltip:       'Change Language',
      initialValue:  current,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          Text(
            current.toUpperCase(),
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      onSelected: (code) => provider.setLanguage(code),
      itemBuilder: (_) => AppConstants.supportedLanguages
          .map((code) {
            final info = _languageInfo[code]!;
            return PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Text(info['flag']!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(info['native']!,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(info['label']!,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  if (code == current) ...[
                    const Spacer(),
                    Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 18),
                  ],
                ],
              ),
            );
          })
          .toList(),
    );
  }
}

// ── Full-screen dialog ─────────────────────────
class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final scheme   = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Select Language'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppConstants.supportedLanguages.map((code) {
          final info    = _languageInfo[code]!;
          final current = provider.languageCode == code;

          return ListTile(
            leading: Text(info['flag']!, style: const TextStyle(fontSize: 24)),
            title:   Text(
              info['native']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(info['label']!),
            trailing: current
                ? Icon(Icons.check_circle, color: scheme.primary)
                : null,
            tileColor: current ? scheme.primary.withOpacity(0.08) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onTap: () {
              provider.setLanguage(code);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────
// widgets/voice_button.dart
// Animated microphone button used wherever
// voice input is needed.
// ─────────────────────────────────────────────

class VoiceButton extends StatefulWidget {
  const VoiceButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.size = 64,
  });

  final bool         isListening;
  final VoidCallback onTap;
  final double       size;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color  = widget.isListening ? Colors.red : scheme.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.scale(
          scale: widget.isListening ? _pulse.value : 1.0,
          child: child,
        ),
        child: Container(
          width:  widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: widget.isListening
                ? [
                    BoxShadow(
                      color:      color.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size:  widget.size * 0.45,
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────
// widgets/result_card.dart
// Reusable disease result summary card
// ─────────────────────────────────────────────

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.diseaseName,
    required this.confidence,
    required this.treatment,
    required this.isHealthy,
  });

  final String diseaseName;
  final double confidence;
  final String treatment;
  final bool   isHealthy;

  @override
  Widget build(BuildContext context) {
    final color  = isHealthy ? Colors.green : Colors.red;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disease badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                isHealthy ? '✅ Healthy' : '🚨 $diseaseName',
                style: TextStyle(
                  color:      color,
                  fontWeight: FontWeight.w700,
                  fontSize:   16,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Confidence bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Confidence',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color:      color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:           confidence,
                minHeight:       10,
                backgroundColor: color.withOpacity(0.12),
                valueColor:      AlwaysStoppedAnimation(color),
              ),
            ),

            const Divider(height: 24),

            // Treatment
            Text(
              treatment,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}