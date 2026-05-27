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
  });

  final List<CarSpot> spots;
  final AppUser currentUser;
  final ValueChanged<CarSpot> onSpotSelected;

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
        if (clusters.isEmpty)
          const EmptyState(
            icon: Icons.map_outlined,
            title: 'No spots to map yet',
            message: 'Add the first spot and Discover will light up your city.',
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
            const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
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
            for (var i = 0; i < visibleClusters.length; i++)
              _ClusterMarker(
                cluster: visibleClusters[i],
                alignment: _markerAlignment(i),
                selected: selectedCluster?.key == visibleClusters[i].key,
                onTap: () => onClusterSelected(visibleClusters[i]),
              ),
          ],
        ),
      ),
    );
  }

  Alignment _markerAlignment(int index) {
    const alignments = [
      Alignment(-0.58, -0.32),
      Alignment(0.2, -0.52),
      Alignment(0.62, -0.12),
      Alignment(-0.18, 0.05),
      Alignment(-0.7, 0.38),
      Alignment(0.42, 0.44),
      Alignment(-0.02, 0.62),
      Alignment(0.78, 0.62),
    ];
    return alignments[index % alignments.length];
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.cluster,
    required this.alignment,
    required this.selected,
    required this.onTap,
  });

  final _SpotCluster cluster;
  final Alignment alignment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = (48 + cluster.spots.length * 6).clamp(48, 78).toDouble();
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: onTap,
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

class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = -size.width; x < size.width * 2; x += 42) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.58, size.height),
        gridPaint,
      );
    }
    for (double y = 22; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 28), gridPaint);
    }

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    final accentRoadPaint = Paint()
      ..color = RvColors.electricBlue.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final route = Path()
      ..moveTo(size.width * 0.08, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.42,
        size.width * 0.48,
        size.height * 0.54,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.65,
        size.width * 0.9,
        size.height * 0.28,
      );
    canvas.drawPath(route, roadPaint);
    canvas.drawPath(route, accentRoadPaint);

    final zonePaint = Paint()..color = RvColors.crimson.withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.5),
      size.shortestSide * 0.36,
      zonePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => false;
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
