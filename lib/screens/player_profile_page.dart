import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../services/vault_repository.dart';
import '../widgets/page_title.dart';
import '../widgets/rv_glass.dart';
import '../widgets/spot_card.dart';
import '../widgets/stats.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({
    super.key,
    required this.username,
    required this.spots,
    required this.currentUser,
    required this.repository,
    required this.onSpotSelected,
    required this.onFollowChanged,
  });

  final String username;
  final List<CarSpot> spots;
  final AppUser currentUser;
  final VaultRepository repository;
  final ValueChanged<CarSpot> onSpotSelected;
  final VoidCallback onFollowChanged;

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _isFollowing = false;
  bool _isLoadingFollow = true;
  bool _isSavingFollow = false;

  List<CarSpot> get _playerSpots =>
      widget.spots.where((spot) => spot.spotter == widget.username).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  String? get _targetUserId {
    final playerSpots = _playerSpots;
    if (playerSpots.isEmpty) {
      return null;
    }
    return playerSpots.first.userId;
  }

  bool get _isCurrentUser => widget.username == widget.currentUser.username;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final targetUserId = _targetUserId;
    if (_isCurrentUser || targetUserId == null) {
      setState(() {
        _isLoadingFollow = false;
      });
      return;
    }

    try {
      final isFollowing = await widget.repository.isFollowing(targetUserId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isFollowing = isFollowing;
        _isLoadingFollow = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFollow = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final targetUserId = _targetUserId;
    if (_isSavingFollow || _isCurrentUser || targetUserId == null) {
      return;
    }

    final nextValue = !_isFollowing;
    setState(() {
      _isFollowing = nextValue;
      _isSavingFollow = true;
    });

    try {
      await widget.repository.setFollowing(targetUserId, following: nextValue);
      widget.onFollowChanged();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFollowing = !nextValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update follow: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingFollow = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerSpots = _playerSpots;
    final stats = _PlayerStats.fromSpots(playerSpots);

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            PageTitle(
              icon: Icons.person_rounded,
              title: '@${widget.username}',
              subtitle: _isCurrentUser
                  ? 'This is your public spotter profile.'
                  : 'Public spotter profile and recent vault activity.',
            ),
            const SizedBox(height: 16),
            _ProfileHero(
              username: widget.username,
              stats: stats,
              isCurrentUser: _isCurrentUser,
              isFollowing: _isFollowing,
              isLoadingFollow: _isLoadingFollow || _isSavingFollow,
              canFollow: _targetUserId != null && !_isCurrentUser,
              onFollowPressed: _toggleFollow,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 94,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ScoreTile(
                    label: 'Points',
                    value: '${stats.points}',
                    icon: Icons.bolt_rounded,
                  ),
                  ScoreTile(
                    label: 'Spots',
                    value: '${stats.spots}',
                    icon: Icons.photo_camera_rounded,
                  ),
                  ScoreTile(
                    label: 'Trust',
                    value: '${stats.averageTrust}%',
                    icon: Icons.verified_user_rounded,
                  ),
                  ScoreTile(
                    label: 'Best',
                    value: stats.rarestRarity,
                    icon: Icons.diamond_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _BadgePanel(stats: stats),
            const SizedBox(height: 18),
            Text(
              'Recent spots',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: RvColors.text,
              ),
            ),
            const SizedBox(height: 10),
            if (playerSpots.isEmpty)
              const EmptyState(
                icon: Icons.garage_outlined,
                title: 'No public spots yet',
                message: 'Their garage will appear here after first upload.',
              )
            else
              for (final spot in playerSpots.take(8)) ...[
                SpotCard(spot: spot, onTap: () => widget.onSpotSelected(spot)),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.username,
    required this.stats,
    required this.isCurrentUser,
    required this.isFollowing,
    required this.isLoadingFollow,
    required this.canFollow,
    required this.onFollowPressed,
  });

  final String username;
  final _PlayerStats stats;
  final bool isCurrentUser;
  final bool isFollowing;
  final bool isLoadingFollow;
  final bool canFollow;
  final VoidCallback onFollowPressed;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(16),
      glowColor: RvColors.legendary,
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: RvColors.legendary,
            child: Text(
              username.characters.first.toUpperCase(),
              style: const TextStyle(
                color: RvColors.obsidian,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: RvColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${stats.cityCountry} - level ${stats.level}',
                  style: const TextStyle(color: RvColors.mutedText),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: canFollow && !isLoadingFollow
                        ? onFollowPressed
                        : null,
                    icon: Icon(
                      isCurrentUser
                          ? Icons.person_rounded
                          : isFollowing
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                    ),
                    label: Text(
                      isCurrentUser
                          ? 'Your profile'
                          : isLoadingFollow
                          ? 'Checking...'
                          : isFollowing
                          ? 'Following'
                          : 'Follow',
                    ),
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

class _BadgePanel extends StatelessWidget {
  const _BadgePanel({required this.stats});

  final _PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final badges = stats.badges;
    return RvGlass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Badges',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RvColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (badges.isEmpty)
            const Text(
              'No public badges yet.',
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
        ],
      ),
    );
  }
}

class _PlayerStats {
  const _PlayerStats({
    required this.points,
    required this.spots,
    required this.averageTrust,
    required this.rarestRarity,
    required this.cityCountry,
    required this.level,
    required this.title,
    required this.badges,
  });

  final int points;
  final int spots;
  final int averageTrust;
  final String rarestRarity;
  final String cityCountry;
  final int level;
  final String title;
  final List<_PublicBadge> badges;

  factory _PlayerStats.fromSpots(List<CarSpot> spots) {
    final points = spots.fold<int>(0, (total, spot) => total + spot.points);
    final trust = spots.isEmpty
        ? 0
        : (spots.fold<int>(0, (total, spot) => total + spot.trustScore) /
                  spots.length)
              .round();
    final rarest = spots.isEmpty
        ? null
        : spots.reduce((a, b) => a.points >= b.points ? a : b);
    final level = _levelForXp(points);

    return _PlayerStats(
      points: points,
      spots: spots.length,
      averageTrust: trust,
      rarestRarity: rarest?.rarity ?? '-',
      cityCountry: spots.isEmpty
          ? 'Unknown location'
          : '${spots.first.city}, ${spots.first.country}',
      level: level,
      title: _titleForLevel(level),
      badges: _badgesForSpots(spots),
    );
  }

  static int _levelForXp(int xp) {
    var level = 1;
    var spentXp = 0;
    var nextCost = 100;
    while (xp - spentXp >= nextCost) {
      spentXp += nextCost;
      level += 1;
      nextCost = 100 + ((level - 1) * 75);
    }
    return level;
  }

  static String _titleForLevel(int level) {
    if (level >= 20) return 'Legendary Collector';
    if (level >= 12) return 'Vault Elite';
    if (level >= 7) return 'Rare Hunter';
    if (level >= 3) return 'Street Scout';
    return 'Rookie Spotter';
  }

  static List<_PublicBadge> _badgesForSpots(List<CarSpot> spots) {
    if (spots.isEmpty) return [];

    final categories = spots.map((spot) => spot.category).toSet();
    final rarities = spots.map((spot) => spot.rarity).toSet();
    final badges = <_PublicBadge>[
      const _PublicBadge(Icons.flag_rounded, 'First Spot'),
    ];

    if (categories.contains('Supercars') || categories.contains('Hypercars')) {
      badges.add(const _PublicBadge(Icons.speed_rounded, 'Supercar Scout'));
    }
    if (categories.contains('JDM') || categories.contains('Japanese')) {
      badges.add(const _PublicBadge(Icons.local_fire_department, 'JDM Hunter'));
    }
    if (categories.contains('Bikes') || categories.contains('Superbikes')) {
      badges.add(const _PublicBadge(Icons.two_wheeler_rounded, 'Bike Watch'));
    }
    if (rarities.contains('Legendary') || rarities.contains('Mythic')) {
      badges.add(const _PublicBadge(Icons.diamond_rounded, 'Rare Find'));
    }
    if (spots.any((spot) => spot.captureSource == 'camera')) {
      badges.add(
        const _PublicBadge(Icons.verified_user_rounded, 'Live Capture'),
      );
    }
    if (spots.length >= 10) {
      badges.add(
        const _PublicBadge(Icons.emoji_events_rounded, 'Vault Builder'),
      );
    }

    return badges;
  }
}

class _PublicBadge {
  const _PublicBadge(this.icon, this.label);

  final IconData icon;
  final String label;
}
