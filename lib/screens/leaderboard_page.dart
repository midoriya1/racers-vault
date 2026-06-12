import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../widgets/page_title.dart';
import '../widgets/rv_glass.dart';
import '../widgets/stats.dart';

enum _RankScope { global, country, city }

enum _RankPeriod { allTime, weekly }

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({
    super.key,
    required this.spots,
    required this.currentUser,
    required this.onSpotterSelected,
  });

  final List<CarSpot> spots;
  final AppUser currentUser;
  final ValueChanged<String> onSpotterSelected;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  _RankScope _scope = _RankScope.country;
  _RankPeriod _period = _RankPeriod.allTime;

  @override
  Widget build(BuildContext context) {
    final rankedEntries = _rankedEntries;
    final currentUserRank = _rankForUser(rankedEntries);
    final currentUserEntry = _entryForUser(rankedEntries);
    final topScore = rankedEntries.isEmpty ? 0 : rankedEntries.first.points;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
      children: [
        PageTitle(
          icon: Icons.emoji_events_rounded,
          title: _title,
          subtitle: _subtitle,
        ),
        const SizedBox(height: 16),
        _RankControls(
          scope: _scope,
          period: _period,
          onScopeChanged: (scope) => setState(() => _scope = scope),
          onPeriodChanged: (period) => setState(() => _period = period),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 94,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ScoreTile(
                label: 'Your rank',
                value: currentUserRank == null ? '-' : '#$currentUserRank',
                icon: Icons.flag_rounded,
              ),
              ScoreTile(
                label: 'Top score',
                value: '$topScore',
                icon: Icons.bolt_rounded,
              ),
              ScoreTile(
                label: 'Spotters',
                value: '${rankedEntries.length}',
                icon: Icons.groups_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rankedEntries.isEmpty)
          const EmptyState(
            icon: Icons.emoji_events_rounded,
            title: 'No ranking yet',
            message: 'The first verified spot will claim the top rank.',
          )
        else ...[
          _PinnedRankCard(
            rank: currentUserRank,
            period: _period,
            currentUser: widget.currentUser,
            entry: currentUserEntry,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rankedEntries.length; i++)
            _RankingTile(
              rank: i + 1,
              entry: rankedEntries[i],
              isCurrentUser:
                  rankedEntries[i].name == widget.currentUser.username,
              onTap: () => widget.onSpotterSelected(rankedEntries[i].name),
            ),
        ],
      ],
    );
  }

  String get _title {
    return switch (_scope) {
      _RankScope.global => 'Global Rank',
      _RankScope.country => '${widget.currentUser.country} Rank',
      _RankScope.city => '${widget.currentUser.city} Rank',
    };
  }

  String get _subtitle {
    final period = _period == _RankPeriod.weekly ? 'this week' : 'all time';
    return switch (_scope) {
      _RankScope.global => 'Top spotters worldwide, $period.',
      _RankScope.country =>
        'Top spotters in ${widget.currentUser.country}, $period.',
      _RankScope.city => 'Top spotters in ${widget.currentUser.city}, $period.',
    };
  }

  List<_RankEntry> get _rankedEntries {
    final totals = <String, _RankEntryBuilder>{};
    final filtered = widget.spots.where(_spotMatchesFilters);

    for (final spot in filtered) {
      final builder = totals.putIfAbsent(
        spot.spotter,
        () => _RankEntryBuilder(
          name: spot.spotter,
          city: spot.city,
          country: spot.country,
        ),
      );
      builder.addSpot(spot);
    }

    return totals.values.map((builder) => builder.build()).toList()
      ..sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) {
          return points;
        }
        return b.spots.compareTo(a.spots);
      });
  }

  bool _spotMatchesFilters(CarSpot spot) {
    if (_period == _RankPeriod.weekly && !_isThisWeek(spot.createdAt)) {
      return false;
    }

    return switch (_scope) {
      _RankScope.global => true,
      _RankScope.country => spot.country == widget.currentUser.country,
      _RankScope.city =>
        spot.country == widget.currentUser.country &&
            spot.city == widget.currentUser.city,
    };
  }

  int? _rankForUser(List<_RankEntry> entries) {
    final index = entries.indexWhere(
      (entry) => entry.name == widget.currentUser.username,
    );
    if (index == -1) {
      return null;
    }
    return index + 1;
  }

  _RankEntry? _entryForUser(List<_RankEntry> entries) {
    for (final entry in entries) {
      if (entry.name == widget.currentUser.username) {
        return entry;
      }
    }
    return null;
  }
}

class _PinnedRankCard extends StatelessWidget {
  const _PinnedRankCard({
    required this.rank,
    required this.period,
    required this.currentUser,
    required this.entry,
  });

  final int? rank;
  final _RankPeriod period;
  final AppUser currentUser;
  final _RankEntry? entry;

  @override
  Widget build(BuildContext context) {
    final ranked = rank != null && entry != null;
    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: ranked ? RvColors.legendary : RvColors.electricBlue,
      borderColor: ranked
          ? RvColors.legendary.withValues(alpha: 0.42)
          : RvColors.electricBlue.withValues(alpha: 0.28),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ranked ? RvColors.legendary : RvColors.graphite,
            child: Icon(
              ranked ? Icons.emoji_events_rounded : Icons.flag_rounded,
              color: ranked ? RvColors.obsidian : RvColors.electricBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranked ? 'You are #$rank' : 'You are unranked',
                  style: const TextStyle(
                    color: RvColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ranked
                      ? '${entry!.points} pts from ${entry!.spots} spots'
                      : 'Post a verified spot to enter ${currentUser.city}.',
                  style: const TextStyle(color: RvColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            period == _RankPeriod.weekly ? 'Resets Mon' : 'All time',
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

class _RankControls extends StatelessWidget {
  const _RankControls({
    required this.scope,
    required this.period,
    required this.onScopeChanged,
    required this.onPeriodChanged,
  });

  final _RankScope scope;
  final _RankPeriod period;
  final ValueChanged<_RankScope> onScopeChanged;
  final ValueChanged<_RankPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<_RankScope>(
          segments: const [
            ButtonSegment(
              value: _RankScope.global,
              icon: Icon(Icons.public_rounded),
              label: Text('Global'),
            ),
            ButtonSegment(
              value: _RankScope.country,
              icon: Icon(Icons.flag_rounded),
              label: Text('Country'),
            ),
            ButtonSegment(
              value: _RankScope.city,
              icon: Icon(Icons.location_city_rounded),
              label: Text('City'),
            ),
          ],
          selected: {scope},
          onSelectionChanged: (value) => onScopeChanged(value.first),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_RankPeriod>(
          segments: const [
            ButtonSegment(
              value: _RankPeriod.allTime,
              icon: Icon(Icons.all_inclusive_rounded),
              label: Text('All time'),
            ),
            ButtonSegment(
              value: _RankPeriod.weekly,
              icon: Icon(Icons.calendar_view_week_rounded),
              label: Text('Weekly'),
            ),
          ],
          selected: {period},
          onSelectionChanged: (value) => onPeriodChanged(value.first),
        ),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
    required this.onTap,
  });

  final int rank;
  final _RankEntry entry;
  final bool isCurrentUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RvGlass(
          padding: const EdgeInsets.all(14),
          borderColor: isCurrentUser
              ? RvColors.legendary.withValues(alpha: 0.55)
              : RvColors.border,
          glowColor: _rankColor(rank),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _rankColor(rank),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: RvColors.obsidian,
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
                      '@${entry.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: RvColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.city}, ${entry.country} - ${entry.spots} spots - best ${entry.rarestRarity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RvColors.mutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: RvColors.crimson),
                      Text(
                        '${entry.points}',
                        style: const TextStyle(
                          color: RvColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    entry.rarestCar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RvColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _rankColor(int rank) {
    return switch (rank) {
      1 => RvColors.legendary,
      2 => RvColors.titanium,
      3 => RvColors.hyperOrange,
      _ => RvColors.electricBlue,
    };
  }
}

class _RankEntry {
  const _RankEntry({
    required this.name,
    required this.city,
    required this.country,
    required this.points,
    required this.spots,
    required this.rarestCar,
    required this.rarestRarity,
  });

  final String name;
  final String city;
  final String country;
  final int points;
  final int spots;
  final String rarestCar;
  final String rarestRarity;
}

class _RankEntryBuilder {
  _RankEntryBuilder({
    required this.name,
    required this.city,
    required this.country,
  });

  final String name;
  final String city;
  final String country;
  int points = 0;
  int spots = 0;
  CarSpot? rarest;

  void addSpot(CarSpot spot) {
    points += spot.points;
    spots += 1;
    final currentRarest = rarest;
    if (currentRarest == null || spot.points > currentRarest.points) {
      rarest = spot;
    }
  }

  _RankEntry build() {
    final rarestSpot = rarest;
    return _RankEntry(
      name: name,
      city: city,
      country: country,
      points: points,
      spots: spots,
      rarestCar: rarestSpot?.carName ?? 'No spot',
      rarestRarity: rarestSpot?.rarity ?? 'None',
    );
  }
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
