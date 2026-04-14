import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_taxonomy.dart';
import '../../core/models/transaction_record.dart';
import '../../application/providers.dart';

class TagTransactionSheet extends ConsumerStatefulWidget {
  const TagTransactionSheet({super.key, required this.transaction});

  final TransactionRecord transaction;

  @override
  ConsumerState<TagTransactionSheet> createState() =>
      _TagTransactionSheetState();
}

class _TagTransactionSheetState extends ConsumerState<TagTransactionSheet> {
  final _search = TextEditingController();
  String _query = '';
  late TransactionRecord _undoSnapshot;

  @override
  void initState() {
    super.initState();
    _undoSnapshot = widget.transaction;
    _search.addListener(() {
      setState(() => _query = _search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _apply(IconEntry entry) async {
    final repo = ref.read(transactionRepositoryProvider);
    final csv = ref.read(transactionCsvExporterProvider);
    await repo.updateTag(
      transactionId: widget.transaction.transactionId,
      userCategory: entry.label,
      iconId: entry.id,
      clearNeedsReview: true,
    );
    await csv.exportAllAtomic();
    ref.invalidate(transactionsProvider);
    ref.invalidate(reviewQueueProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tagged as ${entry.label}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repo.updateTag(
              transactionId: _undoSnapshot.transactionId,
              userCategory: _undoSnapshot.userCategory,
              iconId: _undoSnapshot.iconId,
              needsReview: _undoSnapshot.needsReview,
              clearNeedsReview: false,
            );
            await csv.exportAllAtomic();
            ref.invalidate(transactionsProvider);
            ref.invalidate(reviewQueueProvider);
          },
        ),
        duration: const Duration(seconds: 8),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final top = IconTaxonomy.suggestionsForCategory(
      widget.transaction.inferredCategory,
    );
    final searchResults = IconTaxonomy.search(_query);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tag transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.transaction.amount} ${widget.transaction.currency}'
                '${widget.transaction.merchant != null ? ' · ${widget.transaction.merchant}' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search icons (try “food”)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _query.isEmpty ? 'Suggestions' : 'Matches',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: (_query.isEmpty ? top : searchResults)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () => _apply(e),
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 88,
                              child: Card(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(e.icon, size: 36),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
