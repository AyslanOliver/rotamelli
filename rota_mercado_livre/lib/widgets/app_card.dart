import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final Widget child;
  const AppCard({super.key, this.color, this.gradient, this.padding, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.surface;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? c : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }
}
