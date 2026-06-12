import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/rarity_data.dart';
import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../widgets/page_title.dart';
import '../widgets/rv_glass.dart';
import '../widgets/stats.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.spots,
    required this.currentUser,
    required this.onSpotSelected,
    required this.onScanRequested,
  });

  final List<CarSpot> spots;
  final AppUser currentUser;
  final ValueChanged<CarSpot> onSpotSelected;
  final VoidCallback onScanRequested;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  String _selectedCategory = allCategory;
  _SpotCluster? _selectedCluster;

  @override
  Widget build(BuildContext context) {
    final clusters = _clusters;
    final nearbyClusters = clusters
        .where((cluster) => cluster.country == widget.currentUser.country)
        .toList();
    final activeCluster = _selectedCluster;
    final activeSpots = activeCluster == null
        ? _filteredSpots.take(6).toList()
        : activeCluster.spots;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
      children: [
        const PageTitle(
          icon: Icons.travel_explore_rounded,
          title: 'Discover',
          subtitle:
              'Explore nearby vault activity with privacy-safe city clusters.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 94,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ScoreTile(
                label: 'City clusters',
                value: '${clusters.length}',
                icon: Icons.hub_rounded,
              ),
              ScoreTile(
                label: 'In country',
                value: '${nearbyClusters.length}',
                icon: Icons.flag_rounded,
              ),
              ScoreTile(
                label: 'Discoverable',
                value: '${_filteredSpots.length}',
                icon: Icons.radar_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CategoryRail(
          selectedCategory: _selectedCategory,
          onSelected: (category) {
            setState(() {
              _selectedCategory = category;
              _selectedCluster = null;
            });
          },
        ),
        const SizedBox(height: 14),
        _ClusterMap(
          clusters: clusters,
          currentUser: widget.currentUser,
          selectedCluster: activeCluster,
          onClusterSelected: (cluster) {
            setState(() {
              _selectedCluster = cluster;
            });
          },
        ),
        const SizedBox(height: 14),
        _DiscoverChallengeSheet(
          currentUser: widget.currentUser,
          spots: widget.spots,
          visibleSpots: _filteredSpots,
        ),
        const SizedBox(height: 14),
        if (clusters.isEmpty)
          EmptyState(
            icon: widget.spots.isEmpty
                ? Icons.map_outlined
                : Icons.filter_alt_off_rounded,
            title: widget.spots.isEmpty
                ? 'No spots to map yet'
                : 'No ${_selectedCategory.toLowerCase()} nearby',
            message: widget.spots.isEmpty
                ? 'Add the first spot and Discover will light up your city.'
                : 'This filter has no map results yet. Clear it to return to every discoverable spot.',
            actionLabel: widget.spots.isEmpty
                ? 'Add city spot'
                : 'Clear filter',
            actionIcon: widget.spots.isEmpty
                ? Icons.radar_rounded
                : Icons.close_rounded,
            onAction: widget.spots.isEmpty
                ? widget.onScanRequested
                : () {
                    setState(() {
                      _selectedCategory = allCategory;
                      _selectedCluster = null;
                    });
                  },
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  activeCluster == null
                      ? 'Latest discoverable spots'
                      : '${activeCluster.city} cluster',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (activeCluster != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCluster = null;
                    });
                  },
                  child: const Text('All'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final spot in activeSpots) ...[
            _DiscoverSpotTile(
              spot: spot,
              onTap: () => widget.onSpotSelected(spot),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  List<CarSpot> get _filteredSpots {
    final spots = _selectedCategory == allCategory
        ? widget.spots
        : widget.spots
              .where((spot) => spot.category == _selectedCategory)
              .toList();
    return [...spots]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<_SpotCluster> get _clusters {
    final groups = <String, List<CarSpot>>{};
    for (final spot in _filteredSpots) {
      final key = '${spot.city}|${spot.country}';
      groups.putIfAbsent(key, () => []).add(spot);
    }

    final clusters = groups.entries.map((entry) {
      final parts = entry.key.split('|');
      return _SpotCluster(
        city: parts.first,
        country: parts.length > 1 ? parts[1] : '',
        spots: entry.value,
      );
    }).toList()..sort((a, b) => b.points.compareTo(a.points));
    return clusters;
  }
}

class _DiscoverChallengeSheet extends StatelessWidget {
  const _DiscoverChallengeSheet({
    required this.currentUser,
    required this.spots,
    required this.visibleSpots,
  });

  final AppUser currentUser;
  final List<CarSpot> spots;
  final List<CarSpot> visibleSpots;

  @override
  Widget build(BuildContext context) {
    final active = _activeChallenges;
    final inProgress = active
        .where((challenge) => challenge.progress > 0)
        .length;
    final completed = active.where((challenge) => challenge.complete).length;
    final totalBonus = active.fold<int>(
      0,
      (total, challenge) => total + (challenge.complete ? challenge.points : 0),
    );

    return RvGlass(
      padding: const EdgeInsets.all(16),
      glowColor: RvColors.emerald,
      borderColor: RvColors.emerald.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Daily Challenges',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: RvColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              const Text(
                'View All',
                style: TextStyle(
                  color: RvColors.emerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete challenges to earn bonus points.',
            style: TextStyle(color: RvColors.mutedText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ChallengeStat(
                value: '${active.length}',
                label: 'Active',
                color: RvColors.emerald,
              ),
              _ChallengeStat(
                value: '$inProgress',
                label: 'In progress',
                color: RvColors.hyperOrange,
              ),
              _ChallengeStat(
                value: '$completed',
                label: 'Completed',
                color: RvColors.electricBlue,
              ),
              _ChallengeStat(
                value: '$totalBonus',
                label: 'Points',
                color: RvColors.crimson,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: RvColors.border),
          const SizedBox(height: 8),
          for (final challenge in active.take(2)) ...[
            _DiscoverChallengeRow(challenge: challenge),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: RvColors.emerald),
              const SizedBox(width: 8),
              const Text(
                'Reset in:',
                style: TextStyle(
                  color: RvColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                _resetCountdown,
                style: const TextStyle(
                  color: RvColors.emerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_DiscoverChallenge> get _activeChallenges {
    final todaySpots = spots
        .where((spot) => _isSameDay(spot.createdAt))
        .toList();
    return [
      _DiscoverChallenge(
        title: 'City sweep',
        description: 'Spot 2 vehicles in ${currentUser.city}.',
        progress: todaySpots
            .where((spot) => spot.city == currentUser.city)
            .length
            .clamp(0, 2),
        target: 2,
        points: 100,
      ),
      _DiscoverChallenge(
        title: 'Rare ping',
        description: 'Find 1 Rare or better vehicle today.',
        progress: todaySpots
            .where((spot) => spot.points >= (rarityPoints['Rare'] ?? 75))
            .length
            .clamp(0, 1),
        target: 1,
        points: 150,
      ),
      _DiscoverChallenge(
        title: 'Map scout',
        description: 'Reveal 3 discoverable spots with filters.',
        progress: visibleSpots.length.clamp(0, 3),
        target: 3,
        points: 75,
      ),
    ];
  }

  String get _resetCountdown {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final remaining = tomorrow.difference(now);
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }
}

class _ChallengeStat extends StatelessWidget {
  const _ChallengeStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RvColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DiscoverChallengeRow extends StatelessWidget {
  const _DiscoverChallengeRow({required this.challenge});

  final _DiscoverChallenge challenge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          challenge.complete ? Icons.check_circle_rounded : Icons.flag_rounded,
          color: challenge.complete ? RvColors.emerald : RvColors.hyperOrange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.title,
                style: const TextStyle(
                  color: RvColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                challenge.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: RvColors.mutedText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${challenge.progress}/${challenge.target}',
          style: const TextStyle(
            color: RvColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DiscoverChallenge {
  const _DiscoverChallenge({
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.points,
  });

  final String title;
  final String description;
  final int progress;
  final int target;
  final int points;

  bool get complete => progress >= target;
}

bool _isSameDay(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

class _ClusterMap extends StatelessWidget {
  const _ClusterMap({
    required this.clusters,
    required this.currentUser,
    required this.selectedCluster,
    required this.onClusterSelected,
  });

  final List<_SpotCluster> clusters;
  final AppUser currentUser;
  final _SpotCluster? selectedCluster;
  final ValueChanged<_SpotCluster> onClusterSelected;

  @override
  Widget build(BuildContext context) {
    final visibleClusters = clusters.take(8).toList();
    final center = _mapCenter(visibleClusters, currentUser);
    final zoom = visibleClusters.length <= 1 ? 10 : 4;

    return AspectRatio(
      aspectRatio: 1.12,
      child: RvGlass(
        padding: EdgeInsets.zero,
        radius: 24,
        borderColor: RvColors.electricBlue.withValues(alpha: 0.3),
        glowColor: RvColors.electricBlue,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: _OsmTileMap(
                center: center,
                zoom: zoom,
                clusters: visibleClusters,
                selectedCluster: selectedCluster,
                clusterPoint: _clusterPoint,
                onClusterSelected: onClusterSelected,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        RvColors.obsidian.withValues(alpha: 0.18),
                        Colors.transparent,
                        RvColors.obsidian.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: _MapLabel(
                icon: Icons.privacy_tip_rounded,
                label: 'Exact locations hidden',
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: _MapLabel(
                icon: Icons.my_location_rounded,
                label: currentUser.city,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 12,
              child: _MapLabel(icon: Icons.map_rounded, label: 'OpenStreetMap'),
            ),
          ],
        ),
      ),
    );
  }

  _MapCoordinate _mapCenter(
    List<_SpotCluster> visibleClusters,
    AppUser currentUser,
  ) {
    if (visibleClusters.isEmpty) {
      return _coordinateForCity(currentUser.city, currentUser.country);
    }

    final points = [
      for (var i = 0; i < visibleClusters.length; i++)
        _clusterPoint(visibleClusters[i], i),
    ];
    final latitude =
        points.fold<double>(0, (total, point) => total + point.latitude) /
        points.length;
    final longitude =
        points.fold<double>(0, (total, point) => total + point.longitude) /
        points.length;
    return _MapCoordinate(latitude, longitude);
  }

  _MapCoordinate _clusterPoint(_SpotCluster cluster, int index) {
    final base = _coordinateForCity(cluster.city, cluster.country);
    final offset = _privacyOffset(cluster.key, index);
    return _MapCoordinate(
      base.latitude + offset.latitude,
      base.longitude + offset.longitude,
    );
  }
}

class _OsmTileMap extends StatelessWidget {
  const _OsmTileMap({
    required this.center,
    required this.zoom,
    required this.clusters,
    required this.selectedCluster,
    required this.clusterPoint,
    required this.onClusterSelected,
  });

  static const _tileSize = 256.0;

  final _MapCoordinate center;
  final int zoom;
  final List<_SpotCluster> clusters;
  final _SpotCluster? selectedCluster;
  final _MapCoordinate Function(_SpotCluster cluster, int index) clusterPoint;
  final ValueChanged<_SpotCluster> onClusterSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final centerTile = _tileForCoordinate(center, zoom);
        final centerTileX = centerTile.x.floor();
        final centerTileY = centerTile.y.floor();
        final radiusX = (width / _tileSize).ceil() + 1;
        final radiusY = (height / _tileSize).ceil() + 1;

        return InteractiveViewer(
          minScale: 1,
          maxScale: 2.4,
          boundaryMargin: const EdgeInsets.all(160),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (
                  var x = centerTileX - radiusX;
                  x <= centerTileX + radiusX;
                  x++
                )
                  for (
                    var y = centerTileY - radiusY;
                    y <= centerTileY + radiusY;
                    y++
                  )
                    _MapTile(
                      zoom: zoom,
                      x: x,
                      y: y,
                      left: width / 2 + (x - centerTile.x) * _tileSize,
                      top: height / 2 + (y - centerTile.y) * _tileSize,
                      size: _tileSize,
                    ),
                for (var i = 0; i < clusters.length; i++)
                  _ClusterPositionedMarker(
                    cluster: clusters[i],
                    point: clusterPoint(clusters[i], i),
                    centerTile: centerTile,
                    zoom: zoom,
                    width: width,
                    height: height,
                    selected: selectedCluster?.key == clusters[i].key,
                    onTap: () => onClusterSelected(clusters[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({
    required this.zoom,
    required this.x,
    required this.y,
    required this.left,
    required this.top,
    required this.size,
  });

  final int zoom;
  final int x;
  final int y;
  final double left;
  final double top;
  final double size;

  @override
  Widget build(BuildContext context) {
    final maxTile = 1 << zoom;
    if (y < 0 || y >= maxTile) {
      return const SizedBox.shrink();
    }
    final wrappedX = x % maxTile < 0 ? x % maxTile + maxTile : x % maxTile;

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.42,
          0.08,
          0.08,
          0,
          8,
          0.08,
          0.44,
          0.08,
          0,
          10,
          0.08,
          0.08,
          0.54,
          0,
          18,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: Image.network(
          'https://tile.openstreetmap.org/$zoom/$wrappedX/$y.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) => Container(
            color: RvColors.graphite,
            child: CustomPaint(painter: const _FallbackTilePainter()),
          ),
        ),
      ),
    );
  }
}

class _ClusterPositionedMarker extends StatelessWidget {
  const _ClusterPositionedMarker({
    required this.cluster,
    required this.point,
    required this.centerTile,
    required this.zoom,
    required this.width,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final _SpotCluster cluster;
  final _MapCoordinate point;
  final _TileCoordinate centerTile;
  final int zoom;
  final double width;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markerTile = _tileForCoordinate(point, zoom);
    final left = width / 2 + (markerTile.x - centerTile.x) * 256 - 46;
    final top = height / 2 + (markerTile.y - centerTile.y) * 256 - 46;

    return Positioned(
      left: left,
      top: top,
      width: 92,
      height: 92,
      child: _ClusterMarker(cluster: cluster, selected: selected, onTap: onTap),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.cluster,
    required this.selected,
    required this.onTap,
  });

  final _SpotCluster cluster;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = (48 + cluster.spots.length * 6).clamp(48, 78).toDouble();
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${cluster.city} cluster, ${cluster.spots.length} spots',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? size + 8 : size,
            height: selected ? size + 8 : size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: selected
                    ? const [RvColors.legendary, RvColors.hyperOrange]
                    : const [RvColors.electricBlue, RvColors.crimson],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (selected ? RvColors.legendary : RvColors.electricBlue)
                      .withValues(alpha: 0.42),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cluster.spots.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  cluster.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
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

class _DiscoverSpotTile extends StatelessWidget {
  const _DiscoverSpotTile({required this.spot, required this.onTap});

  final CarSpot spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: EdgeInsets.zero,
      glowColor: RvColors.rarity(spot.rarity),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: RvColors.rarity(spot.rarity).withValues(alpha: 0.18),
          child: Icon(_iconForCategory(spot.category), color: RvColors.text),
        ),
        title: Text(
          spot.carName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: RvColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${spot.city}, ${spot.country} - ${spot.rarity}',
          style: const TextStyle(color: RvColors.mutedText),
        ),
        trailing: Text(
          '${spot.points}',
          style: const TextStyle(
            color: RvColors.crimson,
            fontWeight: FontWeight.w900,
          ),
        ),
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
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: spotCategories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = spotCategories[index];
          return ChoiceChip(
            label: Text(category),
            avatar: Icon(_iconForCategory(category), size: 18),
            selected: selectedCategory == category,
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}

class _SpotCluster {
  const _SpotCluster({
    required this.city,
    required this.country,
    required this.spots,
  });

  final String city;
  final String country;
  final List<CarSpot> spots;

  String get key => '$city|$country';
  int get points => spots.fold(0, (total, spot) => total + spot.points);
}

_MapCoordinate _coordinateForCity(String city, String country) {
  final key = '${city.trim().toLowerCase()}|${country.trim().toLowerCase()}';
  return _knownCityCoordinates[key] ??
      _countryCoordinate(country) ??
      _fallbackCoordinate(key);
}

_MapCoordinate? _countryCoordinate(String country) {
  return _knownCountryCoordinates[country.trim().toLowerCase()];
}

_MapCoordinate _privacyOffset(String key, int index) {
  final seed = key.codeUnits.fold<int>(
    index * 17,
    (value, unit) => value + unit,
  );
  final latOffset = ((seed % 7) - 3) * 0.018;
  final lngOffset = (((seed ~/ 7) % 7) - 3) * 0.018;
  return _MapCoordinate(latOffset, lngOffset);
}

_MapCoordinate _fallbackCoordinate(String key) {
  final seed = key.codeUnits.fold<int>(0, (value, unit) => value + unit);
  final latitude = ((seed % 1200) / 10) - 60;
  final longitude = (((seed ~/ 11) % 3000) / 10) - 150;
  return _MapCoordinate(latitude, longitude);
}

const _knownCityCoordinates = <String, _MapCoordinate>{
  'mumbai|india': _MapCoordinate(19.0760, 72.8777),
  'bengaluru|india': _MapCoordinate(12.9716, 77.5946),
  'bangalore|india': _MapCoordinate(12.9716, 77.5946),
  'delhi|india': _MapCoordinate(28.6139, 77.2090),
  'new delhi|india': _MapCoordinate(28.6139, 77.2090),
  'chennai|india': _MapCoordinate(13.0827, 80.2707),
  'hyderabad|india': _MapCoordinate(17.3850, 78.4867),
  'pune|india': _MapCoordinate(18.5204, 73.8567),
  'kolkata|india': _MapCoordinate(22.5726, 88.3639),
  'ahmedabad|india': _MapCoordinate(23.0225, 72.5714),
  'kochi|india': _MapCoordinate(9.9312, 76.2673),
  'dubai|uae': _MapCoordinate(25.2048, 55.2708),
  'abu dhabi|uae': _MapCoordinate(24.4539, 54.3773),
  'london|uk': _MapCoordinate(51.5072, -0.1276),
  'london|united kingdom': _MapCoordinate(51.5072, -0.1276),
  'los angeles|usa': _MapCoordinate(34.0522, -118.2437),
  'los angeles|united states': _MapCoordinate(34.0522, -118.2437),
  'new york|usa': _MapCoordinate(40.7128, -74.0060),
  'new york|united states': _MapCoordinate(40.7128, -74.0060),
  'tokyo|japan': _MapCoordinate(35.6762, 139.6503),
  'singapore|singapore': _MapCoordinate(1.3521, 103.8198),
  'paris|france': _MapCoordinate(48.8566, 2.3522),
  'berlin|germany': _MapCoordinate(52.5200, 13.4050),
  'stuttgart|germany': _MapCoordinate(48.7758, 9.1829),
  'munich|germany': _MapCoordinate(48.1351, 11.5820),
  'milan|italy': _MapCoordinate(45.4642, 9.1900),
  'monaco|monaco': _MapCoordinate(43.7384, 7.4246),
};

const _knownCountryCoordinates = <String, _MapCoordinate>{
  'india': _MapCoordinate(22.9734, 78.6569),
  'uae': _MapCoordinate(23.4241, 53.8478),
  'united arab emirates': _MapCoordinate(23.4241, 53.8478),
  'usa': _MapCoordinate(39.8283, -98.5795),
  'united states': _MapCoordinate(39.8283, -98.5795),
  'uk': _MapCoordinate(55.3781, -3.4360),
  'united kingdom': _MapCoordinate(55.3781, -3.4360),
  'japan': _MapCoordinate(36.2048, 138.2529),
  'germany': _MapCoordinate(51.1657, 10.4515),
  'italy': _MapCoordinate(41.8719, 12.5674),
  'france': _MapCoordinate(46.2276, 2.2137),
  'singapore': _MapCoordinate(1.3521, 103.8198),
};

class _MapCoordinate {
  const _MapCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _TileCoordinate {
  const _TileCoordinate(this.x, this.y);

  final double x;
  final double y;
}

_TileCoordinate _tileForCoordinate(_MapCoordinate coordinate, int zoom) {
  final clampedLatitude = coordinate.latitude.clamp(-85.0511, 85.0511);
  final latRad = clampedLatitude * math.pi / 180;
  final scale = (1 << zoom).toDouble();
  final x = (coordinate.longitude + 180) / 360 * scale;
  final y =
      (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
      2 *
      scale;
  return _TileCoordinate(x, y);
}

class _FallbackTilePainter extends CustomPainter {
  const _FallbackTilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x + 32, size.height), gridPaint);
    }
    for (double y = 22; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 28), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FallbackTilePainter oldDelegate) => false;
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
