import 'package:flutter/material.dart';

class IconEntry {
  const IconEntry({
    required this.id,
    required this.label,
    required this.icon,
    this.keywords = const [],
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> keywords;
}

/// Local taxonomy: keyword → icon suggestions for typeahead + chips.
class IconTaxonomy {
  static final List<IconEntry> all = [
    const IconEntry(
      id: 'food',
      label: 'Food',
      icon: Icons.restaurant,
      keywords: [
        'food',
        'foo',
        'eat',
        'dining',
        'swiggy',
        'zomato',
        'eatfit',
        'faasos',
      ],
    ),
    const IconEntry(
      id: 'groceries',
      label: 'Groceries',
      icon: Icons.local_grocery_store,
      keywords: [
        'grocery',
        'mart',
        'bigbasket',
        'blinkit',
        'jiomart',
        'dunzo',
        'grofers',
      ],
    ),
    const IconEntry(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_car,
      keywords: [
        'uber',
        'ola',
        'rapido',
        'fuel',
        'petrol',
        'diesel',
        'metro',
        'irctc',
        'fastag',
        'toll',
      ],
    ),
    const IconEntry(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag,
      keywords: [
        'amazon',
        'flipkart',
        'myntra',
        'nykaa',
        'meesho',
        'mall',
        'shop',
      ],
    ),
    const IconEntry(
      id: 'bills',
      label: 'Bills',
      icon: Icons.receipt_long,
      keywords: [
        'bill',
        'electric',
        'bescom',
        'mseb',
        'wifi',
        'broadband',
        'jio',
        'airtel',
        'recharge',
        'rent',
        'society',
      ],
    ),
    const IconEntry(
      id: 'entertainment',
      label: 'Entertainment',
      icon: Icons.movie,
      keywords: [
        'netflix',
        'spotify',
        'movie',
        'game',
        'bookmyshow',
        'hotstar',
        'sonyliv',
      ],
    ),
    const IconEntry(
      id: 'health',
      label: 'Health',
      icon: Icons.local_hospital,
      keywords: [
        'pharmacy',
        'doctor',
        'health',
        'hospital',
        'apollo',
        '1mg',
        'practo',
      ],
    ),
    const IconEntry(
      id: 'transfer',
      label: 'Transfer',
      icon: Icons.swap_horiz,
      keywords: [
        'neft',
        'imps',
        'rtgs',
        'transfer',
        'sent',
        'upi',
      ],
    ),
    const IconEntry(
      id: 'investment',
      label: 'Investment',
      icon: Icons.trending_up,
      keywords: [
        'sip',
        'mutual',
        'stock',
        'invest',
        'groww',
        'zerodha',
        'cred',
        'kuvera',
      ],
    ),
    const IconEntry(
      id: 'other',
      label: 'Other',
      icon: Icons.category,
      keywords: ['misc', 'other'],
    ),
  ];

  static List<IconEntry> suggestionsForCategory(String? inferred) {
    if (inferred == null) return all.take(6).toList();
    final lower = inferred.toLowerCase();
    final scored = <({IconEntry e, int score})>[];
    for (final e in all) {
      var score = 0;
      if (e.id == lower) score += 10;
      for (final k in e.keywords) {
        if (lower.contains(k)) score += 5;
      }
      scored.add((e: e, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(6).map((s) => s.e).toList();
  }

  static List<IconEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all.take(6).toList();
    final out = <IconEntry>[];
    for (final e in all) {
      if (e.label.toLowerCase().contains(q) || e.id.contains(q)) {
        out.add(e);
        continue;
      }
      for (final k in e.keywords) {
        if (k.startsWith(q) || k.contains(q)) {
          out.add(e);
          break;
        }
      }
    }
    return out.take(6).toList();
  }

  static IconEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }
}
