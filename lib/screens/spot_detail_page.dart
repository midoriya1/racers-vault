import 'package:flutter/material.dart';

import '../data/rarity_data.dart';
import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../models/moderation_case.dart';
import '../models/spot_comment.dart';
import '../services/vault_repository.dart';
import '../widgets/rv_glass.dart';
import '../widgets/spot_card.dart';
import '../widgets/stats.dart';

class SpotDetailPage extends StatefulWidget {
  const SpotDetailPage({
    super.key,
    required this.spot,
    required this.currentUser,
    required this.repository,
    required this.onSpotterSelected,
  });

  final CarSpot spot;
  final AppUser currentUser;
  final VaultRepository repository;
  final ValueChanged<String> onSpotterSelected;

  @override
  State<SpotDetailPage> createState() => _SpotDetailPageState();
}

class _SpotDetailPageState extends State<SpotDetailPage> {
  final _commentController = TextEditingController();
  bool _isLiked = false;
  bool _isLoading = true;
  bool _isSaving = false;
  late int _likes;
  late int _commentsCount;
  List<SpotComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _likes = widget.spot.likes;
    _commentsCount = widget.spot.comments;
    _loadSocialState();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadSocialState() async {
    try {
      final liked = await widget.repository.isSpotLiked(widget.spot.id);
      final comments = await widget.repository.loadComments(widget.spot.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = liked;
        _comments = comments;
        _commentsCount = comments.length > _commentsCount
            ? comments.length
            : _commentsCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      _showMessage('Could not load social data: $error');
    }
  }

  Future<void> _toggleLike() async {
    if (_isSaving) {
      return;
    }

    final nextLiked = !_isLiked;
    setState(() {
      _isLiked = nextLiked;
      _likes += nextLiked ? 1 : -1;
      if (_likes < 0) {
        _likes = 0;
      }
      _isSaving = true;
    });

    try {
      await widget.repository.setSpotLiked(widget.spot, liked: nextLiked);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = !nextLiked;
        _likes += nextLiked ? -1 : 1;
      });
      _showMessage('Could not update like: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.repository.addComment(widget.spot, widget.currentUser, body);
      _commentController.clear();
      final comments = await widget.repository.loadComments(widget.spot.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _comments = comments;
        _commentsCount = comments.length;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not add comment: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _reportSpot() async {
    final report = await showDialog<ModerationCaseDraft>(
      context: context,
      builder: (context) => const _ReportDialog(),
    );
    if (report == null) {
      return;
    }

    try {
      await widget.repository.reportSpot(
        widget.spot,
        widget.currentUser,
        report,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Report sent. Thanks for protecting the vault.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not send report: $error');
    }
  }

  Future<void> _suggestCorrection() async {
    final correction = await showDialog<ModerationCaseDraft>(
      context: context,
      builder: (context) => _CorrectionDialog(spot: widget.spot),
    );
    if (correction == null) {
      return;
    }

    try {
      await widget.repository.reportSpot(
        widget.spot,
        widget.currentUser,
        correction,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Correction saved for review.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not save correction: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spot Details'),
        actions: [
          IconButton(
            onPressed: _reportSpot,
            tooltip: 'Report',
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            _CollectibleHero(spot: spot),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : _toggleLike,
                    icon: Icon(
                      _isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    label: Text('$_likes likes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _suggestCorrection,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Correct'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => widget.onSpotterSelected(spot.spotter),
                icon: const Icon(Icons.person_search_rounded),
                label: Text('View @${spot.spotter}'),
              ),
            ),
            const SizedBox(height: 14),
            _RarityBreakdown(spot: spot),
            const SizedBox(height: 14),
            _RecognitionPanel(spot: spot),
            const SizedBox(height: 14),
            _SecurityPanel(spot: spot),
            const SizedBox(height: 14),
            _BadgesPanel(spot: spot),
            const SizedBox(height: 14),
            _InfoPanel(spot: spot, commentsCount: _commentsCount),
            const SizedBox(height: 18),
            Text(
              'Comments',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSaving ? null : _addComment,
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'Send',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_comments.isEmpty)
              const EmptyState(
                icon: Icons.mode_comment_outlined,
                title: 'No comments yet',
                message: 'Start the conversation about this spot.',
              )
            else
              for (final comment in _comments) _CommentTile(comment: comment),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.spot, required this.commentsCount});

  final CarSpot spot;
  final int commentsCount;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          ProfileStat(label: 'Category', value: spot.category),
          ProfileStat(label: 'Rarity', value: spot.rarity),
          ProfileStat(label: 'Points', value: '${spot.points}'),
          ProfileStat(
            label: 'Spotted in',
            value: '${spot.city}, ${spot.country}',
          ),
          ProfileStat(
            label: 'Capture',
            value: _captureLabel(spot.captureSource),
          ),
          ProfileStat(
            label: 'Verification',
            value: _statusLabel(spot.verificationStatus),
          ),
          ProfileStat(label: 'Trust score', value: '${spot.trustScore}%'),
          ProfileStat(label: 'Comments', value: '$commentsCount'),
        ],
      ),
    );
  }

  String _captureLabel(String source) {
    return switch (source) {
      'camera' => 'Camera',
      'gallery' => 'Gallery',
      _ => 'Unknown',
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'camera-captured' => 'Camera verified',
      'gallery-review' => 'Needs review',
      _ => 'Unverified',
    };
  }
}

class _CollectibleHero extends StatelessWidget {
  const _CollectibleHero({required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: EdgeInsets.zero,
      radius: 24,
      glowColor: RvColors.rarity(spot.rarity),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 1.1, child: SpotMedia(spot: spot)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spot.carName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: RvColors.text,
                            ),
                      ),
                    ),
                    RarityChip(label: spot.rarity),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: const TextStyle(
                    color: RvColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(
                      icon: Icons.bolt_rounded,
                      label: '${spot.points} pts',
                    ),
                    _HeroPill(
                      icon: Icons.location_on_outlined,
                      label: '${spot.city}, ${spot.country}',
                    ),
                    _HeroPill(
                      icon: Icons.category_rounded,
                      label: spot.category,
                    ),
                  ],
                ),
                if (spot.caption.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    spot.caption,
                    style: const TextStyle(
                      color: RvColors.titanium,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    final parts = [
      spot.vehicleMake,
      spot.vehicleModel,
      spot.vehicleGeneration,
      spot.yearRange,
      spot.bodyType,
    ].where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Collected by @${spot.spotter}' : parts.join(' - ');
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RvColors.glassStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RvColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: RvColors.electricBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: RvColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RarityBreakdown extends StatelessWidget {
  const _RarityBreakdown({required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    final maxPoints = rarityPoints['Mythic'] ?? 500;
    final score = (spot.points / maxPoints).clamp(0, 1).toDouble();
    final scoreText = (score * 10).toStringAsFixed(1);
    final confidenceBonus = (spot.aiConfidence * 25).round();
    final trustBonus = (spot.trustScore / 100 * 25).round();
    final base = (spot.points - confidenceBonus - trustBonus).clamp(
      0,
      spot.points,
    );

    return _Panel(
      title: 'Rarity Breakdown',
      icon: Icons.auto_graph_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$scoreText/10 in ${spot.country}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${spot.points} pts',
                style: const TextStyle(
                  color: RvColors.crimson,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: score,
              backgroundColor: RvColors.graphiteLight,
              color: RvColors.rarity(spot.rarity),
            ),
          ),
          const SizedBox(height: 12),
          _BreakdownRow(label: 'Base rarity', value: '$base pts'),
          _BreakdownRow(label: 'AI confidence', value: '+$confidenceBonus pts'),
          _BreakdownRow(label: 'Trust signal', value: '+$trustBonus pts'),
          const SizedBox(height: 6),
          const Text(
            'This is the MVP formula. Later it can include production volume, city scarcity, streaks, and event multipliers.',
            style: TextStyle(color: RvColors.mutedText, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _RecognitionPanel extends StatelessWidget {
  const _RecognitionPanel({required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    final confidence = spot.aiConfidence <= 0
        ? 'Not stored'
        : '${(spot.aiConfidence * 100).round()}%';

    return _Panel(
      title: 'AI Identification',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          ProfileStat(label: 'Confidence', value: confidence),
          ProfileStat(label: 'Make', value: _valueOrUnknown(spot.vehicleMake)),
          ProfileStat(
            label: 'Model',
            value: _valueOrUnknown(spot.vehicleModel),
          ),
          ProfileStat(
            label: 'Generation',
            value: _valueOrUnknown(spot.vehicleGeneration),
          ),
          ProfileStat(
            label: 'Year range',
            value: _valueOrUnknown(spot.yearRange),
          ),
          ProfileStat(
            label: 'Body type',
            value: _valueOrUnknown(spot.bodyType),
          ),
          if (spot.recognitionNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              spot.recognitionNote,
              style: const TextStyle(color: RvColors.mutedText, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  String _valueOrUnknown(String value) {
    return value.trim().isEmpty ? 'Unknown' : value;
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    final syntheticRisk = '${(spot.syntheticImageRisk * 100).round()}%';
    final manipulationRisk = '${(spot.manipulationRisk * 100).round()}%';

    return _Panel(
      title: 'Privacy & Security',
      icon: Icons.security_rounded,
      child: Column(
        children: [
          ProfileStat(
            label: 'License plate',
            value: spot.privacyPlateDetected ? 'Needs blur' : 'Clear',
          ),
          ProfileStat(
            label: 'Faces',
            value: spot.privacyFaceDetected ? 'Needs blur' : 'Clear',
          ),
          ProfileStat(label: 'AI-generated risk', value: syntheticRisk),
          ProfileStat(label: 'Edit risk', value: manipulationRisk),
          ProfileStat(
            label: 'Location integrity',
            value: _locationLabel(spot.locationIntegrity),
          ),
          ProfileStat(label: 'Blur status', value: _blurLabel(spot.blurStatus)),
          if (spot.securityNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              spot.securityNotes,
              style: const TextStyle(color: RvColors.mutedText, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  String _locationLabel(String value) {
    return switch (value) {
      'gps-verified' => 'GPS verified',
      'mock-location-review' => 'Fake GPS review',
      'low-accuracy-review' => 'Low accuracy review',
      _ => 'Profile fallback',
    };
  }

  String _blurLabel(String value) {
    return switch (value) {
      'processed' => 'Auto blurred',
      'failed' => 'Blur failed',
      'not_needed' => 'Not needed',
      _ => value,
    };
  }
}

class _BadgesPanel extends StatelessWidget {
  const _BadgesPanel({required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    final badges = _badgesForSpot();
    return _Panel(
      title: 'Collection Badges',
      icon: Icons.military_tech_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final badge in badges)
            Chip(
              avatar: Icon(badge.icon, size: 18),
              label: Text(badge.label),
              backgroundColor: RvColors.electricBlue.withValues(alpha: 0.12),
              side: BorderSide(
                color: RvColors.electricBlue.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }

  List<_BadgeData> _badgesForSpot() {
    final badges = <_BadgeData>[
      const _BadgeData(Icons.place_rounded, 'City Spotter'),
    ];
    if (spot.category == 'JDM' || spot.category == 'Japanese') {
      badges.add(const _BadgeData(Icons.local_fire_department, 'JDM Hunter'));
    }
    if (spot.category == 'Italian') {
      badges.add(const _BadgeData(Icons.workspace_premium, 'Italian Icon'));
    }
    if (spot.category == 'Supercars' || spot.category == 'Hypercars') {
      badges.add(const _BadgeData(Icons.speed_rounded, 'Supercar Scout'));
    }
    if (spot.category == 'Bikes' ||
        spot.category == 'Superbikes' ||
        spot.category == 'Cruisers') {
      badges.add(const _BadgeData(Icons.two_wheeler_rounded, 'Bike Watch'));
    }
    if (spot.rarity == 'Legendary' || spot.rarity == 'Mythic') {
      badges.add(const _BadgeData(Icons.diamond_rounded, 'Rare Find'));
    }
    if (spot.captureSource == 'camera') {
      badges.add(const _BadgeData(Icons.verified_user_rounded, 'Live Capture'));
    }
    return badges;
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: RvColors.electricBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: RvColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: RvColors.mutedText),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: RvColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeData {
  const _BadgeData(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final SpotComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RvGlass(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${comment.username}',
              style: const TextStyle(
                color: RvColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              comment.body,
              style: const TextStyle(color: RvColors.titanium),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = 'Stolen photo';
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report spot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Stolen photo',
                child: Text('Stolen photo'),
              ),
              DropdownMenuItem(
                value: 'Fake location',
                child: Text('Fake location'),
              ),
              DropdownMenuItem(value: 'Wrong car', child: Text('Wrong car')),
              DropdownMenuItem(
                value: 'Unsafe content',
                child: Text('Unsafe content'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _reason = value ?? _reason;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            decoration: const InputDecoration(
              labelText: 'Details',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final details = _detailsController.text.trim();
            Navigator.of(context).pop(
              ModerationCaseDraft.report(reason: _reason, details: details),
            );
          },
          child: const Text('Report'),
        ),
      ],
    );
  }
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.spot});

  final CarSpot spot;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late final TextEditingController _carController;
  late final TextEditingController _detailsController;

  @override
  void initState() {
    super.initState();
    _carController = TextEditingController(text: widget.spot.carName);
    _detailsController = TextEditingController();
  }

  @override
  void dispose() {
    _carController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Suggest correction'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _carController,
            decoration: const InputDecoration(
              labelText: 'Correct vehicle name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            decoration: const InputDecoration(
              labelText: 'Why?',
              hintText: 'Example: this is a 992 GT3 RS, not a Turbo S',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final car = _carController.text.trim();
            final details = _detailsController.text.trim();
            if (car.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              ModerationCaseDraft.correction(
                suggestedCarName: car,
                details: details,
              ),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
