import 'dart:io';

import 'package:flutter/material.dart';

import '../design/rv_colors.dart';
import '../models/car_spot.dart';
import 'rv_glass.dart';

class SpotCard extends StatelessWidget {
  const SpotCard({super.key, required this.spot, this.onTap});

  final CarSpot spot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rarityColor = RvColors.rarity(spot.rarity);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: RvGlass(
        padding: EdgeInsets.zero,
        radius: 24,
        borderColor: rarityColor.withValues(alpha: 0.36),
        glowColor: rarityColor,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.42,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SpotMedia(spot: spot),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.66),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _SpotterPill(spotter: spot.spotter),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: RarityChip(label: spot.rarity),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            spot.carName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.02,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _PointsPill(points: spot.points),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: RvColors.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${spot.city}, ${spot.country} - ${spot.category}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: RvColors.titanium),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _TrustRow(spot: spot),
                  const SizedBox(height: 10),
                  Text(
                    spot.caption,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: RvColors.text,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: RvColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.favorite_border_rounded),
                    label: Text('${spot.likes}'),
                  ),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: Text('${spot.comments}'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.bookmark_border_rounded),
                    label: const Text('Vault'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    final isCamera = spot.captureSource == 'camera';
    final status = _statusLabel(spot.verificationStatus);
    return Row(
      children: [
        Icon(
          isCamera ? Icons.verified_user_rounded : Icons.manage_search_rounded,
          color: isCamera ? RvColors.emerald : RvColors.hyperOrange,
          size: 18,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${spot.trustScore}% trust - $status',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: RvColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'camera-captured' => 'camera captured',
      'gallery-review' => 'gallery upload',
      'privacy-redacted' => 'privacy blurred',
      'privacy-review' => 'privacy review',
      'location-review' => 'location review',
      'authenticity-review' => 'authenticity review',
      _ => 'unverified',
    };
  }
}

class _SpotterPill extends StatelessWidget {
  const _SpotterPill({required this.spotter});

  final String spotter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        '@$spotter',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: RvColors.crimson.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: RvColors.crimson.withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 3),
          Text(
            '$points',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class SpotMedia extends StatelessWidget {
  const SpotMedia({super.key, required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    final localPath = spot.localMediaPath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    }

    final mediaUrl = spot.mediaUrl;
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      return Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              CarPoster(spot: spot),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => CarPoster(spot: spot),
      );
    }

    return CarPoster(spot: spot);
  }
}

class CarPoster extends StatelessWidget {
  const CarPoster({super.key, required this.spot});

  final CarSpot spot;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CarPosterPainter(
        colorA: spot.colorA,
        colorB: spot.colorB,
        accent: spot.accent,
      ),
      child: Stack(children: [const SizedBox.shrink()]),
    );
  }
}

class CarPosterPainter extends CustomPainter {
  const CarPosterPainter({
    required this.colorA,
    required this.colorB,
    required this.accent,
  });

  final Color colorA;
  final Color colorB;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colorA, colorB],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final road = Paint()..color = Colors.black.withValues(alpha: 0.24);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32),
      road,
    );

    final glow = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.72),
        width: size.width * 0.72,
        height: size.height * 0.24,
      ),
      glow,
    );

    final carPaint = Paint()..color = Colors.white.withValues(alpha: 0.93);
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.22);
    final linePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final baseTop = size.height * 0.57;
    final car = Path()
      ..moveTo(size.width * 0.15, baseTop)
      ..quadraticBezierTo(
        size.width * 0.23,
        size.height * 0.47,
        size.width * 0.34,
        size.height * 0.46,
      )
      ..lineTo(size.width * 0.44, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.28,
        size.width * 0.68,
        size.height * 0.39,
      )
      ..lineTo(size.width * 0.78, size.height * 0.49)
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.51,
        size.width * 0.91,
        baseTop,
      )
      ..quadraticBezierTo(
        size.width * 0.87,
        size.height * 0.66,
        size.width * 0.72,
        size.height * 0.66,
      )
      ..lineTo(size.width * 0.25, size.height * 0.66)
      ..quadraticBezierTo(
        size.width * 0.17,
        size.height * 0.65,
        size.width * 0.15,
        baseTop,
      )
      ..close();

    canvas.drawShadow(car, Colors.black.withValues(alpha: 0.55), 8, true);
    canvas.drawPath(car, carPaint);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.28, size.height * 0.54)
        ..lineTo(size.width * 0.76, size.height * 0.54),
      linePaint,
    );

    final cabin = Path()
      ..moveTo(size.width * 0.41, size.height * 0.45)
      ..lineTo(size.width * 0.48, size.height * 0.36)
      ..quadraticBezierTo(
        size.width * 0.57,
        size.height * 0.34,
        size.width * 0.66,
        size.height * 0.43,
      )
      ..lineTo(size.width * 0.41, size.height * 0.45)
      ..close();
    canvas.drawPath(cabin, shadowPaint);

    for (final wheelX in [size.width * 0.31, size.width * 0.72]) {
      canvas.drawCircle(
        Offset(wheelX, size.height * 0.66),
        size.width * 0.07,
        shadowPaint,
      );
      canvas.drawCircle(
        Offset(wheelX, size.height * 0.66),
        size.width * 0.035,
        Paint()..color = accent,
      );
    }

    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..strokeWidth = 3;
    for (double x = -40; x < size.width; x += 82) {
      canvas.drawLine(
        Offset(x, size.height * 0.84),
        Offset(x + 34, size.height * 0.84),
        lanePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CarPosterPainter oldDelegate) {
    return oldDelegate.colorA != colorA ||
        oldDelegate.colorB != colorB ||
        oldDelegate.accent != accent;
  }
}

class RarityChip extends StatelessWidget {
  const RarityChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = RvColors.rarity(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 14),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
