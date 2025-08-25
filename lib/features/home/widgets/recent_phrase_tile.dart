import 'package:flutter/material.dart';
import 'package:englishplease/ui/constants.dart';
import '../models/recent_phrase.dart';

class RecentPhraseTile extends StatelessWidget {
  final RecentPhrase phrase;
  const RecentPhraseTile({super.key, required this.phrase});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(kRadius16),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius16),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kGap16, vertical: kGap12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phrase.text, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: kGap4),
                    Text(phrase.meaning, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 14)),
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

