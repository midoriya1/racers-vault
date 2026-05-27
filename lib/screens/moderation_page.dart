import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import '../models/moderation_case.dart';
import '../services/vault_repository.dart';
import '../widgets/page_title.dart';
import '../widgets/rv_glass.dart';

class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key, required this.repository});

  final VaultRepository repository;

  @override
  State<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  List<ModerationCase> _cases = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cases = await widget.repository.loadModerationQueue();
      if (!mounted) {
        return;
      }
      setState(() {
        _cases = cases;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _setStatus(ModerationCase moderationCase, String status) async {
    try {
      await widget.repository.updateModerationCaseStatus(
        moderationCase,
        status: status,
      );
      await _loadQueue();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked ${moderationCase.spotName} $status')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCases = _cases.where((item) => item.status == 'open').length;

    return Scaffold(
      backgroundColor: RvColors.obsidian,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadQueue,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              PageTitle(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Mod Console',
                subtitle: '$openCases open review items',
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const _ModerationState(
                  icon: Icons.sync_rounded,
                  title: 'Loading queue',
                  message: 'Pulling the latest reports.',
                )
              else if (_error != null)
                _ModerationState(
                  icon: Icons.warning_amber_rounded,
                  title: 'Could not load queue',
                  message: _error!,
                )
              else if (_cases.isEmpty)
                const _ModerationState(
                  icon: Icons.verified_user_rounded,
                  title: 'Queue is clean',
                  message: 'No reports are waiting for review.',
                )
              else
                for (final moderationCase in _cases) ...[
                  _ModerationCard(
                    moderationCase: moderationCase,
                    onResolve: () => _setStatus(moderationCase, 'resolved'),
                    onDismiss: () => _setStatus(moderationCase, 'dismissed'),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.moderationCase,
    required this.onResolve,
    required this.onDismiss,
  });

  final ModerationCase moderationCase;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isClosed = moderationCase.status != 'open';

    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: _priorityColor,
      borderColor: _priorityColor.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 62,
                  height: 62,
                  color: RvColors.graphite,
                  child: moderationCase.mediaUrl == null
                      ? const Icon(Icons.directions_car_rounded)
                      : Image.network(
                          moderationCase.mediaUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_rounded),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moderationCase.spotName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RvColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${moderationCase.spotter} - ${moderationCase.reason}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RvColors.mutedText),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: moderationCase.status, color: _statusColor),
            ],
          ),
          if (moderationCase.details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              moderationCase.details,
              style: const TextStyle(color: RvColors.text, height: 1.35),
            ),
          ],
          if (moderationCase.suggestedCarName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Suggested: ${moderationCase.suggestedCarName}',
              style: const TextStyle(
                color: RvColors.electricBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusPill(label: moderationCase.priority, color: _priorityColor),
              const Spacer(),
              if (!isClosed) ...[
                TextButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Dismiss'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Resolve'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color get _priorityColor {
    return switch (moderationCase.priority) {
      'high' => RvColors.crimson,
      'medium' => RvColors.hyperOrange,
      _ => RvColors.electricBlue,
    };
  }

  Color get _statusColor {
    return switch (moderationCase.status) {
      'resolved' => RvColors.emerald,
      'dismissed' => RvColors.mutedText,
      _ => RvColors.legendary,
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ModerationState extends StatelessWidget {
  const _ModerationState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(18),
      glowColor: RvColors.electricBlue,
      child: Column(
        children: [
          Icon(icon, color: RvColors.electricBlue, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: RvColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RvColors.mutedText),
          ),
        ],
      ),
    );
  }
}
