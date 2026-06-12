import 'package:flutter/material.dart';

class RvColors {
  const RvColors._();

  static const obsidian = Color(0xFF080B10);
  static const carbon = Color(0xFF10151E);
  static const graphite = Color(0xFF18202D);
  static const graphiteLight = Color(0xFF222B39);
  static const titanium = Color(0xFFC7CED8);
  static const text = Color(0xFFE8ECF2);
  static const mutedText = Color(0xFFA8B0BC);
  static const border = Color(0x38FFFFFF);
  static const glass = Color(0x18FFFFFF);
  static const glassStrong = Color(0x28FFFFFF);

  static const electricBlue = Color(0xFF2F80FF);
  static const crimson = Color(0xFFFF304F);
  static const hyperOrange = Color(0xFFFF7A1A);
  static const emerald = Color(0xFF22C55E);
  static const legendary = Color(0xFFFACC15);
  static const mythic = Color(0xFFFF4D00);

  static Color rarity(String rarity) {
    return switch (rarity) {
      'Common' => const Color(0xFF9CA3AF),
      'Uncommon' => const Color(0xFF38BDF8),
      'Rare' => const Color(0xFF8B5CF6),
      'Ultra Rare' => const Color(0xFFEC4899),
      'Legendary' => legendary,
      'Mythic' => mythic,
      _ => electricBlue,
    };
  }
}
