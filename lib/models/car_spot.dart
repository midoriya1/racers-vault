import 'package:flutter/material.dart';

class CarSpot {
  const CarSpot({
    required this.id,
    required this.userId,
    required this.spotter,
    required this.city,
    required this.country,
    required this.category,
    required this.carName,
    required this.rarity,
    required this.points,
    required this.caption,
    required this.colorA,
    required this.colorB,
    required this.accent,
    required this.likes,
    required this.comments,
    required this.createdAt,
    this.mediaUrl,
    this.localMediaPath,
    this.imageHash,
    this.perceptualHash,
    this.captureSource = 'unknown',
    this.trustScore = 50,
    this.verificationStatus = 'unverified',
    this.aiConfidence = 0,
    this.recognitionNote = '',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleGeneration = '',
    this.yearRange = '',
    this.bodyType = '',
    this.privacyPlateDetected = false,
    this.privacyFaceDetected = false,
    this.syntheticImageRisk = 0,
    this.manipulationRisk = 0,
    this.locationIntegrity = 'profile-fallback',
    this.securityNotes = '',
    this.blurStatus = 'not_needed',
  });

  final String id;
  final String userId;
  final String spotter;
  final String city;
  final String country;
  final String category;
  final String carName;
  final String rarity;
  final int points;
  final String caption;
  final Color colorA;
  final Color colorB;
  final Color accent;
  final int likes;
  final int comments;
  final DateTime createdAt;
  final String? mediaUrl;
  final String? localMediaPath;
  final String? imageHash;
  final String? perceptualHash;
  final String captureSource;
  final int trustScore;
  final String verificationStatus;
  final double aiConfidence;
  final String recognitionNote;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleGeneration;
  final String yearRange;
  final String bodyType;
  final bool privacyPlateDetected;
  final bool privacyFaceDetected;
  final double syntheticImageRisk;
  final double manipulationRisk;
  final String locationIntegrity;
  final String securityNotes;
  final String blurStatus;
}
