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
    final metadata = _readExifMetadata(bytes);
    final metadataReview = _reviewMetadata(
      metadata: metadata,
      captureSource: captureSource,
    );
    final baseTrustScore = captureSource == 'camera' ? 85 : 55;
    final trustScore = (baseTrustScore + metadataReview.trustDelta).clamp(
      0,
      100,
    );

    return SpotIntegrity(
      imageHash: imageHash,
      perceptualHash: perceptualHash,
      captureSource: captureSource,
      trustScore: trustScore,
      verificationStatus: metadataReview.verificationStatus,
      capturedAt: metadata.capturedAt,
      hasGpsMetadata: metadata.hasGps,
      metadataStatus: metadataReview.status,
      metadataNotes: metadataReview.notes.join(' '),
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

  _ExifMetadata _readExifMetadata(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) {
      return const _ExifMetadata();
    }

    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xff) {
        break;
      }

      final marker = bytes[offset + 1];
      if (marker == 0xda || marker == 0xd9) {
        break;
      }

      final segmentLength = _readUint16(bytes, offset + 2, false);
      if (segmentLength < 2 || offset + 2 + segmentLength > bytes.length) {
        break;
      }

      final segmentStart = offset + 4;
      final segmentEnd = offset + 2 + segmentLength;
      if (marker == 0xe1 &&
          segmentEnd - segmentStart > 14 &&
          _matchesAscii(bytes, segmentStart, 'Exif\u0000\u0000')) {
        return _readTiffExif(bytes, segmentStart + 6, segmentEnd);
      }

      offset += 2 + segmentLength;
    }

    return const _ExifMetadata();
  }

  _ExifMetadata _readTiffExif(Uint8List bytes, int tiffStart, int segmentEnd) {
    if (tiffStart + 8 > segmentEnd) {
      return const _ExifMetadata();
    }

    final littleEndian =
        bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49;
    final bigEndian = bytes[tiffStart] == 0x4d && bytes[tiffStart + 1] == 0x4d;
    if (!littleEndian && !bigEndian) {
      return const _ExifMetadata();
    }

    final marker = _readUint16(bytes, tiffStart + 2, littleEndian);
    if (marker != 42) {
      return const _ExifMetadata();
    }

    final firstIfdOffset = _readUint32(bytes, tiffStart + 4, littleEndian);
    final rootIfd = tiffStart + firstIfdOffset;
    final root = _readIfd(bytes, rootIfd, tiffStart, segmentEnd, littleEndian);
    final exifIfdOffset = root[0x8769]?.asInt;
    final gpsIfdOffset = root[0x8825]?.asInt;

    DateTime? capturedAt;
    if (exifIfdOffset != null) {
      final exif = _readIfd(
        bytes,
        tiffStart + exifIfdOffset,
        tiffStart,
        segmentEnd,
        littleEndian,
      );
      capturedAt = _parseExifDate(
        exif[0x9003]?.asString ?? exif[0x9004]?.asString,
      );
    }

    capturedAt ??= _parseExifDate(root[0x0132]?.asString);

    var hasGps = false;
    if (gpsIfdOffset != null) {
      final gps = _readIfd(
        bytes,
        tiffStart + gpsIfdOffset,
        tiffStart,
        segmentEnd,
        littleEndian,
      );
      hasGps = gps.containsKey(0x0002) && gps.containsKey(0x0004);
    }

    return _ExifMetadata(capturedAt: capturedAt, hasGps: hasGps);
  }

  Map<int, _ExifValue> _readIfd(
    Uint8List bytes,
    int ifdOffset,
    int tiffStart,
    int segmentEnd,
    bool littleEndian,
  ) {
    if (ifdOffset < tiffStart || ifdOffset + 2 > segmentEnd) {
      return const {};
    }

    final count = _readUint16(bytes, ifdOffset, littleEndian);
    final values = <int, _ExifValue>{};
    var entryOffset = ifdOffset + 2;
    for (var i = 0; i < count; i++) {
      if (entryOffset + 12 > segmentEnd) {
        break;
      }

      final tag = _readUint16(bytes, entryOffset, littleEndian);
      final type = _readUint16(bytes, entryOffset + 2, littleEndian);
      final componentCount = _readUint32(bytes, entryOffset + 4, littleEndian);
      final byteCount = _typeByteCount(type) * componentCount;
      final valueOffset = byteCount <= 4
          ? entryOffset + 8
          : tiffStart + _readUint32(bytes, entryOffset + 8, littleEndian);

      if (valueOffset >= tiffStart && valueOffset + byteCount <= segmentEnd) {
        if (type == 2) {
          values[tag] = _ExifValue(
            stringValue: _readAscii(bytes, valueOffset, byteCount),
          );
        } else if ((type == 3 || type == 4) && componentCount >= 1) {
          final intValue = type == 3
              ? _readUint16(bytes, valueOffset, littleEndian)
              : _readUint32(bytes, valueOffset, littleEndian);
          values[tag] = _ExifValue(intValue: intValue);
        } else {
          values[tag] = const _ExifValue(intValue: 1);
        }
      }

      entryOffset += 12;
    }

    return values;
  }

  _MetadataReview _reviewMetadata({
    required _ExifMetadata metadata,
    required String captureSource,
  }) {
    final notes = <String>[];
    var trustDelta = 0;
    var status = 'metadata-ok';
    var verificationStatus = captureSource == 'camera'
        ? 'camera-captured'
        : 'gallery-review';

    final capturedAt = metadata.capturedAt;
    if (capturedAt == null) {
      notes.add('No EXIF capture time found.');
      if (captureSource == 'gallery') {
        trustDelta -= 18;
        status = 'metadata-missing';
        verificationStatus = 'metadata-review';
      } else {
        trustDelta -= 4;
      }
    } else {
      final age = DateTime.now().toUtc().difference(capturedAt.toUtc());
      if (age < const Duration(minutes: -10)) {
        notes.add('EXIF capture time is in the future.');
        trustDelta -= 25;
        status = 'metadata-suspicious';
        verificationStatus = 'metadata-review';
      } else if (age > const Duration(days: 30)) {
        notes.add('EXIF capture time is older than 30 days.');
        trustDelta -= captureSource == 'gallery' ? 18 : 8;
        status = 'metadata-stale';
        verificationStatus = 'metadata-review';
      } else if (age <= const Duration(days: 7)) {
        notes.add('Recent EXIF capture time found.');
        trustDelta += captureSource == 'gallery' ? 8 : 3;
      }
    }

    if (!metadata.hasGps) {
      notes.add('No embedded GPS metadata found.');
      if (captureSource == 'gallery') {
        trustDelta -= 6;
      }
    } else {
      notes.add('Embedded GPS metadata found.');
      if (captureSource == 'gallery') {
        trustDelta += 4;
      }
    }

    return _MetadataReview(
      status: status,
      verificationStatus: verificationStatus,
      trustDelta: trustDelta,
      notes: notes,
    );
  }

  int _readUint16(Uint8List bytes, int offset, bool littleEndian) {
    final byteData = ByteData.sublistView(bytes);
    return byteData.getUint16(
      offset,
      littleEndian ? Endian.little : Endian.big,
    );
  }

  int _readUint32(Uint8List bytes, int offset, bool littleEndian) {
    final byteData = ByteData.sublistView(bytes);
    return byteData.getUint32(
      offset,
      littleEndian ? Endian.little : Endian.big,
    );
  }

  int _typeByteCount(int type) {
    return switch (type) {
      1 || 2 || 7 => 1,
      3 => 2,
      4 || 9 => 4,
      5 || 10 => 8,
      _ => 1,
    };
  }

  bool _matchesAscii(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) {
      return false;
    }
    for (var i = 0; i < value.length; i++) {
      if (bytes[offset + i] != value.codeUnitAt(i)) {
        return false;
      }
    }
    return true;
  }

  String _readAscii(Uint8List bytes, int offset, int length) {
    final end = math.min(bytes.length, offset + length);
    final codes = <int>[];
    for (var i = offset; i < end; i++) {
      final code = bytes[i];
      if (code == 0) {
        break;
      }
      codes.add(code);
    }
    return String.fromCharCodes(codes).trim();
  }

  DateTime? _parseExifDate(String? value) {
    if (value == null || value.length < 19) {
      return null;
    }
    final match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final parts = [for (var i = 1; i <= 6; i++) int.tryParse(match.group(i)!)];
    if (parts.any((part) => part == null)) {
      return null;
    }
    return DateTime(
      parts[0]!,
      parts[1]!,
      parts[2]!,
      parts[3]!,
      parts[4]!,
      parts[5]!,
    );
  }
}

class _ExifMetadata {
  const _ExifMetadata({this.capturedAt, this.hasGps = false});

  final DateTime? capturedAt;
  final bool hasGps;
}

class _ExifValue {
  const _ExifValue({this.stringValue, this.intValue});

  final String? stringValue;
  final int? intValue;

  String? get asString => stringValue;
  int? get asInt => intValue;
}

class _MetadataReview {
  const _MetadataReview({
    required this.status,
    required this.verificationStatus,
    required this.trustDelta,
    required this.notes,
  });

  final String status;
  final String verificationStatus;
  final int trustDelta;
  final List<String> notes;
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
