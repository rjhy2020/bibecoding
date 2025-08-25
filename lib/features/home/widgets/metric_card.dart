import 'package:flutter/material.dart';
import 'package:englishplease/ui/constants.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const MetricCard({super.key, required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      height: 88,
      padding: const EdgeInsets.all(kGap16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: kGap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: tt.bodySmall?.copyWith(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: kGap4),
                Text(value, style: tt.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

