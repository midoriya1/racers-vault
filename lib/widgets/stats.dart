import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import 'rv_glass.dart';

class ScoreTile extends StatelessWidget {
  const ScoreTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: RvGlass(
        padding: const EdgeInsets.all(14),
        glowColor: RvColors.electricBlue,
        child: SizedBox(
          width: 150,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: RvColors.crimson.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: RvColors.crimson.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, color: RvColors.crimson, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: RvColors.text,
                        fontSize: value.length > 7 ? 15 : null,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RvColors.mutedText,
                      ),
                    ),
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

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, color: RvColors.crimson, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RvColors.mutedText),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.arrow_forward_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: RvColors.mutedText),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: RvColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
