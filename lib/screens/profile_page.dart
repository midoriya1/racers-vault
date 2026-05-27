import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../widgets/page_title.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/rv_glass.dart';
import '../widgets/stats.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.spots,
    required this.totalPoints,
    required this.currentUser,
    required this.onSignOut,
    required this.onEditProfile,
    this.onOpenModeration,
  });

  final List<CarSpot> spots;
  final int totalPoints;
  final AppUser currentUser;
  final VoidCallback onSignOut;
  final VoidCallback onEditProfile;
  final VoidCallback? onOpenModeration;

  @override
  Widget build(BuildContext context) {
    final progression = _ProfileProgress.fromSpots(spots);
    final rarest = spots.isEmpty
        ? 'No spots yet'
        : spots.reduce((a, b) => a.points >= b.points ? a : b).carName;
    final badges = _earnedBadges(spots);
    final trust = _TrustSummary.fromSpots(spots);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
      children: [
        const PageTitle(
          icon: Icons.person_rounded,
          title: 'Spotter Profile',
          subtitle: 'Your early Racers Vault identity.',
        ),
        const SizedBox(height: 16),
        RvGlass(
          padding: const EdgeInsets.all(18),
          glowColor: RvColors.crimson,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(
                    username: currentUser.username,
                    avatarUrl: currentUser.avatarUrl,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${currentUser.username}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: RvColors.text,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          '${currentUser.country} spotter',
                          style: const TextStyle(color: RvColors.mutedText),
                        ),
                        if (currentUser.bio.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            currentUser.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: RvColors.titanium),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit profile'),
                ),
              ),
              const SizedBox(height: 20),
              _LevelPanel(progression: progression),
              const SizedBox(height: 16),
              ProfileStat(label: 'Vault points', value: '$totalPoints'),
              ProfileStat(label: 'XP earned', value: '${progression.xp}'),
              ProfileStat(label: 'Level', value: '${progression.level}'),
              ProfileStat(label: 'Cars spotted', value: '${spots.length}'),
              ProfileStat(label: 'Rarest spot', value: rarest),
              const SizedBox(height: 18),
              Text(
                'Achievements',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: RvColors.text,
                ),
              ),
              const SizedBox(height: 10),
              if (badges.isEmpty)
                const Text(
                  'Add your first verified spot to unlock badges.',
                  style: TextStyle(color: RvColors.mutedText),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final badge in badges)
                      Chip(
                        avatar: Icon(badge.icon, size: 18),
                        label: Text(badge.label),
                        backgroundColor: RvColors.electricBlue.withValues(
                          alpha: 0.12,
                        ),
                        side: BorderSide(
                          color: RvColors.electricBlue.withValues(alpha: 0.35),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
              _TrustCenter(summary: trust, spots: spots),
              const SizedBox(height: 18),
              if (currentUser.isModerator && onOpenModeration != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenModeration,
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: const Text('Open mod console'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_AchievementBadge> _earnedBadges(List<CarSpot> spots) {
    if (spots.isEmpty) {
      return [];
    }

    final categories = spots.map((spot) => spot.category).toSet();
    final rarities = spots.map((spot) => spot.rarity).toSet();
    final countries = spots.map((spot) => spot.country).toSet();
    final hasCameraSpot = spots.any((spot) => spot.captureSource == 'camera');
    final badges = <_AchievementBadge>[
      const _AchievementBadge(Icons.flag_rounded, 'First Spot'),
    ];

    if (rarities.contains('Rare') ||
        rarities.contains('Ultra Rare') ||
        rarities.contains('Legendary') ||
        rarities.contains('Mythic')) {
      badges.add(const _AchievementBadge(Icons.star_rounded, 'Rare Starter'));
    }
    if (rarities.contains('Legendary') || rarities.contains('Mythic')) {
      badges.add(const _AchievementBadge(Icons.diamond_rounded, 'Rare Find'));
    }
    if (categories.contains('JDM') || categories.contains('Japanese')) {
      badges.add(
        const _AchievementBadge(Icons.local_fire_department, 'JDM Hunter'),
      );
    }
    if (categories.contains('Supercars') || categories.contains('Hypercars')) {
      badges.add(
        const _AchievementBadge(Icons.speed_rounded, 'Supercar Scout'),
      );
    }
    if (categories.contains('Bikes') ||
        categories.contains('Superbikes') ||
        categories.contains('Cruisers') ||
        categories.contains('Adventure Bikes')) {
      badges.add(
        const _AchievementBadge(Icons.two_wheeler_rounded, 'Bike Watch'),
      );
    }
    if (categories.contains('Hot Wheels')) {
      badges.add(
        const _AchievementBadge(Icons.toys_rounded, 'Die-cast Hunter'),
      );
    }
    if (categories.contains('RC')) {
      badges.add(
        const _AchievementBadge(Icons.settings_remote_rounded, 'RC Scout'),
      );
    }
    if (hasCameraSpot) {
      badges.add(
        const _AchievementBadge(Icons.verified_user_rounded, 'Live Capture'),
      );
    }
    if (countries.length >= 2) {
      badges.add(
        const _AchievementBadge(Icons.public_rounded, 'Cross-border Spotter'),
      );
    }
    if (spots.length >= 10) {
      badges.add(
        const _AchievementBadge(Icons.emoji_events_rounded, 'Vault Builder'),
      );
    }

    return badges;
  }
}

class _TrustCenter extends StatelessWidget {
  const _TrustCenter({required this.summary, required this.spots});

  final _TrustSummary summary;
  final List<CarSpot> spots;

  @override
  Widget build(BuildContext context) {
    final reviewSpots = spots
        .where(
          (spot) =>
              spot.trustScore < 70 ||
              spot.verificationStatus == 'gallery-review',
        )
        .take(3)
        .toList();

    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: RvColors.legendary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: RvColors.legendary),
              const SizedBox(width: 8),
              Text(
                'Trust Center',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Protect your vault with camera captures, duplicate checks, reports, and AI correction review.',
            style: TextStyle(color: RvColors.mutedText, height: 1.3),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _TrustMetric(
                label: 'Avg trust',
                value: '${summary.averageTrust}%',
              ),
              _TrustMetric(label: 'Verified', value: '${summary.verified}'),
              _TrustMetric(label: 'Needs review', value: '${summary.review}'),
              _TrustMetric(label: 'Protected', value: '${summary.hashed}'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Review queue',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (reviewSpots.isEmpty)
            const _TrustNotice(
              icon: Icons.verified_user_rounded,
              title: 'No review items',
              message: 'Your spots currently look clean.',
            )
          else
            for (final spot in reviewSpots) ...[
              _ReviewSpotTile(spot: spot),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          const _TrustNotice(
            icon: Icons.info_outline_rounded,
            title: 'How moderation works',
            message:
                'Reports and correction suggestions are stored for review. Exact photo hashes block duplicates, while perceptual hashes catch near-duplicates.',
          ),
        ],
      ),
    );
  }
}

class _TrustMetric extends StatelessWidget {
  const _TrustMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFE8DED2), fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: RvColors.legendary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSpotTile extends StatelessWidget {
  const _ReviewSpotTile({required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, color: RvColors.legendary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.carName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${spot.trustScore}% trust - ${_statusLabel(spot.verificationStatus)}',
                  style: const TextStyle(color: RvColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    return spot.captureSource == 'camera'
        ? Icons.verified_user_rounded
        : Icons.manage_search_rounded;
  }

  String _statusLabel(String status) {
    return switch (status) {
      'camera-captured' => 'camera verified',
      'gallery-review' => 'gallery review',
      _ => 'unverified',
    };
  }
}

class _TrustNotice extends StatelessWidget {
  const _TrustNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RvColors.legendary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: RvColors.mutedText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustSummary {
  const _TrustSummary({
    required this.averageTrust,
    required this.verified,
    required this.review,
    required this.hashed,
  });

  final int averageTrust;
  final int verified;
  final int review;
  final int hashed;

  factory _TrustSummary.fromSpots(List<CarSpot> spots) {
    if (spots.isEmpty) {
      return const _TrustSummary(
        averageTrust: 0,
        verified: 0,
        review: 0,
        hashed: 0,
      );
    }

    final totalTrust = spots.fold<int>(
      0,
      (total, spot) => total + spot.trustScore,
    );

    return _TrustSummary(
      averageTrust: (totalTrust / spots.length).round(),
      verified: spots
          .where((spot) => spot.verificationStatus == 'camera-captured')
          .length,
      review: spots
          .where((spot) => spot.verificationStatus == 'gallery-review')
          .length,
      hashed: spots
          .where(
            (spot) =>
                (spot.imageHash != null && spot.imageHash!.isNotEmpty) ||
                (spot.perceptualHash != null &&
                    spot.perceptualHash!.isNotEmpty),
          )
          .length,
    );
  }
}

class _LevelPanel extends StatelessWidget {
  const _LevelPanel({required this.progression});

  final _ProfileProgress progression;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: RvColors.legendary,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RvColors.legendary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${progression.level}',
              style: const TextStyle(
                color: RvColors.obsidian,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progression.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: RvColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progression.levelProgress,
                    minHeight: 9,
                    backgroundColor: RvColors.graphiteLight,
                    color: RvColors.legendary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${progression.xpIntoLevel}/${progression.xpForNextLevel} XP to level ${progression.level + 1}',
                  style: const TextStyle(color: RvColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileProgress {
  const _ProfileProgress({
    required this.xp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  final int xp;
  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;

  double get levelProgress {
    if (xpForNextLevel <= 0) {
      return 1;
    }
    return (xpIntoLevel / xpForNextLevel).clamp(0, 1).toDouble();
  }

  String get title {
    if (level >= 20) return 'Legendary Collector';
    if (level >= 12) return 'Vault Elite';
    if (level >= 7) return 'Rare Hunter';
    if (level >= 3) return 'Street Scout';
    return 'Rookie Spotter';
  }

  factory _ProfileProgress.fromSpots(List<CarSpot> spots) {
    final xp = spots.fold<int>(0, (total, spot) => total + spot.points);
    var level = 1;
    var spentXp = 0;
    var nextLevelCost = _xpRequiredForLevel(level);

    while (xp - spentXp >= nextLevelCost) {
      spentXp += nextLevelCost;
      level += 1;
      nextLevelCost = _xpRequiredForLevel(level);
    }

    return _ProfileProgress(
      xp: xp,
      level: level,
      xpIntoLevel: xp - spentXp,
      xpForNextLevel: nextLevelCost,
    );
  }

  static int _xpRequiredForLevel(int level) {
    return 100 + ((level - 1) * 75);
  }
}

class _AchievementBadge {
  const _AchievementBadge(this.icon, this.label);

  final IconData icon;
  final String label;
}
