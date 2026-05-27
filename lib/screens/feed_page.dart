import 'package:flutter/material.dart';

import '../data/rarity_data.dart';
import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../widgets/rv_glass.dart';
import '../widgets/spot_card.dart';
import '../widgets/stats.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    required this.spots,
    required this.totalPoints,
    required this.currentUser,
    required this.followingUserIds,
    required this.onSpotSelected,
  });

  final List<CarSpot> spots;
  final int totalPoints;
  final AppUser currentUser;
  final Set<String> followingUserIds;
  final ValueChanged<CarSpot> onSpotSelected;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String _selectedCategory = allCategory;
  _FeedScope _selectedScope = _FeedScope.all;

  @override
  Widget build(BuildContext context) {
    final scopedSpots = _selectedScope == _FeedScope.all
        ? widget.spots
        : widget.spots
              .where((spot) => widget.followingUserIds.contains(spot.userId))
              .toList();
    final filteredSpots = _selectedCategory == allCategory
        ? scopedSpots
        : scopedSpots
              .where((spot) => spot.category == _selectedCategory)
              .toList();
    final userSpots = widget.spots
        .where((spot) => spot.spotter == widget.currentUser.username)
        .toList();
    final rank = _rankForCurrentUser(widget.spots, widget.currentUser);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header(currentUser: widget.currentUser)),
        SliverToBoxAdapter(
          child: _ScoreStrip(
            totalPoints: widget.totalPoints,
            carsSpotted: filteredSpots.length,
            rank: rank,
          ),
        ),
        SliverToBoxAdapter(
          child: _FeedScopeControl(
            selectedScope: _selectedScope,
            followingCount: widget.followingUserIds.length,
            onSelected: (scope) {
              setState(() {
                _selectedScope = scope;
              });
            },
          ),
        ),
        SliverToBoxAdapter(
          child: _DailyHuntCard(
            currentUser: widget.currentUser,
            userSpots: userSpots,
          ),
        ),
        SliverToBoxAdapter(
          child: _CategoryRail(
            selectedCategory: _selectedCategory,
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
          ),
        ),
        if (filteredSpots.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: EmptyState(
                icon: _selectedScope == _FeedScope.following
                    ? Icons.people_outline_rounded
                    : Icons.add_a_photo_rounded,
                title: _selectedScope == _FeedScope.following
                    ? 'No following spots yet'
                    : 'Start the city feed',
                message: _selectedScope == _FeedScope.following
                    ? 'Follow spotters from Rank or spot details to build this feed.'
                    : 'Post the first spot and Racers Vault will turn it into points, rarity, and a vault entry.',
              ),
            ),
          )
        else
          SliverList.separated(
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SpotCard(
                spot: filteredSpots[index],
                onTap: () => widget.onSpotSelected(filteredSpots[index]),
              ),
            ),
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemCount: filteredSpots.length,
          ),
        SliverToBoxAdapter(
          child: _WeeklyChallengesSection(
            currentUser: widget.currentUser,
            userSpots: userSpots,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  String _rankForCurrentUser(List<CarSpot> spots, AppUser user) {
    final totals = <String, int>{};
    for (final spot in spots.where((spot) => spot.country == user.country)) {
      totals.update(
        spot.spotter,
        (value) => value + spot.points,
        ifAbsent: () => spot.points,
      );
    }

    if (!totals.containsKey(user.username)) {
      return 'Unranked';
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = sorted.indexWhere((entry) => entry.key == user.username) + 1;
    return '#$rank';
  }
}

enum _FeedScope { all, following }

class _FeedScopeControl extends StatelessWidget {
  const _FeedScopeControl({
    required this.selectedScope,
    required this.followingCount,
    required this.onSelected,
  });

  final _FeedScope selectedScope;
  final int followingCount;
  final ValueChanged<_FeedScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_FeedScope>(
          segments: [
            const ButtonSegment(
              value: _FeedScope.all,
              icon: Icon(Icons.public_rounded),
              label: Text('All'),
            ),
            ButtonSegment(
              value: _FeedScope.following,
              icon: const Icon(Icons.people_alt_rounded),
              label: Text('Following $followingCount'),
            ),
          ],
          selected: {selectedScope},
          onSelectionChanged: (selection) {
            onSelected(selection.first);
          },
        ),
      ),
    );
  }
}

class _DailyHuntCard extends StatelessWidget {
  const _DailyHuntCard({required this.currentUser, required this.userSpots});

  final AppUser currentUser;
  final List<CarSpot> userSpots;

  @override
  Widget build(BuildContext context) {
    final challenge = _dailyChallenge(currentUser);
    final progress = challenge.progress(userSpots);
    final isComplete = progress >= challenge.targetCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: RvGlass(
        padding: const EdgeInsets.all(14),
        glowColor: RvColors.hyperOrange,
        child: Row(
          children: [
            const Icon(Icons.radar_rounded, color: RvColors.hyperOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isComplete ? 'Daily hunt complete' : 'Daily rare hunt',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: RvColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    challenge.description,
                    style: const TextStyle(color: RvColors.titanium),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: challenge.progressValue(userSpots),
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      color: RvColors.hyperOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$progress/${challenge.targetCount}',
              style: TextStyle(
                color: RvColors.hyperOrange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _SpotChallenge _dailyChallenge(AppUser user) {
    final weekday = DateTime.now().weekday;
    return switch (weekday) {
      DateTime.monday => _SpotChallenge(
        title: 'Daily rare hunt',
        description: 'Find a German performance car in ${user.city}.',
        targetCount: 1,
        bonusLabel: '2x',
        matches: (spot) => spot.category == 'German',
        mustBeToday: true,
      ),
      DateTime.tuesday => _SpotChallenge(
        title: 'Daily bike watch',
        description: 'Spot any bike or superbike in ${user.city}.',
        targetCount: 1,
        bonusLabel: '+50 XP',
        matches: _isBike,
        mustBeToday: true,
      ),
      DateTime.wednesday => _SpotChallenge(
        title: 'Daily culture find',
        description: 'Find a JDM or Japanese spot today.',
        targetCount: 1,
        bonusLabel: '+50 XP',
        matches: (spot) =>
            spot.category == 'JDM' || spot.category == 'Japanese',
        mustBeToday: true,
      ),
      DateTime.thursday => _SpotChallenge(
        title: 'Daily premium hunt',
        description: 'Spot a Luxury, Supercar, or Hypercar.',
        targetCount: 1,
        bonusLabel: '2x',
        matches: (spot) =>
            spot.category == 'Luxury' ||
            spot.category == 'Supercars' ||
            spot.category == 'Hypercars',
        mustBeToday: true,
      ),
      DateTime.friday => _SpotChallenge(
        title: 'Daily live capture',
        description: 'Use the camera for a live verified spot.',
        targetCount: 1,
        bonusLabel: '+75 XP',
        matches: (spot) => spot.captureSource == 'camera',
        mustBeToday: true,
      ),
      DateTime.saturday => _SpotChallenge(
        title: 'Weekend collector',
        description: 'Add any rare or better spot today.',
        targetCount: 1,
        bonusLabel: '2x',
        matches: (spot) => spot.points >= (rarityPoints['Rare'] ?? 75),
        mustBeToday: true,
      ),
      _ => _SpotChallenge(
        title: 'Sunday city sweep',
        description: 'Add 2 spots from ${user.city}.',
        targetCount: 2,
        bonusLabel: '+100 XP',
        matches: (spot) => spot.city == user.city,
        mustBeToday: true,
      ),
    };
  }
}

class _WeeklyChallengesSection extends StatelessWidget {
  const _WeeklyChallengesSection({
    required this.currentUser,
    required this.userSpots,
  });

  final AppUser currentUser;
  final List<CarSpot> userSpots;

  @override
  Widget build(BuildContext context) {
    final challenges = _weeklyChallenges(currentUser);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Weekly challenges',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: RvColors.text,
                ),
              ),
              const Spacer(),
              const Text(
                'Resets Monday',
                style: TextStyle(
                  color: RvColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: challenges.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _ChallengeCard(
                challenge: challenges[index],
                userSpots: userSpots,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_SpotChallenge> _weeklyChallenges(AppUser user) {
    return [
      _SpotChallenge(
        title: 'City Streak',
        description: 'Add 3 spots from ${user.city}.',
        targetCount: 3,
        bonusLabel: '+250 XP',
        matches: (spot) => spot.city == user.city,
        weekOnly: true,
      ),
      _SpotChallenge(
        title: 'Rare Week',
        description: 'Collect 2 Rare or better finds.',
        targetCount: 2,
        bonusLabel: '+300 XP',
        matches: (spot) => spot.points >= (rarityPoints['Rare'] ?? 75),
        weekOnly: true,
      ),
      _SpotChallenge(
        title: 'Culture Mix',
        description: 'Spot 3 different categories.',
        targetCount: 3,
        bonusLabel: 'Badge',
        matches: (_) => true,
        weekOnly: true,
        uniqueCategoryProgress: true,
      ),
      _SpotChallenge(
        title: 'Proof Hunter',
        description: 'Capture 2 spots using camera.',
        targetCount: 2,
        bonusLabel: '+200 XP',
        matches: (spot) => spot.captureSource == 'camera',
        weekOnly: true,
      ),
    ];
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.userSpots});

  final _SpotChallenge challenge;
  final List<CarSpot> userSpots;

  @override
  Widget build(BuildContext context) {
    final progress = challenge.progress(userSpots);
    final isComplete = progress >= challenge.targetCount;

    return RvGlass(
      glowColor: isComplete ? RvColors.emerald : RvColors.crimson,
      borderColor: isComplete
          ? RvColors.emerald.withValues(alpha: 0.38)
          : RvColors.border,
      width: 226,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle_rounded : Icons.flag_rounded,
                color: isComplete ? RvColors.emerald : RvColors.crimson,
              ),
              const Spacer(),
              Text(
                challenge.bonusLabel,
                style: const TextStyle(
                  color: RvColors.crimson,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: RvColors.mutedText, height: 1.25),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: challenge.progressValue(userSpots),
              minHeight: 8,
              backgroundColor: RvColors.glassStrong,
              color: isComplete ? RvColors.emerald : RvColors.crimson,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$progress/${challenge.targetCount} complete',
            style: const TextStyle(
              color: RvColors.mutedText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotChallenge {
  const _SpotChallenge({
    required this.title,
    required this.description,
    required this.targetCount,
    required this.bonusLabel,
    required this.matches,
    this.mustBeToday = false,
    this.weekOnly = false,
    this.uniqueCategoryProgress = false,
  });

  final String title;
  final String description;
  final int targetCount;
  final String bonusLabel;
  final bool Function(CarSpot spot) matches;
  final bool mustBeToday;
  final bool weekOnly;
  final bool uniqueCategoryProgress;

  int progress(List<CarSpot> spots) {
    final matched = spots.where((spot) {
      if (mustBeToday && !_isSameDay(spot.createdAt, DateTime.now())) {
        return false;
      }
      if (weekOnly && !_isThisWeek(spot.createdAt)) {
        return false;
      }
      return matches(spot);
    }).toList();

    if (uniqueCategoryProgress) {
      return matched.map((spot) => spot.category).toSet().length;
    }

    return matched.length;
  }

  double progressValue(List<CarSpot> spots) {
    if (targetCount <= 0) {
      return 1;
    }
    return (progress(spots) / targetCount).clamp(0, 1).toDouble();
  }
}

bool _isBike(CarSpot spot) {
  return spot.category == 'Bikes' ||
      spot.category == 'Superbikes' ||
      spot.category == 'Cruisers' ||
      spot.category == 'Adventure Bikes' ||
      spot.category == 'Dirt Bikes' ||
      spot.category == 'Scooters';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isThisWeek(DateTime date) {
  final now = DateTime.now();
  final startOfWeek = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));
  return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
}

class _Header extends StatelessWidget {
  const _Header({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: RvColors.crimson),
              const SizedBox(width: 8),
              Text(
                'Racers Vault',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: RvColors.text,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'Notifications',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Tonight in ${currentUser.city}',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: RvColors.text,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Scan the street. Reveal rarity. Build the vault.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RvColors.mutedText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({
    required this.totalPoints,
    required this.carsSpotted,
    required this.rank,
  });

  final int totalPoints;
  final int carsSpotted;
  final String rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        scrollDirection: Axis.horizontal,
        children: [
          ScoreTile(label: 'Your rank', value: rank, icon: Icons.flag_rounded),
          ScoreTile(
            label: 'Your points',
            value: '$totalPoints',
            icon: Icons.bolt_rounded,
          ),
          ScoreTile(
            label: 'Feed spots',
            value: '$carsSpotted',
            icon: Icons.photo_camera_rounded,
          ),
        ],
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.selectedCategory,
    required this.onSelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = spotCategories[index];
          return ChoiceChip(
            selected: category == selectedCategory,
            label: Text(category),
            avatar: Icon(_iconForCategory(category), size: 18),
            onSelected: (_) => onSelected(category),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: spotCategories.length,
      ),
    );
  }

  IconData _iconForCategory(String category) {
    return switch (category) {
      'Bikes' ||
      'Superbikes' ||
      'Cruisers' ||
      'Adventure Bikes' ||
      'Dirt Bikes' ||
      'Scooters' => Icons.two_wheeler_rounded,
      'Hot Wheels' => Icons.toys_rounded,
      'RC' => Icons.settings_remote_rounded,
      'Karts' => Icons.sports_motorsports_rounded,
      'EVs' => Icons.electric_car_rounded,
      'Off-road' || 'Trucks' => Icons.local_shipping_rounded,
      'Luxury' => Icons.diamond_rounded,
      'Hypercars' || 'Supercars' || 'Sports Cars' => Icons.speed_rounded,
      allCategory => Icons.grid_view_rounded,
      _ => Icons.directions_car_rounded,
    };
  }
}
