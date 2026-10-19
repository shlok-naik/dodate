import 'package:flutter/material.dart';

import '../core/scheduler.dart';
import 'theme.dart';

/// Rounded square in the assignment's colour with its first letter.
class TintBadge extends StatelessWidget {
  const TintBadge({super.key, required this.taskId, required this.title, this.size = 40});

  final String taskId;
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.tintFor(taskId);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(
        title.isEmpty ? '?' : title.characters.first.toUpperCase(),
        style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: size * 0.45, color: tint.fg),
      ),
    );
  }
}

/// Amber card for "needs more time"; muted red only for truly overdue work.
class WarningCard extends StatelessWidget {
  const WarningCard({super.key, required this.warning});

  final PlanWarning warning;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overdue = warning.type == WarningType.overdue;
    final fg = overdue ? c.danger : c.warn;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
      decoration: BoxDecoration(
        color: overdue ? c.dangerBg : c.warnBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(overdue ? Icons.flag_outlined : Icons.hourglass_bottom_rounded, size: 20, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warning.headline,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: fg)),
                const SizedBox(height: 2),
                Text(warning.message, style: TextStyle(fontSize: 14, height: 1.35, color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: context.colors.muted),
      );
}
