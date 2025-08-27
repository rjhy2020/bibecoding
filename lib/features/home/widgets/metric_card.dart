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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const baseW = 240.0; // 기준 카드 너비
          final scale = (maxW / baseW).clamp(0.90, 1.0);
          final tSize = titleSize * scale;
          final vSize = valueSize * scale;

          return Row(
            children: [
              Icon(icon, color: cs.primary),
              SizedBox(width: compact ? kGap8 : kGap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: tt.bodySmall?.copyWith(fontSize: tSize, color: cs.onSurfaceVariant),
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                    const SizedBox(height: kGap4),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: tt.titleLarge?.copyWith(fontSize: vSize, fontWeight: FontWeight.w600),
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
