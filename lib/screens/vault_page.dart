import 'package:flutter/material.dart';

import '../data/rarity_data.dart';
import '../data/registry_data.dart';
import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../widgets/page_title.dart';
import '../widgets/rv_glass.dart';
import '../widgets/spot_card.dart';
import '../widgets/stats.dart';

enum _GarageSort { newest, points, rarity }

class VaultPage extends StatefulWidget {
  const VaultPage({
    super.key,
    required this.spots,
    required this.totalPoints,
    required this.currentUser,
    required this.onSpotSelected,
    required this.onScanRequested,
  });

  final List<CarSpot> spots;
  final int totalPoints;
  final AppUser currentUser;
  final ValueChanged<CarSpot> onSpotSelected;
  final VoidCallback onScanRequested;

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = allCategory;
  String _selectedRarity = allCategory;
  _GarageSort _sort = _GarageSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _availableCategories {
    final categories =
        widget.spots
            .map((spot) => spot.category)
            .where((category) => category.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [allCategory, ...categories];
  }

  List<String> get _availableRarities {
    final rarities =
        widget.spots
            .map((spot) => spot.rarity)
            .where((rarity) => rarity.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (a, b) => (rarityPoints[a] ?? 0).compareTo(rarityPoints[b] ?? 0),
          );
    return [allCategory, ...rarities];
  }

  List<CarSpot> get _filteredSpots {
    final normalizedQuery = _query.trim().toLowerCase();
    final results = widget.spots.where((spot) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          spot.carName.toLowerCase().contains(normalizedQuery) ||
          spot.category.toLowerCase().contains(normalizedQuery) ||
          spot.rarity.toLowerCase().contains(normalizedQuery) ||
          spot.city.toLowerCase().contains(normalizedQuery) ||
          spot.country.toLowerCase().contains(normalizedQuery);
      final matchesCategory =
          _selectedCategory == allCategory ||
          spot.category == _selectedCategory;
      final matchesRarity =
          _selectedRarity == allCategory || spot.rarity == _selectedRarity;
      return matchesQuery && matchesCategory && matchesRarity;
    }).toList();

    switch (_sort) {
      case _GarageSort.newest:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _GarageSort.points:
        results.sort((a, b) => b.points.compareTo(a.points));
      case _GarageSort.rarity:
        results.sort(
          (a, b) => (rarityPoints[b.rarity] ?? b.points).compareTo(
            rarityPoints[a.rarity] ?? a.points,
          ),
        );
    }
    return results;
  }

  int get _uniqueCategoryCount =>
      widget.spots.map((spot) => spot.category).toSet().length;

  CarSpot? get _rarestSpot {
    if (widget.spots.isEmpty) return null;
    final sorted = [...widget.spots]
      ..sort((a, b) => b.points.compareTo(a.points));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final filteredSpots = _filteredSpots;
    final rarestSpot = _rarestSpot;
    final registry = RegistryProgress.fromSpots(widget.spots);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
      children: [
        PageTitle(
          icon: Icons.garage_rounded,
          title: '${widget.currentUser.username} Vault',
          subtitle: widget.spots.isEmpty
              ? 'Your submitted car spots will appear here.'
              : '${widget.totalPoints} points across ${widget.spots.length} spots.',
        ),
        const SizedBox(height: 16),
        if (widget.spots.isEmpty)
          EmptyState(
            icon: Icons.add_a_photo_rounded,
            title: 'Your vault is waiting',
            message: 'Scan a car to create your first collectible garage card.',
            actionLabel: 'Start scanning',
            actionIcon: Icons.photo_camera_rounded,
            onAction: widget.onScanRequested,
          )
        else ...[
          SizedBox(
            height: 94,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ScoreTile(
                  label: 'Vault points',
                  value: widget.totalPoints.toString(),
                  icon: Icons.bolt_rounded,
                ),
                ScoreTile(
                  label: 'Spots saved',
                  value: widget.spots.length.toString(),
                  icon: Icons.collections_bookmark_rounded,
                ),
                ScoreTile(
                  label: 'Categories',
                  value: _uniqueCategoryCount.toString(),
                  icon: Icons.category_rounded,
                ),
                ScoreTile(
                  label: 'Registry',
                  value: '${registry.vehiclePercent}%',
                  icon: Icons.pie_chart_rounded,
                ),
                ScoreTile(
                  label: 'Best find',
                  value: rarestSpot == null ? '-' : rarestSpot.rarity,
                  icon: Icons.workspace_premium_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _RegistryPanel(registry: registry),
          const SizedBox(height: 16),
          _GarageControls(
            searchController: _searchController,
            query: _query,
            selectedCategory: _selectedCategory,
            selectedRarity: _selectedRarity,
            sort: _sort,
            categories: _availableCategories,
            rarities: _availableRarities,
            onQueryChanged: (value) => setState(() => _query = value),
            onCategoryChanged: (value) =>
                setState(() => _selectedCategory = value),
            onRarityChanged: (value) => setState(() => _selectedRarity = value),
            onSortChanged: (value) => setState(() => _sort = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${filteredSpots.length} garage ${filteredSpots.length == 1 ? 'card' : 'cards'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_query.isNotEmpty ||
                  _selectedCategory != allCategory ||
                  _selectedRarity != allCategory)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _selectedCategory = allCategory;
                      _selectedRarity = allCategory;
                    });
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredSpots.isEmpty)
            const EmptyState(
              icon: Icons.manage_search_rounded,
              title: 'No matches in this garage',
              message: 'Try a different search, category, or rarity filter.',
            )
          else
            for (final spot in filteredSpots) ...[
              SpotCard(spot: spot, onTap: () => widget.onSpotSelected(spot)),
              const SizedBox(height: 14),
            ],
        ],
      ],
    );
  }
}

class _RegistryPanel extends StatelessWidget {
  const _RegistryPanel({required this.registry});

  final RegistryProgress registry;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: RvColors.electricBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.manage_search_rounded,
                color: RvColors.electricBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Registry',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: RvColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${registry.vehiclePercent}%',
                style: const TextStyle(
                  color: RvColors.electricBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RegistryProgressRow(
            label: 'Vehicles identified',
            value: '${registry.uniqueVehicles}/${registry.totalVehicles}',
            progress: registry.uniqueVehicles / registry.totalVehicles,
          ),
          const SizedBox(height: 10),
          _RegistryProgressRow(
            label: 'Collectible cards',
            value: '${registry.uniqueCards}/${registry.totalCards}',
            progress: registry.uniqueCards / registry.totalCards,
          ),
        ],
      ),
    );
  }
}

class _RegistryProgressRow extends StatelessWidget {
  const _RegistryProgressRow({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: RvColors.mutedText,
                  fontWeight: FontWeight.w800,
                ),
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: progress.clamp(0, 1),
            backgroundColor: RvColors.graphiteLight,
            color: RvColors.electricBlue,
          ),
        ),
      ],
    );
  }
}

class _GarageControls extends StatelessWidget {
  const _GarageControls({
    required this.searchController,
    required this.query,
    required this.selectedCategory,
    required this.selectedRarity,
    required this.sort,
    required this.categories,
    required this.rarities,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onRarityChanged,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final String query;
  final String selectedCategory;
  final String selectedRarity;
  final _GarageSort sort;
  final List<String> categories;
  final List<String> rarities;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onRarityChanged;
  final ValueChanged<_GarageSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search garage',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _ChoiceRail(
          label: 'Category',
          values: categories,
          selectedValue: selectedCategory,
          onSelected: onCategoryChanged,
        ),
        const SizedBox(height: 10),
        _ChoiceRail(
          label: 'Rarity',
          values: rarities,
          selectedValue: selectedRarity,
          onSelected: onRarityChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<_GarageSort>(
          initialValue: sort,
          dropdownColor: RvColors.graphite,
          decoration: const InputDecoration(
            labelText: 'Sort garage',
            prefixIcon: Icon(Icons.tune_rounded),
          ),
          items: const [
            DropdownMenuItem(
              value: _GarageSort.newest,
              child: Text('Newest first'),
            ),
            DropdownMenuItem(
              value: _GarageSort.points,
              child: Text('Highest points'),
            ),
            DropdownMenuItem(
              value: _GarageSort.rarity,
              child: Text('Rarest tier'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onSortChanged(value);
          },
        ),
      ],
    );
  }
}

class _ChoiceRail extends StatelessWidget {
  const _ChoiceRail({
    required this.label,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  final String label;
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: RvColors.titanium,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final value = values[index];
              return ChoiceChip(
                label: Text(value),
                selected: selectedValue == value,
                onSelected: (_) => onSelected(value),
              );
            },
          ),
        ),
      ],
    );
  }
}
