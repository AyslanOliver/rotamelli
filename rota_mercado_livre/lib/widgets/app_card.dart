import 'package:flutter/material.dart';
import '../theme/sb2.dart';

class AppCard extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final Widget child;
  final Color? borderLeftColor;
  const AppCard({super.key, this.color, this.gradient, this.padding, this.borderLeftColor, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.surface;
    return Container(
      padding: padding ?? SB2.cardPadding,
      decoration: BoxDecoration(
        color: gradient == null ? c : null,
        gradient: gradient,
        borderRadius: SB2.cardRadius,
        border: borderLeftColor != null ? Border(left: BorderSide(color: borderLeftColor!, width: 4)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: child,
    );
  }
}
