import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/rarity_data.dart';
import '../design/rv_colors.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../models/spot_integrity.dart';
import '../models/recognition_result.dart';
import '../services/car_recognition_service.dart';
import '../services/spot_integrity_service.dart';
import '../services/spot_location_service.dart';
import '../widgets/rv_glass.dart';
import '../widgets/spot_card.dart';

class AddSpotPage extends StatefulWidget {
  const AddSpotPage({
    super.key,
    required this.currentUser,
    required this.carRecognitionService,
  });

  final AppUser currentUser;
  final CarRecognitionService carRecognitionService;

  @override
  State<AddSpotPage> createState() => _AddSpotPageState();
}

class _AddSpotPageState extends State<AddSpotPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _integrityService = const SpotIntegrityService();
  final _locationService = const SpotLocationService();
  String _rarity = 'Rare';
  String _category = 'Cars';
  String _carName = '';
  RecognitionResult? _selectedRecognition;
  late String _city;
  late String _country;
  String _locationIntegrity = 'profile-fallback';
  XFile? _selectedImage;
  String? _privacySafeImagePath;
  SpotIntegrity? _spotIntegrity;
  bool _isRecognizing = false;
  bool _isInspecting = false;
  bool _isLocating = false;
  String? _recognitionError;
  List<RecognitionResult> _recognitionResults = [];
  late final AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat();
    _city = widget.currentUser.city;
    _country = widget.currentUser.country;
    _detectLocation();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo before posting.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_carName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Let AI identify the spot first.')),
      );
      return;
    }

    final points = rarityPoints[_rarity]!;
    final colors = spotColors[_rarity]!;
    Navigator.of(context).pop(
      CarSpot(
        id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
        userId: widget.currentUser.uid,
        spotter: widget.currentUser.username,
        city: _city,
        country: _country,
        category: _category,
        carName: _carName,
        rarity: _rarity,
        points: points,
        caption: _captionController.text.trim().isEmpty
            ? 'Fresh spot added to the vault.'
            : _captionController.text.trim(),
        colorA: colors.$1,
        colorB: colors.$2,
        accent: colors.$3,
        likes: 0,
        comments: 0,
        createdAt: DateTime.now(),
        localMediaPath: _privacySafeImagePath ?? _selectedImage?.path,
        imageHash: _spotIntegrity?.imageHash,
        perceptualHash: _spotIntegrity?.perceptualHash,
        captureSource: _spotIntegrity?.captureSource ?? 'unknown',
        trustScore: _computedTrustScore,
        verificationStatus: _computedVerificationStatus,
        aiConfidence: _selectedRecognition?.confidence ?? 0,
        recognitionNote: _recognitionNote,
        vehicleMake: _selectedRecognition?.make ?? '',
        vehicleModel: _selectedRecognition?.model ?? '',
        vehicleGeneration: _selectedRecognition?.generation ?? '',
        yearRange: _selectedRecognition?.yearRange ?? '',
        bodyType: _selectedRecognition?.bodyType ?? '',
        privacyPlateDetected:
            _selectedRecognition?.licensePlateVisible ?? false,
        privacyFaceDetected: _selectedRecognition?.faceVisible ?? false,
        syntheticImageRisk: _selectedRecognition?.syntheticImageRisk ?? 0,
        manipulationRisk: _selectedRecognition?.manipulationRisk ?? 0,
        locationIntegrity: _locationIntegrity,
        securityNotes: _securityNotes,
        blurStatus: _selectedRecognition?.blurStatus ?? 'not_needed',
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _selectedImage = image;
      _privacySafeImagePath = null;
      _spotIntegrity = null;
      _recognitionResults = [];
      _selectedRecognition = null;
      _recognitionError = null;
      _carName = '';
      _category = 'Cars';
      _rarity = 'Rare';
    });

    await _inspectImage(
      imagePath: image.path,
      captureSource: source == ImageSource.camera ? 'camera' : 'gallery',
    );
    await _identifyCar();
  }

  Future<void> _inspectImage({
    required String imagePath,
    required String captureSource,
  }) async {
    setState(() {
      _isInspecting = true;
    });

    try {
      final integrity = await _integrityService.inspectImage(
        imagePath: imagePath,
        captureSource: captureSource,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _spotIntegrity = integrity;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInspecting = false;
        });
      }
    }
  }

  Future<void> _identifyCar() async {
    final image = _selectedImage;
    if (image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a photo first.')));
      return;
    }

    setState(() {
      _isRecognizing = true;
      _recognitionError = null;
    });

    try {
      final results = await widget.carRecognitionService.identifyCar(
        imagePath: image.path,
        country: _country,
        city: _city,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recognitionResults = results;
        _isRecognizing = false;
        _recognitionError = results.isEmpty
            ? 'AI could not confidently find a vehicle in this image.'
            : null;
      });

      if (results.isNotEmpty) {
        await _applyRecognition(results.first);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecognizing = false;
        _recognitionError = _friendlyRecognitionError(error);
      });
    }
  }

  String _friendlyRecognitionError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('high demand') || text.contains('busy')) {
      return 'AI is under high demand right now. Wait a moment and retry.';
    }
    if (text.contains('Connection refused') ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'Could not reach the recognizer. Check that the backend is running and adb reverse is active.';
    }
    return text.replaceFirst('Recognizer failed: ', '');
  }

  Future<void> _applyRecognition(RecognitionResult result) async {
    final privacySafeImagePath = await _writePrivacySafeImage(result);
    if (!mounted) {
      return;
    }

    setState(() {
      _carName = result.carName;
      _selectedRecognition = result;
      if (privacySafeImagePath != null) {
        _privacySafeImagePath = privacySafeImagePath;
      }
      _category = spotCategories.contains(result.category)
          ? result.category
          : 'Cars';
      if (rarityPoints.containsKey(result.suggestedRarity)) {
        _rarity = result.suggestedRarity;
      }
    });

    await _showRarityReveal(result);
  }

  Future<void> _showRarityReveal(RecognitionResult result) async {
    if (!mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    HapticFeedback.mediumImpact();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Rarity reveal',
      barrierColor: Colors.black.withValues(alpha: 0.74),
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _RarityRevealDialog(
          result: result,
          points:
              rarityPoints[result.suggestedRarity] ?? rarityPoints[_rarity]!,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<String?> _writePrivacySafeImage(RecognitionResult result) async {
    if (result.processedImageBase64.isEmpty ||
        result.blurStatus != 'processed') {
      return null;
    }

    try {
      final bytes = base64Decode(result.processedImageBase64);
      final directory = Directory.systemTemp.createTempSync('racers-vault-');
      final file = File(
        '${directory.path}${Platform.pathSeparator}privacy-safe-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final location = await _locationService.currentLocation();
      if (!mounted) {
        return;
      }

      if (location != null) {
        setState(() {
          _city = location.city;
          _country = location.country;
          _locationIntegrity = location.integrityStatus;
        });
      }
    } catch (_) {
      // Keep the profile location as a fallback if GPS or geocoding is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = CarSpot(
      id: 'preview',
      userId: widget.currentUser.uid,
      spotter: widget.currentUser.username,
      city: _city,
      country: _country,
      category: _category,
      carName: _carName.isEmpty ? 'AI will identify this spot' : _carName,
      rarity: _rarity,
      points: rarityPoints[_rarity]!,
      caption: 'Preview',
      colorA: spotColors[_rarity]!.$1,
      colorB: spotColors[_rarity]!.$2,
      accent: spotColors[_rarity]!.$3,
      likes: 0,
      comments: 0,
      createdAt: DateTime.now(),
      localMediaPath: _selectedImage?.path,
      imageHash: _spotIntegrity?.imageHash,
      perceptualHash: _spotIntegrity?.perceptualHash,
      captureSource: _spotIntegrity?.captureSource ?? 'unknown',
      trustScore: _computedTrustScore,
      verificationStatus: _computedVerificationStatus,
      aiConfidence: _selectedRecognition?.confidence ?? 0,
      recognitionNote: _recognitionNote,
      vehicleMake: _selectedRecognition?.make ?? '',
      vehicleModel: _selectedRecognition?.model ?? '',
      vehicleGeneration: _selectedRecognition?.generation ?? '',
      yearRange: _selectedRecognition?.yearRange ?? '',
      bodyType: _selectedRecognition?.bodyType ?? '',
      privacyPlateDetected: _selectedRecognition?.licensePlateVisible ?? false,
      privacyFaceDetected: _selectedRecognition?.faceVisible ?? false,
      syntheticImageRisk: _selectedRecognition?.syntheticImageRisk ?? 0,
      manipulationRisk: _selectedRecognition?.manipulationRisk ?? 0,
      locationIntegrity: _locationIntegrity,
      securityNotes: _securityNotes,
      blurStatus: _selectedRecognition?.blurStatus ?? 'not_needed',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Scanner'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _isRecognizing ? 'SCAN LIVE' : 'VAULT READY',
                style: const TextStyle(
                  color: RvColors.electricBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
          children: [
            AspectRatio(
              aspectRatio: 0.92,
              child: _ScannerViewport(
                spot: preview,
                imagePath: _privacySafeImagePath ?? _selectedImage?.path,
                isScanning: _isRecognizing || _isInspecting,
                confidence: _selectedRecognition?.confidence ?? 0,
                statusLabel: _scannerStatusLabel,
                scannerAnimation: _scannerController,
              ),
            ),
            const SizedBox(height: 10),
            _LocationPill(
              city: _city,
              country: _country,
              isLocating: _isLocating,
              locationIntegrity: _locationIntegrity,
              onRefresh: _detectLocation,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Live camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Import'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AiResultPanel(
              carName: _carName,
              category: _category,
              rarity: _rarity,
              points: rarityPoints[_rarity]!,
              isRecognizing: _isRecognizing,
              isInspecting: _isInspecting,
              hasImage: _selectedImage != null,
              integrity: _spotIntegrity,
              onRetry: _selectedImage == null || _isRecognizing
                  ? null
                  : _identifyCar,
            ),
            const SizedBox(height: 12),
            _SafetyPanel(
              recognition: _selectedRecognition,
              locationIntegrity: _locationIntegrity,
              trustScore: _computedTrustScore,
              verificationStatus: _computedVerificationStatus,
            ),
            if (_recognitionError != null) ...[
              const SizedBox(height: 12),
              _RecognitionErrorPanel(
                message: _recognitionError!,
                onRetry: _selectedImage == null || _isRecognizing
                    ? null
                    : _identifyCar,
              ),
            ],
            if (_recognitionResults.length > 1) ...[
              const SizedBox(height: 12),
              _RecognitionResults(
                results: _recognitionResults,
                onSelected: (result) async {
                  await _applyRecognition(result);
                },
              ),
            ],
            const SizedBox(height: 12),
            _RarityScorePanel(
              rarity: _rarity,
              points: rarityPoints[_rarity]!,
              city: _city,
              country: _country,
            ),
            const SizedBox(height: 14),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      labelText: 'Vault note',
                      hintText: 'Where did the spot happen?',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isRecognizing || _isInspecting
                          ? null
                          : _submit,
                      icon: const Icon(Icons.bolt_rounded),
                      label: Text('Claim ${rarityPoints[_rarity]} XP'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _computedTrustScore {
    var score = _spotIntegrity?.trustScore ?? 50;
    final recognition = _selectedRecognition;
    if (_locationIntegrity == 'mock-location-review') {
      score -= 35;
    } else if (_locationIntegrity == 'low-accuracy-review') {
      score -= 12;
    }
    if (recognition != null) {
      if (recognition.syntheticImageRisk >= 0.65) {
        score -= 35;
      }
      if (recognition.manipulationRisk >= 0.65) {
        score -= 25;
      }
      if (recognition.licensePlateVisible || recognition.faceVisible) {
        score -= 5;
      }
    }
    return score.clamp(0, 100);
  }

  String get _computedVerificationStatus {
    final recognition = _selectedRecognition;
    if (_locationIntegrity == 'mock-location-review') {
      return 'location-review';
    }
    if ((recognition?.syntheticImageRisk ?? 0) >= 0.65 ||
        (recognition?.manipulationRisk ?? 0) >= 0.65) {
      return 'authenticity-review';
    }
    if ((recognition?.licensePlateVisible ?? false) ||
        (recognition?.faceVisible ?? false)) {
      if (recognition?.blurStatus == 'processed') {
        return 'privacy-redacted';
      }
      return 'privacy-review';
    }
    return _spotIntegrity?.verificationStatus ?? 'unverified';
  }

  String get _recognitionNote {
    final recognition = _selectedRecognition;
    if (recognition == null) {
      return '';
    }
    final notes = [recognition.reason];
    if (recognition.securityNote.trim().isNotEmpty) {
      notes.add(recognition.securityNote.trim());
    }
    return notes.join(' ');
  }

  String get _securityNotes {
    final recognition = _selectedRecognition;
    final notes = <String>[];
    if (_locationIntegrity == 'mock-location-review') {
      notes.add('Possible mock location detected.');
    } else if (_locationIntegrity == 'low-accuracy-review') {
      notes.add('Location accuracy was low.');
    }
    if (recognition?.licensePlateVisible ?? false) {
      notes.add('License plate may be visible.');
    }
    if (recognition?.faceVisible ?? false) {
      notes.add('Bystander face may be visible.');
    }
    if ((recognition?.syntheticImageRisk ?? 0) >= 0.65) {
      notes.add('High AI-generated image risk.');
    }
    if ((recognition?.manipulationRisk ?? 0) >= 0.65) {
      notes.add('High editing/manipulation risk.');
    }
    if (recognition?.blurStatus == 'processed') {
      notes.add('Public image was automatically privacy blurred.');
    }
    return notes.join(' ');
  }

  String get _scannerStatusLabel {
    if (_isInspecting) {
      return 'AUTHENTICITY CHECK';
    }
    if (_isRecognizing) {
      return 'AI LOCKING';
    }
    if (_carName.isNotEmpty) {
      return 'RARITY REVEALED';
    }
    return 'AWAITING TARGET';
  }
}

class _ScannerViewport extends StatelessWidget {
  const _ScannerViewport({
    required this.spot,
    required this.imagePath,
    required this.isScanning,
    required this.confidence,
    required this.statusLabel,
    required this.scannerAnimation,
  });

  final CarSpot spot;
  final String? imagePath;
  final bool isScanning;
  final double confidence;
  final String statusLabel;
  final Animation<double> scannerAnimation;

  @override
  Widget build(BuildContext context) {
    final rarityColor = RvColors.rarity(spot.rarity);
    return AnimatedBuilder(
      animation: scannerAnimation,
      builder: (context, _) {
        final phase = scannerAnimation.value;
        final pulse = 0.5 + (0.5 - (phase - 0.5).abs());
        final hudColor = isScanning ? RvColors.electricBlue : rarityColor;
        final hasImage = imagePath != null && imagePath!.isNotEmpty;
        final hasResult = !spot.carName.startsWith('AI ');

        return RvGlass(
          padding: EdgeInsets.zero,
          radius: 30,
          clipBehavior: Clip.antiAlias,
          borderColor: hudColor.withValues(alpha: 0.22 + pulse * 0.34),
          glowColor: hudColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!hasImage)
                _ScannerEmptyPreview(color: hudColor, progress: phase)
              else
                AnimatedScale(
                  scale: isScanning ? 1.035 : 1,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  child: Image.file(
                    File(imagePath!),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              _ScannerLightingOverlay(
                color: hudColor,
                progress: phase,
                isScanning: isScanning,
              ),
              CustomPaint(
                painter: _ScannerHudPainter(
                  color: hudColor,
                  isScanning: isScanning,
                  progress: phase,
                  pulse: pulse,
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                top: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: _HudPill(
                        icon: isScanning
                            ? Icons.radar_rounded
                            : Icons.center_focus_strong_rounded,
                        label: statusLabel,
                        color: hudColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HudPill(
                      icon: Icons.memory_rounded,
                      label: confidence <= 0
                          ? 'AI --'
                          : 'AI ${(confidence * 100).round()}%',
                      color: RvColors.electricBlue,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                top: 62,
                child: _ScanProgressStrip(
                  isScanning: isScanning,
                  hasResult: hasResult,
                  color: hudColor,
                  progress: isScanning
                      ? phase
                      : hasResult
                      ? 1
                      : 0,
                ),
              ),
              Center(
                child: _FocusReticle(
                  color: hudColor,
                  progress: phase,
                  isScanning: isScanning,
                  hasResult: hasResult,
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: _ScannerResultTray(
                  spot: spot,
                  confidence: confidence,
                  color: hudColor,
                  hasResult: hasResult,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerEmptyPreview extends StatelessWidget {
  const _ScannerEmptyPreview({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(
            0.1 + math.sin(progress * math.pi * 2) * 0.08,
            -0.35,
          ),
          radius: 1.08,
          colors: [
            color.withValues(alpha: 0.22),
            RvColors.graphite,
            RvColors.obsidian,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerEmptyPainter(color: color, progress: progress),
            ),
          ),
          Center(
            child: Container(
              width: 116,
              height: 116,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.34)),
                color: Colors.black.withValues(alpha: 0.24),
              ),
              child: Icon(Icons.add_a_photo_rounded, color: color, size: 42),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 112,
            child: Text(
              'Add a street photo to begin AI recognition',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RvColors.text,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerLightingOverlay extends StatelessWidget {
  const _ScannerLightingOverlay({
    required this.color,
    required this.progress,
    required this.isScanning,
  });

  final Color color;
  final double progress;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final sweepX = -1.2 + progress * 2.4;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.22),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.86),
              ],
            ),
          ),
        ),
        if (isScanning)
          Transform.translate(
            offset: Offset(sweepX * 90, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    color.withValues(alpha: 0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScanProgressStrip extends StatelessWidget {
  const _ScanProgressStrip({
    required this.isScanning,
    required this.hasResult,
    required this.color,
    required this.progress,
  });

  final bool isScanning;
  final bool hasResult;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: 0.34)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.06, 1).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.28),
                      color,
                      hasResult ? RvColors.legendary : RvColors.electricBlue,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusReticle extends StatelessWidget {
  const _FocusReticle({
    required this.color,
    required this.progress,
    required this.isScanning,
    required this.hasResult,
  });

  final Color color;
  final double progress;
  final bool isScanning;
  final bool hasResult;

  @override
  Widget build(BuildContext context) {
    final size = hasResult
        ? 188.0
        : 148.0 + math.sin(progress * math.pi * 2) * 10;
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: isScanning ? 0.42 : 0.26),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isScanning ? 0.18 : 0.08),
              blurRadius: 28,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasResult ? RvColors.legendary : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerResultTray extends StatelessWidget {
  const _ScannerResultTray({
    required this.spot,
    required this.confidence,
    required this.color,
    required this.hasResult,
  });

  final CarSpot spot;
  final double confidence;
  final Color color;
  final bool hasResult;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: hasResult ? 0.64 : 0.48),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spot.carName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${spot.category} - ${spot.city}, ${spot.country}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RvColors.titanium,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _AiConfidenceRail(confidence: confidence, color: color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.94, end: hasResult ? 1.04 : 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: RarityChip(label: spot.rarity),
          ),
        ],
      ),
    );
  }
}

class _AiConfidenceRail extends StatelessWidget {
  const _AiConfidenceRail({required this.confidence, required this.color});

  final double confidence;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: confidence.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.white.withValues(alpha: 0.14)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value <= 0 ? 0.08 : value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              RvColors.legendary.withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerEmptyPainter extends CustomPainter {
  const _ScannerEmptyPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = -size.width; x < size.width * 2; x += 44) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.5, size.height),
        gridPaint,
      );
    }
    for (double y = 24; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 30), gridPaint);
    }

    final orbPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: 0.16);
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final radius = 72.0 + i * 42 + math.sin(progress * math.pi * 2) * 4;
      canvas.drawCircle(center, radius, orbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerEmptyPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

class _ScannerHudPainter extends CustomPainter {
  const _ScannerHudPainter({
    required this.color,
    required this.isScanning,
    required this.progress,
    required this.pulse,
  });

  final Color color;
  final bool isScanning;
  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.58 + pulse * 0.28)
      ..strokeWidth = 1.8 + pulse * 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const inset = 18.0;
    const corner = 42.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(0, corner),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, corner),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -corner),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -corner),
      paint,
    );

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), gridPaint);
    }
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 20), Offset(x, size.height - 20), gridPaint);
    }

    if (isScanning) {
      final scanPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.58),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 34));
      final y = -34 + (size.height + 68) * progress;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 34), scanPaint);

      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.72)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(24, y + 17),
        Offset(size.width - 24, y + 17),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerHudPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isScanning != isScanning ||
        oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse;
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _RarityRevealDialog extends StatelessWidget {
  const _RarityRevealDialog({required this.result, required this.points});

  final RecognitionResult result;
  final int points;

  @override
  Widget build(BuildContext context) {
    final rarityColor = RvColors.rarity(result.suggestedRarity);
    final confidence = (result.confidence * 100).round();

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: RvGlass(
            padding: const EdgeInsets.all(20),
            radius: 30,
            borderColor: rarityColor.withValues(alpha: 0.54),
            glowColor: rarityColor,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RevealBurstPainter(color: rarityColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.82, end: 1),
                      duration: const Duration(milliseconds: 720),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              rarityColor.withValues(alpha: 0.9),
                              rarityColor.withValues(alpha: 0.16),
                              Colors.transparent,
                            ],
                          ),
                          border: Border.all(
                            color: rarityColor.withValues(alpha: 0.72),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: rarityColor.withValues(alpha: 0.46),
                              blurRadius: 42,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _rarityIcon(result.suggestedRarity),
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      result.suggestedRarity.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: rarityColor,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.carName,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: RvColors.text),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result.reason,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RvColors.mutedText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _RevealMetric(
                            label: 'AI LOCK',
                            value: '$confidence%',
                            color: RvColors.electricBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: points),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return _RevealMetric(
                                label: 'VAULT XP',
                                value: '$value',
                                color: rarityColor,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Lock result'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _rarityIcon(String rarity) {
    return switch (rarity) {
      'Legendary' || 'Mythic' => Icons.workspace_premium_rounded,
      'Ultra Rare' => Icons.diamond_rounded,
      'Rare' => Icons.auto_awesome_rounded,
      'Uncommon' => Icons.bolt_rounded,
      _ => Icons.directions_car_rounded,
    };
  }
}

class _RevealMetric extends StatelessWidget {
  const _RevealMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: RvColors.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealBurstPainter extends CustomPainter {
  const _RevealBurstPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.25);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.16);

    for (var i = 0; i < 18; i++) {
      final angle = i * 0.349;
      final start = Offset(
        center.dx + 70 * math.cos(angle),
        center.dy + 70 * math.sin(angle),
      );
      final end = Offset(
        center.dx + 150 * math.cos(angle),
        center.dy + 150 * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RevealBurstPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RarityScorePanel extends StatelessWidget {
  const _RarityScorePanel({
    required this.rarity,
    required this.points,
    required this.city,
    required this.country,
  });

  final String rarity;
  final int points;
  final String city;
  final String country;

  @override
  Widget build(BuildContext context) {
    final score = (points / 500 * 10).clamp(0, 10).toStringAsFixed(1);

    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: RvColors.rarity(rarity),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: RvColors.rarity(rarity).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: RvColors.rarity(rarity).withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              color: RvColors.rarity(rarity),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$score/10 rarity in $country',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: RvColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$rarity spot near $city. Worth $points vault points.',
                  style: const TextStyle(color: RvColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecognitionResults extends StatelessWidget {
  const _RecognitionResults({required this.results, required this.onSelected});

  final List<RecognitionResult> results;
  final ValueChanged<RecognitionResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final result in results)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RvGlass(
              padding: EdgeInsets.zero,
              glowColor: RvColors.rarity(result.suggestedRarity),
              child: ListTile(
                onTap: () => onSelected(result),
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: RvColors.crimson,
                ),
                title: Text(
                  result.carName,
                  style: const TextStyle(
                    color: RvColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  '${(result.confidence * 100).round()}% match - ${result.reason}',
                  style: const TextStyle(color: RvColors.mutedText),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RarityChip(label: result.suggestedRarity),
                    const SizedBox(height: 4),
                    Text(
                      result.category,
                      style: const TextStyle(
                        color: RvColors.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecognitionErrorPanel extends StatelessWidget {
  const _RecognitionErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.all(14),
      borderColor: RvColors.crimson.withValues(alpha: 0.5),
      glowColor: RvColors.crimson,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: RvColors.crimson),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: RvColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            tooltip: 'Retry AI',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({
    required this.city,
    required this.country,
    required this.isLocating,
    required this.locationIntegrity,
    required this.onRefresh,
  });

  final String city;
  final String country;
  final bool isLocating;
  final String locationIntegrity;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RvGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: RvColors.electricBlue.withValues(alpha: 0.28),
      child: Row(
        children: [
          Icon(
            isLocating ? Icons.location_searching_rounded : Icons.my_location,
            color: RvColors.electricBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocating ? 'Getting location...' : '$city, $country',
                  style: const TextStyle(
                    color: RvColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _locationLabel(locationIntegrity),
                  style: const TextStyle(
                    color: RvColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isLocating ? null : onRefresh,
            tooltip: 'Refresh location',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  String _locationLabel(String value) {
    return switch (value) {
      'gps-verified' => 'GPS verified',
      'mock-location-review' => 'Possible fake GPS - review',
      'low-accuracy-review' => 'Low accuracy location - review',
      _ => 'Using profile location fallback',
    };
  }
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({
    required this.recognition,
    required this.locationIntegrity,
    required this.trustScore,
    required this.verificationStatus,
  });

  final RecognitionResult? recognition;
  final String locationIntegrity;
  final int trustScore;
  final String verificationStatus;

  @override
  Widget build(BuildContext context) {
    final flags = <_SafetyFlag>[
      _SafetyFlag(
        icon: Icons.pin_drop_rounded,
        label: _locationLabel(locationIntegrity),
        isWarning: locationIntegrity != 'gps-verified',
      ),
      _SafetyFlag(
        icon: Icons.directions_car_filled_rounded,
        label: recognition?.blurStatus == 'processed'
            ? 'Plate blurred'
            : (recognition?.licensePlateVisible ?? false)
            ? 'Plate visible'
            : 'Plate clear',
        isWarning: recognition?.licensePlateVisible ?? false,
      ),
      _SafetyFlag(
        icon: Icons.face_retouching_off_rounded,
        label: recognition?.blurStatus == 'processed'
            ? 'Face area blurred'
            : (recognition?.faceVisible ?? false)
            ? 'Face visible'
            : 'No face',
        isWarning: recognition?.faceVisible ?? false,
      ),
      _SafetyFlag(
        icon: Icons.auto_fix_high_rounded,
        label:
            'AI risk ${(((recognition?.syntheticImageRisk ?? 0) * 100).round())}%',
        isWarning: (recognition?.syntheticImageRisk ?? 0) >= 0.65,
      ),
    ];

    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: trustScore >= 70 ? RvColors.emerald : RvColors.hyperOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: RvColors.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Security scan',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: RvColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$trustScore% trust',
                style: TextStyle(
                  color: trustScore >= 70
                      ? RvColors.emerald
                      : RvColors.hyperOrange,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusLabel(verificationStatus),
            style: const TextStyle(color: RvColors.mutedText),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final flag in flags)
                Chip(
                  avatar: Icon(flag.icon, size: 17),
                  label: Text(flag.label),
                  backgroundColor: flag.isWarning
                      ? RvColors.hyperOrange.withValues(alpha: 0.14)
                      : RvColors.emerald.withValues(alpha: 0.13),
                  side: BorderSide(
                    color: flag.isWarning
                        ? RvColors.hyperOrange.withValues(alpha: 0.45)
                        : RvColors.emerald.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _locationLabel(String value) {
    return switch (value) {
      'gps-verified' => 'GPS verified',
      'mock-location-review' => 'Fake GPS risk',
      'low-accuracy-review' => 'Low accuracy',
      _ => 'Profile fallback',
    };
  }

  String _statusLabel(String value) {
    return switch (value) {
      'camera-captured' => 'Live camera capture with duplicate protection.',
      'gallery-review' => 'Gallery upload. Kept in review until trusted.',
      'privacy-review' => 'Needs plate/face blur before public-grade trust.',
      'privacy-redacted' => 'Plate/face risk was automatically blurred.',
      'location-review' => 'Location looks suspicious and needs review.',
      'authenticity-review' => 'Image authenticity needs moderator review.',
      _ => 'Security checks will run after image selection.',
    };
  }
}

class _SafetyFlag {
  const _SafetyFlag({
    required this.icon,
    required this.label,
    required this.isWarning,
  });

  final IconData icon;
  final String label;
  final bool isWarning;
}

class _AiResultPanel extends StatelessWidget {
  const _AiResultPanel({
    required this.carName,
    required this.category,
    required this.rarity,
    required this.points,
    required this.isRecognizing,
    required this.isInspecting,
    required this.hasImage,
    required this.integrity,
    required this.onRetry,
  });

  final String carName;
  final String category;
  final String rarity;
  final int points;
  final bool isRecognizing;
  final bool isInspecting;
  final bool hasImage;
  final SpotIntegrity? integrity;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final title = isInspecting
        ? 'Checking photo authenticity...'
        : isRecognizing
        ? 'AI is identifying this spot...'
        : carName.isEmpty
        ? 'Add a photo to identify'
        : carName;
    final subtitle = integrity == null
        ? 'Duplicate checks and trust score will run after photo selection.'
        : carName.isEmpty
        ? 'Name, category, rarity, and points will be filled automatically.'
        : '$category - $rarity - $points pts - ${integrity!.trustScore}% trust';

    return RvGlass(
      padding: const EdgeInsets.all(14),
      glowColor: RvColors.rarity(rarity),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: Center(
              child: isRecognizing || isInspecting
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RvColors.legendary,
                    )
                  : const Icon(
                      Icons.auto_awesome_rounded,
                      color: RvColors.legendary,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: RvColors.mutedText),
                ),
              ],
            ),
          ),
          if (hasImage && !isRecognizing && !isInspecting)
            IconButton(
              onPressed: onRetry,
              tooltip: 'Retry AI',
              icon: const Icon(Icons.refresh_rounded),
              color: RvColors.text,
            ),
        ],
      ),
    );
  }
}
