import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

import '../models/spot_integrity.dart';

class SpotIntegrityService {
  const SpotIntegrityService();

  Future<SpotIntegrity> inspectImage({
    required String imagePath,
    required String captureSource,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final imageHash = sha256.convert(bytes).toString();
    final perceptualHash = await _averageHash(bytes);
    final trustScore = captureSource == 'camera' ? 85 : 55;

    return SpotIntegrity(
      imageHash: imageHash,
      perceptualHash: perceptualHash,
      captureSource: captureSource,
      trustScore: trustScore,
      verificationStatus: captureSource == 'camera'
          ? 'camera-captured'
          : 'gallery-review',
    );
  }

  Future<String> _averageHash(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 8,
      targetHeight: 8,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();

    if (byteData == null) {
      return '';
    }

    final luminance = <int>[];
    final data = byteData.buffer.asUint8List();
    for (var i = 0; i < data.length; i += 4) {
      final r = data[i];
      final g = data[i + 1];
      final b = data[i + 2];
      luminance.add((0.299 * r + 0.587 * g + 0.114 * b).round());
    }

    final average =
        luminance.fold<int>(0, (total, value) => total + value) /
        math.max(1, luminance.length);
    final buffer = StringBuffer();
    for (var i = 0; i < luminance.length; i += 4) {
      var nibble = 0;
      for (var bit = 0; bit < 4; bit++) {
        final index = i + bit;
        if (index < luminance.length && luminance[index] >= average) {
          nibble |= 1 << (3 - bit);
        }
      }
      buffer.write(nibble.toRadixString(16));
    }

    return buffer.toString();
  }
}

int perceptualHashDistance(String a, String b) {
  if (a.length != b.length || a.isEmpty) {
    return 64;
  }

  var distance = 0;
  for (var i = 0; i < a.length; i++) {
    final left = int.tryParse(a[i], radix: 16);
    final right = int.tryParse(b[i], radix: 16);
    if (left == null || right == null) {
      return 64;
    }

    var xor = left ^ right;
    while (xor > 0) {
      distance += xor & 1;
      xor >>= 1;
    }
  }

  return distance;
}
