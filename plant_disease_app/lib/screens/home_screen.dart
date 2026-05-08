import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sync_service.dart';
import '../widgets/language_selector.dart';
import 'auth_screen.dart';
import 'camera_screen.dart';
import 'chat_screen.dart';
import 'crop_recommend_screen.dart';
import 'history_screen.dart';
import 'weather_screen.dart';

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
    final result = await SyncService.instance.syncPendingData();
    if (!mounted) return;
    setState(() => _syncStatus = result.status);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final l10n = provider.l10n;
    final scheme = Theme.of(context).colorScheme;
    final items = [
      _FeatureItem(
        icon: Icons.camera_alt_rounded,
        label: l10n['detect_disease'],
        subtitle: l10n['feature_detect_subtitle'],
        color: const Color(0xFFE95D52),
        accent: const Color(0xFFFFE3DC),
        emoji: '🌿',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CameraScreen()),
        ),
      ),
      _FeatureItem(
        icon: Icons.eco_rounded,
        label: l10n['crop_recommend'],
        subtitle: l10n['feature_crop_subtitle'],
        color: const Color(0xFF2F8F46),
        accent: const Color(0xFFDDF4D6),
        emoji: '🌾',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CropRecommendScreen()),
        ),
      ),
      _FeatureItem(
        icon: Icons.chat_bubble_rounded,
        label: l10n['chat_assistant'],
        subtitle: l10n['feature_chat_subtitle'],
        color: const Color(0xFF2C78D0),
        accent: const Color(0xFFDCEBFF),
        emoji: '🤖',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        ),
      ),
      _FeatureItem(
        icon: Icons.wb_sunny_rounded,
        label: l10n['weather'],
        subtitle: l10n['feature_weather_subtitle'],
        color: const Color(0xFFE2A52A),
        accent: const Color(0xFFFFEFCC),
        emoji: '🌤️',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeatherScreen()),
        ),
      ),
      _FeatureItem(
        icon: Icons.history_rounded,
        label: l10n['history'],
        subtitle: l10n['feature_history_subtitle'],
        color: const Color(0xFF7A42C2),
        accent: const Color(0xFFEADFFF),
        emoji: '📋',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        ),
      ),
      _FeatureItem(
        icon: Icons.settings_rounded,
        label: l10n['settings'],
        subtitle: l10n['feature_settings_subtitle'],
        color: const Color(0xFF4B5F54),
        accent: const Color(0xFFE3ECE6),
        emoji: '⚙️',
        onTap: () => _showSettings(context, provider),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n['app_name']),
        actions: [
          const LanguageSelector(),
          if (_syncStatus == SyncStatus.syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: Icon(
              authProvider.isAuthenticated
                  ? Icons.verified_user_rounded
                  : Icons.login_rounded,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            ),
          ),
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (AppConstants.hasBackendBaseUrl)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _AuthStatusBanner(
                  isAuthenticated: authProvider.isAuthenticated,
                  email: authProvider.user?.email,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.92),
                      const Color(0xFFA6DB94),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n['home_title'],
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n['home_subtitle'],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoPill(
                          icon: Icons.camera_alt_rounded,
                          label: l10n['home_pill_scan'],
                        ),
                        _InfoPill(
                          icon: Icons.cloud_sync_rounded,
                          label: _statusLabel(_syncStatus, l10n),
                        ),
                        _InfoPill(
                          icon: Icons.translate_rounded,
                          label: l10n['home_pill_multilang'],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _FeatureCard(item: items[index]),
                childCount: items.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(SyncStatus status, AppL10n l10n) {
    switch (status) {
      case SyncStatus.syncing:
        return l10n['sync_in_progress'];
      case SyncStatus.success:
        return l10n['reports_synced'];
      case SyncStatus.partialSuccess:
        return l10n['partially_synced'];
      case SyncStatus.failed:
        return l10n['sync_needs_attention'];
      case SyncStatus.offline:
        return l10n['offline_mode'];
      case SyncStatus.idle:
        return l10n['ready_to_help'];
    }
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
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.brightness_6),
              title: Text(provider.l10n['dark_mode']),
              trailing: Switch(
                value: provider.themeMode == ThemeMode.dark,
                onChanged: (v) =>
                    provider.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
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

class _AuthStatusBanner extends StatelessWidget {
  const _AuthStatusBanner({
    required this.isAuthenticated,
    required this.email,
    required this.onTap,
  });

  final bool isAuthenticated;
  final String? email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isAuthenticated
              ? const Color(0xFFE3F4E8)
              : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isAuthenticated
                ? const Color(0xFF7AC690)
                : scheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isAuthenticated
                  ? Icons.shield_rounded
                  : Icons.lock_person_rounded,
              color: isAuthenticated
                  ? const Color(0xFF2F8F46)
                  : scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAuthenticated
                        ? 'Secure sync is on'
                        : 'Sign in to secure your synced reports',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAuthenticated
                        ? 'Signed in as ${email ?? 'your account'}.'
                        : 'Backend sync now uses your account session instead of one shared app token.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: [
                item.color.withValues(alpha: 0.16),
                item.color.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: item.color.withValues(alpha: 0.16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: item.accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 12),
                Icon(item.icon, color: item.color, size: 22),
                const SizedBox(height: 12),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: item.color,
                    height: 1.15,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    item.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: item.color.withValues(alpha: 0.8),
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      l10n['open_action'],
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: item.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: item.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.accent,
    required this.emoji,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color accent;
  final String emoji;
  final VoidCallback onTap;
}
