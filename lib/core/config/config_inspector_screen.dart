import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../../shared/widgets/gritty_background.dart';
import '../../shared/widgets/primitives.dart';
import 'remote_config.dart';

/// Debug-only view of the resolved remote config.
///
/// This exists because "is the config working?" is otherwise unanswerable
/// from inside the app: a key the server never sent and a key the server
/// sent with the same value as the default look identical on screen. Here
/// each row states its **source** — SERVER when the payload carried the key,
/// DEFAULT when it fell through to the compiled-in value — so a failed
/// rollout is visible rather than inferred.
///
/// Compiled out of release builds by the guard in [ConfigInspectorScreen.isAvailable].
class ConfigInspectorScreen extends StatefulWidget {
  const ConfigInspectorScreen({super.key});

  static const String routeName = '/dev/config';

  /// Debug and profile builds only. A config inspector in a shipped app is
  /// an invitation to screenshot internal flag names.
  static bool get isAvailable {
    bool debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }

  @override
  State<ConfigInspectorScreen> createState() => _ConfigInspectorScreenState();
}

class _ConfigInspectorScreenState extends State<ConfigInspectorScreen> {
  bool _refreshing = false;
  String? _lastResult;

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _lastResult = null;
    });
    final ok = await config.refresh();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _lastResult = ok
          ? 'Fetched and cached.'
          : 'Fetch failed — showing cached/default values.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final overrides = config.activeOverrides;
    final keys = RemoteConfig.knownKeys;

    // Keys the server sent that the app has no reader for. Surfacing these
    // catches the most common rollout mistake: a value set under a name that
    // nothing in the app looks up.
    final unread =
        overrides.keys
            .where((k) => !RemoteConfig.defaults.containsKey(k))
            .toList()
          ..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GrittyBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.mdLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconTile(
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 15,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: AppSpacing.mdLg),
                        Text(
                          'Remote config',
                          style: AppText.sans(
                            21,
                            weight: FontWeight.w500,
                            color: AppColors.text,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.mdLg),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                            color: config.isFresh
                                ? AppColors.tealSurface
                                : AppColors.elevated,
                          ),
                          child: MonoLabel(
                            config.isFresh ? 'LIVE THIS SESSION' : 'CACHED',
                            size: 8.5,
                            letterSpacing: 1.2,
                            color: config.isFresh
                                ? AppColors.teal
                                : AppColors.textFaint,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        MonoLabel(
                          '${overrides.length} FROM SERVER · ${keys.length} READ BY APP',
                          size: 8.5,
                          letterSpacing: 1.1,
                          color: AppColors.textFaint,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.mdLg),
                    GoldButton(
                      label: 'Re-fetch now',
                      icon: Icons.refresh_rounded,
                      loading: _refreshing,
                      onTap: _refresh,
                    ),
                    if (_lastResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          _lastResult!,
                          style: AppText.sans(11.5, color: AppColors.textDim),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: [
                    for (final key in keys)
                      _ConfigRow(
                        configKey: key,
                        value: overrides.containsKey(key)
                            ? overrides[key]
                            : RemoteConfig.defaults[key],
                        fromServer: overrides.containsKey(key),
                      ),
                    if (unread.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const MonoLabel(
                        'SENT BY SERVER, NOT READ BY THE APP',
                        size: 9,
                        letterSpacing: 1.4,
                        color: AppColors.textFaint,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final key in unread)
                        _ConfigRow(
                          configKey: key,
                          value: overrides[key],
                          fromServer: true,
                          orphan: true,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String configKey;
  final Object? value;
  final bool fromServer;
  final bool orphan;

  const _ConfigRow({
    required this.configKey,
    required this.value,
    required this.fromServer,
    this.orphan = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color tagColor = orphan
        ? AppColors.destructive
        : (fromServer ? AppColors.teal : AppColors.textFaint);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OutlinedSurface(
        onTap: () {
          Clipboard.setData(ClipboardData(text: configKey));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied "$configKey"'),
              backgroundColor: AppColors.elevated,
              duration: const Duration(seconds: 1),
            ),
          );
        },
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.mdLg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    configKey,
                    style: AppText.mono(11, ls: 0, c: AppColors.text),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                MonoLabel(
                  orphan ? 'UNREAD' : (fromServer ? 'SERVER' : 'DEFAULT'),
                  size: 8,
                  letterSpacing: 1.1,
                  color: tagColor,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: AppText.mono(10.5, ls: 0, c: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
