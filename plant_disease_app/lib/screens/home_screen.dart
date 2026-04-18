// ─────────────────────────────────────────────
// screens/home_screen.dart
// Main dashboard. Large icon-based navigation
// grid designed for low-literacy farmers.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/sync_service.dart';
import '../widgets/language_selector.dart';
import 'camera_screen.dart';
import 'chat_screen.dart';
import 'crop_recommend_screen.dart';
import 'weather_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SyncStatus _syncStatus = SyncStatus.idle;

  @override
  void initState() {
    super.initState();
    _attemptSync();
  }

  Future<void> _attemptSync() async {
    final synced = await SyncService.instance.syncPendingReports();
    if (mounted && synced > 0) {
      setState(() => _syncStatus = SyncStatus.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l10n = provider.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // ── App Bar ────────────────────────────────
      appBar: AppBar(
        title: Text(l10n['app_name']),
        actions: [
          // Language selector
          const LanguageSelector(),
          // Sync status indicator
          if (_syncStatus == SyncStatus.syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          // Dark mode toggle
          IconButton(
            icon: Icon(
              provider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              provider.setThemeMode(
                provider.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
            },
          ),
        ],
      ),

      // ── Body ──────────────────────────────────
      body: Column(
        children: [
          // Welcome banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primary.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n['home_title'],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      l10n['no_internet'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Feature grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _FeatureCard(
                  icon: Icons.camera_alt_rounded,
                  label: l10n['detect_disease'],
                  color: const Color(0xFFE53935),
                  emoji: '🌿',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.eco_rounded,
                  label: l10n['crop_recommend'],
                  color: const Color(0xFF2E7D32),
                  emoji: '🌾',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CropRecommendScreen(),
                    ),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.chat_bubble_rounded,
                  label: l10n['chat_assistant'],
                  color: const Color(0xFF1565C0),
                  emoji: '🤖',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.wb_sunny_rounded,
                  label: l10n['weather'],
                  color: const Color(0xFFF57F17),
                  emoji: '🌤',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WeatherScreen()),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.history_rounded,
                  label: l10n['history'],
                  color: const Color(0xFF6A1B9A),
                  emoji: '📋',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                _FeatureCard(
                  icon: Icons.settings_rounded,
                  label: l10n['settings'],
                  color: const Color(0xFF37474F),
                  emoji: '⚙️',
                  onTap: () => _showSettings(context, provider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext ctx, AppProvider provider) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.l10n['settings'],
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: provider.themeMode == ThemeMode.dark,
                onChanged: (v) =>
                    provider.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(provider.l10n['language']),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: ctx,
                  builder: (_) => const LanguageSelectorDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature card widget ───────────────────────
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.emoji,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large emoji for low-literacy recognisability
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
