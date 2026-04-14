import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../onboarding/onboarding.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final pathAsync = ref.watch(exportPathProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Allow cloud parsing'),
            subtitle: const Text('Requires backend URL in onboarding or here later.'),
            value: config.allowCloudParse,
            onChanged: (v) async {
              await config.setAllowCloudParse(v);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            title: const Text('Sync window (months)'),
            subtitle: Text('${config.syncWindowMonths}'),
            onTap: () async {
              final m = await _pickMonths(context, config.syncWindowMonths);
              if (m != null) await config.setSyncWindowMonths(m);
            },
          ),
          pathAsync.when(
            data: (p) => ListTile(
              title: const Text('CSV export path'),
              subtitle: Text(p, style: const TextStyle(fontSize: 12)),
            ),
            loading: () => const ListTile(title: Text('CSV path…')),
            error: (e, _) => ListTile(title: Text('Path error: $e')),
          ),
          ListTile(
            title: const Text('Re-run onboarding'),
            onTap: () async {
              await config.setOnboardingDone(false);
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const OnboardingScreen(),
                ),
                (_) => false,
              );
            },
          ),
          ListTile(
            title: Text(
              'Clear local data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete all local data?'),
                  content: const Text(
                    'Removes transactions from this device. '
                    'Gmail access can be revoked in Google account settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(transactionRepositoryProvider).clearAllData();
                await ref.read(transactionCsvExporterProvider).exportAllAtomic();
                ref.invalidate(transactionsProvider);
                ref.invalidate(reviewQueueProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local data cleared')),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('Sign out Google'),
            onTap: () async {
              await ref.read(mailSyncServiceProvider).signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  static Future<int?> _pickMonths(BuildContext context, int current) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sync window'),
        children: [3, 6, 12, 120]
            .map(
              (m) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, m),
                child: Text(
                  m >= 120 ? 'All (~10 yr)' : '$m months',
                  style: TextStyle(
                    fontWeight: m == current ? FontWeight.bold : null,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
