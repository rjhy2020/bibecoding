import 'package:flutter/material.dart';
import 'package:englishplease/ui/constants.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool compact;
  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final double h = compact ? 76 : 88;
    final double titleSize = compact ? 11 : 12;
    final double valueSize = compact ? 18 : 20;
    final double pad = compact ? kGap12 : kGap16;
    return Container(
      height: h,
      padding: EdgeInsets.all(pad),
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
          SizedBox(width: compact ? kGap8 : kGap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: tt.bodySmall?.copyWith(fontSize: titleSize, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: kGap4),
                Text(value, style: tt.titleLarge?.copyWith(fontSize: valueSize, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
