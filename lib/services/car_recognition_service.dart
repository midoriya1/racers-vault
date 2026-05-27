import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recognition_result.dart';

abstract class CarRecognitionService {
  Future<List<RecognitionResult>> identifyCar({
    required String imagePath,
    required String country,
    required String city,
  });
}

class HttpCarRecognitionService implements CarRecognitionService {
  const HttpCarRecognitionService(this.endpoint, {this.accessTokenProvider});

  final Uri endpoint;
  final String? Function()? accessTokenProvider;

  @override
  Future<List<RecognitionResult>> identifyCar({
    required String imagePath,
    required String country,
    required String city,
  }) async {
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['country'] = country
      ..fields['city'] = city
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));
    final accessToken = accessTokenProvider?.call();
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $accessToken';
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Recognizer failed: ${_recognizerErrorMessage(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>? ?? [];
    final blurStatus = decoded['blurStatus'] as String? ?? 'not_needed';
    final processedImageBase64 =
        decoded['processedImageBase64'] as String? ?? '';
    final processedMimeType = decoded['processedMimeType'] as String? ?? '';

    return candidates.map((candidate) {
      final data = candidate as Map<String, dynamic>;
      return RecognitionResult(
        carName: data['carName'] as String? ?? 'Unknown car',
        category: data['category'] as String? ?? 'Cars',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
        suggestedRarity: data['suggestedRarity'] as String? ?? 'Rare',
        reason: data['reason'] as String? ?? 'AI recognition result',
        make: data['make'] as String? ?? '',
        model: data['model'] as String? ?? '',
        generation: data['generation'] as String? ?? '',
        yearRange: data['yearRange'] as String? ?? '',
        bodyType: data['bodyType'] as String? ?? '',
        licensePlateVisible: data['licensePlateVisible'] as bool? ?? false,
        faceVisible: data['faceVisible'] as bool? ?? false,
        syntheticImageRisk:
            (data['syntheticImageRisk'] as num?)?.toDouble() ?? 0,
        manipulationRisk: (data['manipulationRisk'] as num?)?.toDouble() ?? 0,
        securityNote: data['securityNote'] as String? ?? '',
        blurStatus: blurStatus,
        processedImageBase64: processedImageBase64,
        processedMimeType: processedMimeType,
      );
    }).toList();
  }

  String _recognizerErrorMessage(String body) {
    if (body.trim().isEmpty) {
      return 'The AI recognizer did not return details.';
    }

    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return _detailMessage(detail);
      }

      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error;
      }
    } catch (_) {
      return body;
    }

    return body;
  }

  String _detailMessage(String detail) {
    try {
      final decoded = jsonDecode(detail) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      if (detail.contains('high demand')) {
        return 'The AI model is busy right now. Try again in a moment.';
      }
    }

    return detail;
  }
}

class MockCarRecognitionService implements CarRecognitionService {
  const MockCarRecognitionService();

  @override
  Future<List<RecognitionResult>> identifyCar({
    required String imagePath,
    required String country,
    required String city,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final normalizedCountry = country.toLowerCase();
    final isIndia = normalizedCountry.contains('india');

    return [
      RecognitionResult(
        carName: 'Porsche 911 GT3 RS',
        category: 'Supercars',
        confidence: 0.87,
        suggestedRarity: isIndia ? 'Ultra Rare' : 'Rare',
        reason: isIndia
            ? 'Track-focused 911s are uncommon in Indian city uploads.'
            : 'Strong match for a winged Porsche performance model.',
        make: 'Porsche',
        model: '911 GT3 RS',
        generation: '992',
        yearRange: '2022-present',
        bodyType: 'Coupe',
        licensePlateVisible: true,
        faceVisible: false,
        syntheticImageRisk: 0.08,
        manipulationRisk: 0.05,
        securityNote: 'Plate may be visible. Queue for blur before public use.',
        blurStatus: 'processed',
      ),
      RecognitionResult(
        carName: 'Nissan GT-R R35',
        category: 'JDM',
        confidence: 0.76,
        suggestedRarity: isIndia ? 'Rare' : 'Uncommon',
        reason: 'Shape resembles a modern Japanese performance coupe.',
        make: 'Nissan',
        model: 'GT-R',
        generation: 'R35',
        yearRange: '2007-2025',
        bodyType: 'Coupe',
        licensePlateVisible: false,
        faceVisible: false,
        syntheticImageRisk: 0.12,
        manipulationRisk: 0.08,
        securityNote: 'No obvious privacy risk detected in mock scan.',
        blurStatus: 'not_needed',
      ),
      RecognitionResult(
        carName: 'BMW M4 Competition',
        category: 'German',
        confidence: 0.62,
        suggestedRarity: isIndia ? 'Rare' : 'Uncommon',
        reason: 'Front profile could match a German performance coupe.',
        make: 'BMW',
        model: 'M4 Competition',
        generation: 'G82',
        yearRange: '2021-present',
        bodyType: 'Coupe',
        licensePlateVisible: true,
        faceVisible: true,
        syntheticImageRisk: 0.1,
        manipulationRisk: 0.12,
        securityNote:
            'Plate and possible bystander face detected. Needs blur pass.',
        blurStatus: 'processed',
      ),
    ];
  }
}
