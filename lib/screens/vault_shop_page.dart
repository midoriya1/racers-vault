import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import '../widgets/page_title.dart';
import '../widgets/rv_glass.dart';

class VaultShopPage extends StatefulWidget {
  const VaultShopPage({super.key});

  @override
  State<VaultShopPage> createState() => _VaultShopPageState();
}

class _VaultShopPageState extends State<VaultShopPage> {
  _ShopCategory _category = _ShopCategory.frames;
  late _ShopItem _selected = _shopItems.first;
  final Set<String> _ownedIds = {'carbon_ring', 'starter_badge'};
  final Map<_ShopCategory, String> _equipped = {
    _ShopCategory.frames: 'carbon_ring',
    _ShopCategory.badges: 'starter_badge',
  };

  @override
  Widget build(BuildContext context) {
    const unlockLabel = 'Vault Coins soon';
    final categories = _shopItems
        .map((item) => item.category)
        .toSet()
        .toList(growable: false);
    if (!categories.contains(_category)) {
      _category = categories.first;
    }
    final visibleItems = _shopItems
        .where((item) => item.category == _category)
        .toList();
    if (_selected.category != _category) {
      _selected = visibleItems.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vault Shop')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const PageTitle(
            icon: Icons.storefront_rounded,
            title: 'Vault Shop',
            subtitle: 'Cosmetics for your profile, garage, and scanner.',
          ),
          const SizedBox(height: 16),
          _ShopHero(
            item: _selected,
            owned: _ownedIds.contains(_selected.id),
            equipped: _equipped[_selected.category] == _selected.id,
            unlockLabel: unlockLabel,
            onBuy: () => _buyOrPreview(_selected),
            onEquip: () => _equip(_selected),
          ),
          const SizedBox(height: 16),
          _ShopTabs(
            selected: _category,
            categories: categories,
            onSelected: (category) {
              setState(() {
                _category = category;
                _selected = _shopItems.firstWhere(
                  (item) => item.category == category,
                );
              });
            },
          ),
          const SizedBox(height: 10),
          _CategoryIntro(category: _category),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              return _ShopCard(
                item: item,
                selected: item.id == _selected.id,
                owned: _ownedIds.contains(item.id),
                equipped: _equipped[item.category] == item.id,
                unlockLabel: unlockLabel,
                onTap: () {
                  setState(() {
                    _selected = item;
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _buyOrPreview(_ShopItem item) {
    if (_ownedIds.contains(item.id)) {
      _equip(item);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.name} unlocks are parked for now. Vault Coins are coming soon.',
        ),
      ),
    );
  }

  void _equip(_ShopItem item) {
    if (!_ownedIds.contains(item.id)) {
      _buyOrPreview(item);
      return;
    }
    setState(() {
      _equipped[item.category] = item.id;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.name} equipped')));
  }
}

class _ShopHero extends StatelessWidget {
  const _ShopHero({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.unlockLabel,
    required this.onBuy,
    required this.onEquip,
  });

  final _ShopItem item;
  final bool owned;
  final bool equipped;
  final String unlockLabel;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(16),
      glowColor: item.color,
      borderColor: item.color.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.75,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.color.withValues(alpha: 0.24),
                    RvColors.graphite,
                    RvColors.obsidian,
                  ],
                ),
              ),
              child: item.previewAssetPath == null
                  ? Center(child: _ShopPreview(item: item, large: true))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        item.previewAssetPath!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: RvColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: RvColors.mutedText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RarityPill(item: item),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatusPill(label: owned ? 'Owned' : unlockLabel),
              const Spacer(),
              FilledButton.icon(
                onPressed: equipped
                    ? null
                    : owned
                    ? onEquip
                    : onBuy,
                icon: Icon(
                  equipped
                      ? Icons.check_circle_rounded
                      : owned
                      ? Icons.checkroom_rounded
                      : Icons.shopping_bag_rounded,
                ),
                label: Text(
                  equipped
                      ? 'Equipped'
                      : owned
                      ? 'Equip'
                      : 'Preview',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopTabs extends StatelessWidget {
  const _ShopTabs({
    required this.selected,
    required this.categories,
    required this.onSelected,
  });

  final _ShopCategory selected;
  final List<_ShopCategory> categories;
  final ValueChanged<_ShopCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          return ChoiceChip(
            selected: selected == category,
            avatar: Icon(category.icon, size: 18),
            label: Text(category.label),
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}

class _CategoryIntro extends StatelessWidget {
  const _CategoryIntro({required this.category});

  final _ShopCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(category.icon, color: RvColors.electricBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.description,
              style: const TextStyle(color: RvColors.mutedText, height: 1.3),
            ),
          ),
          const SizedBox(width: 10),
          const _StatusPill(label: 'No payments yet'),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.item,
    required this.selected,
    required this.owned,
    required this.equipped,
    required this.unlockLabel,
    required this.onTap,
  });

  final _ShopItem item;
  final bool selected;
  final bool owned;
  final bool equipped;
  final String unlockLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? item.color.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.14),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.24),
                    blurRadius: 24,
                    spreadRadius: -12,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(child: _ShopPreview(item: item, large: false)),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RvColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              equipped
                  ? 'Equipped'
                  : owned
                  ? 'Owned'
                  : unlockLabel,
              style: TextStyle(
                color: equipped ? RvColors.emerald : item.color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopPreview extends StatelessWidget {
  const _ShopPreview({required this.item, required this.large});

  final _ShopItem item;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 118.0 : 82.0;
    final assetPath = item.thumbnailAssetPath ?? item.assetPath;
    if (assetPath != null) {
      return SizedBox.square(
        dimension: size,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return CustomPaint(
      size: Size.square(size),
      painter: _ShopPreviewPainter(item),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Icon(item.icon, color: item.foreground, size: large ? 42 : 30),
        ),
      ),
    );
  }
}

class _ShopPreviewPainter extends CustomPainter {
  const _ShopPreviewPainter(this.item);

  final _ShopItem item;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final glow = Paint()
      ..color = item.color.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius * 0.86, glow);

    if (item.category == _ShopCategory.frames) {
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.2
        ..shader = SweepGradient(
          colors: [item.color, item.foreground, item.color],
        ).createShader(Offset.zero & size);
      canvas.drawCircle(center, radius * 0.68, base);
      final inner = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.72);
      canvas.drawCircle(center, radius * 0.52, inner);
    } else if (item.category == _ShopCategory.themes) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.74,
          height: size.height * 0.52,
        ),
        const Radius.circular(8),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [item.color, RvColors.graphite, item.foreground],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.36),
      );
    } else if (item.category == _ShopCategory.bundles) {
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [item.color, RvColors.graphiteLight, item.foreground],
        ).createShader(Offset.zero & size);
      for (var i = 0; i < 3; i++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center + Offset((i - 1) * radius * 0.28, (i - 1) * 5),
            width: radius * 0.82,
            height: radius * 1.05,
          ),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, paint);
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = Colors.white.withValues(alpha: 0.44),
        );
      }
    } else {
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final angle = -1.57 + i * 1.047;
        final point = Offset(
          center.dx + math.cos(angle) * radius * 0.74,
          center.dy + math.sin(angle) * radius * 0.74,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [RvColors.graphiteLight, item.color],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = item.foreground,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShopPreviewPainter oldDelegate) {
    return oldDelegate.item != item;
  }
}

class _RarityPill extends StatelessWidget {
  const _RarityPill({required this.item});

  final _ShopItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: item.color.withValues(alpha: 0.38)),
      ),
      child: Text(
        item.rarity.toUpperCase(),
        style: TextStyle(
          color: item.color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: RvColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: RvColors.text,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _ShopCategory {
  frames(
    'Frames',
    Icons.account_circle_rounded,
    'Avatar frames wrap your profile picture with collectible style.',
  ),
  themes(
    'Themes',
    Icons.garage_rounded,
    'Theme packs change the look of your vault, garage, and profile.',
  ),
  bundles(
    'Bundles',
    Icons.inventory_2_rounded,
    'Bundles group matching frames, themes, badges, and scanner looks.',
  ),
  badges(
    'Badges',
    Icons.workspace_premium_rounded,
    'Profile badges are small collectibles for your public identity.',
  ),
  scanner(
    'Scanner',
    Icons.center_focus_strong_rounded,
    'Scanner skins change the feel of AI lock-on and rarity reveals.',
  );

  const _ShopCategory(this.label, this.icon, this.description);

  final String label;
  final IconData icon;
  final String description;
}

class _ShopItem {
  const _ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.icon,
    required this.color,
    required this.foreground,
    this.assetPath,
    this.previewAssetPath,
    this.thumbnailAssetPath,
  });

  final String id;
  final String name;
  final String description;
  final _ShopCategory category;
  final String rarity;
  final IconData icon;
  final Color color;
  final Color foreground;
  final String? assetPath;
  final String? previewAssetPath;
  final String? thumbnailAssetPath;
}

const _shopItems = [
  _ShopItem(
    id: 'carbon_ring',
    name: 'Carbon Ring',
    description: 'A clean carbon fiber avatar frame with a silver edge.',
    category: _ShopCategory.frames,
    rarity: 'Common',
    icon: Icons.circle_rounded,
    color: RvColors.titanium,
    foreground: Colors.white,
    assetPath: 'assets/cosmetics/frames/carbon_fibre.png',
  ),
  _ShopItem(
    id: 'sleepy_cat',
    name: 'Sleepy Cat',
    description: 'A cozy cat avatar frame for chill garage profiles.',
    category: _ShopCategory.frames,
    rarity: 'Rare',
    icon: Icons.pets_rounded,
    color: Color(0xFFF2A65A),
    foreground: Colors.white,
    assetPath: 'assets/cosmetics/frames/sleepy_cat.png',
  ),
  _ShopItem(
    id: 'boba_tea',
    name: 'Boba Tea',
    description: 'A warm boba frame with wood, pearls, and gold trim.',
    category: _ShopCategory.frames,
    rarity: 'Epic',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFD8A04E),
    foreground: Colors.white,
    assetPath: 'assets/cosmetics/frames/boba_tea.png',
  ),
  _ShopItem(
    id: 'crimson_surge',
    name: 'Crimson Surge',
    description: 'A mythic red energy frame with spark trails.',
    category: _ShopCategory.frames,
    rarity: 'Mythic',
    icon: Icons.local_fire_department_rounded,
    color: RvColors.crimson,
    foreground: Colors.white,
    assetPath: 'assets/cosmetics/frames/crimson_surge.png',
  ),
  _ShopItem(
    id: 'starter_badge',
    name: 'Starter Spotter',
    description: 'Your first clean identity badge.',
    category: _ShopCategory.badges,
    rarity: 'Common',
    icon: Icons.flag_rounded,
    color: RvColors.titanium,
    foreground: Colors.white,
  ),
  _ShopItem(
    id: 'hypercar_hunter',
    name: 'Hypercar Hunter',
    description: 'A speed badge for rare machine chasers.',
    category: _ShopCategory.badges,
    rarity: 'Mythic',
    icon: Icons.speed_rounded,
    color: RvColors.mythic,
    foreground: Colors.white,
  ),
  _ShopItem(
    id: 'trusted_curator',
    name: 'Trusted Curator',
    description: 'A clean capture badge for high-trust spotters.',
    category: _ShopCategory.badges,
    rarity: 'Epic',
    icon: Icons.security_rounded,
    color: RvColors.emerald,
    foreground: Colors.white,
  ),
  _ShopItem(
    id: 'sleepy_cat_lounge',
    name: 'Sleepy Cat Lounge',
    description: 'A cozy moonlit cat lounge for soft profile and vault pages.',
    category: _ShopCategory.themes,
    rarity: 'Epic',
    icon: Icons.nightlight_round,
    color: Color(0xFFF2A65A),
    foreground: Color(0xFF24456A),
    previewAssetPath: 'assets/cosmetics/themes/sleepy_cat_lounge/preview.png',
    thumbnailAssetPath: 'assets/cosmetics/themes/sleepy_cat_lounge/thumb.png',
  ),
  _ShopItem(
    id: 'spilled_boba',
    name: 'Spilled Boba',
    description: 'A clean caramel boba theme with pearls along the edge.',
    category: _ShopCategory.themes,
    rarity: 'Rare',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFD8A04E),
    foreground: Color(0xFF5B321F),
    previewAssetPath: 'assets/cosmetics/themes/spilled_boba/preview.png',
    thumbnailAssetPath: 'assets/cosmetics/themes/spilled_boba/thumb.png',
  ),
  _ShopItem(
    id: 'aqua_flow_theme',
    name: 'Aqua Flow',
    description: 'A glossy blue water theme with ripples and crystal drops.',
    category: _ShopCategory.themes,
    rarity: 'Epic',
    icon: Icons.water_drop_rounded,
    color: RvColors.electricBlue,
    foreground: Color(0xFFBDEFFF),
    previewAssetPath: 'assets/cosmetics/themes/aqua_flow/preview.png',
    thumbnailAssetPath: 'assets/cosmetics/themes/aqua_flow/thumb.png',
  ),
  _ShopItem(
    id: 'crimson_surge_theme',
    name: 'Crimson Surge',
    description: 'A dark red energy theme with glossy ribbons and sparks.',
    category: _ShopCategory.themes,
    rarity: 'Mythic',
    icon: Icons.local_fire_department_rounded,
    color: RvColors.crimson,
    foreground: RvColors.mythic,
    previewAssetPath: 'assets/cosmetics/themes/crimson_surge/preview.png',
    thumbnailAssetPath: 'assets/cosmetics/themes/crimson_surge/thumb.png',
  ),
  _ShopItem(
    id: 'classic_hud',
    name: 'Classic HUD',
    description: 'Default clean scanner interface.',
    category: _ShopCategory.scanner,
    rarity: 'Common',
    icon: Icons.center_focus_strong_rounded,
    color: RvColors.electricBlue,
    foreground: Colors.white,
  ),
  _ShopItem(
    id: 'gold_reveal',
    name: 'Gold Reveal',
    description: 'Legendary reveal glow for scanner moments.',
    category: _ShopCategory.scanner,
    rarity: 'Legendary',
    icon: Icons.auto_awesome_rounded,
    color: RvColors.legendary,
    foreground: Colors.white,
  ),
  _ShopItem(
    id: 'mythic_lock',
    name: 'Mythic Lock',
    description: 'Red-orange scanner lock-on cosmetic.',
    category: _ShopCategory.scanner,
    rarity: 'Mythic',
    icon: Icons.radar_rounded,
    color: RvColors.mythic,
    foreground: Colors.white,
  ),
];
