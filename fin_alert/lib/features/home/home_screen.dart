import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/models/transaction_record.dart';
import '../../services/notification_service.dart';
import '../settings/settings.dart';
import '../tagging/tagging.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _syncing = false;
  String _status = '';

  Future<void> _sync({bool incremental = false}) async {
    setState(() {
      _syncing = true;
      _status = 'Syncing…';
    });
    final mailSync = ref.read(mailSyncServiceProvider);
    final before = await ref.read(transactionRepositoryProvider).needingReview();
    final summary = incremental
        ? await mailSync.syncIncremental(
            progress: (s, n) {
              if (mounted) setState(() => _status = '$s ($n)');
            },
          )
        : await mailSync.syncFull(
            progress: (s, n) {
              if (mounted) setState(() => _status = '$s ($n)');
            },
          );
    ref.invalidate(transactionsProvider);
    ref.invalidate(reviewQueueProvider);
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _status = summary.success
          ? 'Done: ${summary.parsed} parsed, ${summary.inserted} new'
          : (summary.error ?? 'Failed');
    });
    if (summary.success) {
      final after = await ref.read(transactionRepositoryProvider).needingReview();
      final delta = after.length - before.length;
      if (delta > 0) {
        await NotificationService.showNewTransactions(delta);
      }
    }
    if (mounted && summary.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_status)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncTx = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_syncing) const LinearProgressIndicator(),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_status, textAlign: TextAlign.center),
            ),
          Expanded(
            child: asyncTx.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('No transactions yet. Run a full sync.'),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return _TxTile(
                      t: t,
                      onTap: () => _openTag(context, t),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'inc',
            onPressed: _syncing ? null : () => _sync(incremental: true),
            child: const Icon(Icons.sync),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'full',
            onPressed: _syncing ? null : () => _sync(incremental: false),
            icon: const Icon(Icons.cloud_download),
            label: const Text('Full sync'),
          ),
        ],
      ),
    );
  }

  void _openTag(BuildContext context, TransactionRecord t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => TagTransactionSheet(transaction: t),
    ).then((_) {
      ref.invalidate(transactionsProvider);
      ref.invalidate(reviewQueueProvider);
    });
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.t, required this.onTap});

  final TransactionRecord t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd('en_IN').add_jm();
    final subtitle = [
      if (t.merchant != null) t.merchant,
      t.type,
      t.paymentMode,
      if (t.userCategory != null) '· ${t.userCategory}',
    ].whereType<String>().join(' · ');
    return ListTile(
      leading: CircleAvatar(
        child: Text(t.currency == 'INR' ? '₹' : r'$'),
      ),
      title: Text(
        '${t.amount.toStringAsFixed(2)} ${t.currency}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text('$subtitle\n${df.format(t.dateTime.toLocal())}'),
      isThreeLine: true,
      trailing: t.needsReview == 1
          ? const Icon(Icons.flag, color: Colors.orange)
          : null,
      onTap: onTap,
    );
  }
}
