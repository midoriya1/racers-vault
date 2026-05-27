import 'package:flutter/material.dart';

import '../design/rv_colors.dart';

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: RvColors.electricBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: RvColors.electricBlue.withValues(alpha: 0.34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: RvColors.electricBlue.withValues(alpha: 0.18),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Icon(icon, color: RvColors.electricBlue, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: RvColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: RvColors.mutedText,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
