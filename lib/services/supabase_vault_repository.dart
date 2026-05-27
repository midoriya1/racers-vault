import 'dart:io';

import 'package:supabase/supabase.dart';

import '../data/rarity_data.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../models/moderation_case.dart';
import '../models/spot_comment.dart';
import 'spot_integrity_service.dart';
import 'vault_repository.dart';

class SupabaseVaultRepository implements VaultRepository {
  SupabaseVaultRepository({required this.client});

  final SupabaseClient client;

  @override
  Future<AppUser?> loadCurrentUser() async {
    final user = await _ensureSignedIn();
    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return _userFromData(user.id, data);
  }

  @override
  Future<AppUser> saveProfile(ProfileDraft draft) async {
    final user = await _ensureSignedIn();
    final appUser = AppUser(
      uid: user.id,
      username: draft.username,
      country: draft.country,
      city: draft.city,
    );

    await client.from('profiles').upsert({
      'id': appUser.uid,
      'username': appUser.username,
      'country': appUser.country,
      'city': appUser.city,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    return appUser;
  }

  @override
  Stream<List<CarSpot>> watchSpots() {
    return client
        .from('spots')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(_spotFromData).toList());
  }

  @override
  Future<void> addSpot(CarSpot spot) async {
    await _ensureNotDuplicate(spot);

    final user = await _ensureSignedIn();
    final spotId = _createSpotId();
    final mediaUrl = await _uploadSpotMedia(spot, user.id, spotId);

    await client.from('spots').insert({
      'id': spotId,
      'user_id': user.id,
      'spotter': spot.spotter,
      'city': spot.city,
      'country': spot.country,
      'category': spot.category,
      'car_name': spot.carName,
      'rarity': spot.rarity,
      'points': spot.points,
      'caption': spot.caption,
      'media_url': mediaUrl,
      'image_hash': spot.imageHash,
      'perceptual_hash': spot.perceptualHash,
      'capture_source': spot.captureSource,
      'trust_score': spot.trustScore,
      'verification_status': spot.verificationStatus,
      'ai_confidence': spot.aiConfidence,
      'recognition_note': spot.recognitionNote,
      'vehicle_make': spot.vehicleMake,
      'vehicle_model': spot.vehicleModel,
      'vehicle_generation': spot.vehicleGeneration,
      'year_range': spot.yearRange,
      'body_type': spot.bodyType,
      'privacy_plate_detected': spot.privacyPlateDetected,
      'privacy_face_detected': spot.privacyFaceDetected,
      'synthetic_image_risk': spot.syntheticImageRisk,
      'manipulation_risk': spot.manipulationRisk,
      'location_integrity': spot.locationIntegrity,
      'security_notes': spot.securityNotes,
      'blur_status': spot.blurStatus,
      'likes': spot.likes,
      'comments': spot.comments,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<bool> isSpotLiked(String spotId) async {
    final user = await _ensureSignedIn();
    final rows = await client
        .from('likes')
        .select('spot_id')
        .eq('spot_id', spotId)
        .eq('user_id', user.id)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> setSpotLiked(CarSpot spot, {required bool liked}) async {
    final user = await _ensureSignedIn();
    final isLiked = await isSpotLiked(spot.id);
    if (liked == isLiked) {
      return;
    }

    if (liked) {
      await client.from('likes').insert({
        'user_id': user.id,
        'spot_id': spot.id,
      });
      await client.rpc(
        'increment_spot_likes',
        params: {'target_spot_id': spot.id, 'delta': 1},
      );
    } else {
      await client
          .from('likes')
          .delete()
          .eq('spot_id', spot.id)
          .eq('user_id', user.id);
      await client.rpc(
        'increment_spot_likes',
        params: {'target_spot_id': spot.id, 'delta': -1},
      );
    }
  }

  @override
  Future<List<SpotComment>> loadComments(String spotId) async {
    final rows = await client
        .from('comments')
        .select()
        .eq('spot_id', spotId)
        .order('created_at', ascending: true)
        .limit(100);
    return rows.map(_commentFromData).toList();
  }

  @override
  Future<void> addComment(CarSpot spot, AppUser user, String body) async {
    await client.from('comments').insert({
      'spot_id': spot.id,
      'user_id': user.uid,
      'username': user.username,
      'body': body,
    });
    await client.rpc(
      'increment_spot_comments',
      params: {'target_spot_id': spot.id, 'delta': 1},
    );
  }

  @override
  Future<bool> isFollowing(String userId) async {
    final user = await _ensureSignedIn();
    final rows = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', user.id)
        .eq('following_id', userId)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<Set<String>> loadFollowingIds() async {
    final user = await _ensureSignedIn();
    final rows = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', user.id);
    return rows
        .map((row) => row['following_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> setFollowing(String userId, {required bool following}) async {
    final user = await _ensureSignedIn();
    if (user.id == userId) {
      return;
    }

    if (following) {
      await client.from('follows').upsert({
        'follower_id': user.id,
        'following_id': userId,
      });
    } else {
      await client
          .from('follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', userId);
    }
  }

  @override
  Future<void> reportSpot(
    CarSpot spot,
    AppUser user,
    ModerationCaseDraft report,
  ) async {
    await client.from('reports').insert({
      'spot_id': spot.id,
      'reporter_id': user.uid,
      'type': report.type,
      'reason': report.reason,
      'details': report.details,
      'suggested_car_name': report.suggestedCarName,
      'priority': report.priority,
      'status': 'open',
    });
  }

  Future<void> _ensureNotDuplicate(CarSpot spot) async {
    final imageHash = spot.imageHash;
    if (imageHash != null && imageHash.isNotEmpty) {
      final exact = await client
          .from('spots')
          .select('id')
          .eq('image_hash', imageHash)
          .limit(1);
      if (exact.isNotEmpty) {
        throw StateError('This exact photo is already in Racers Vault.');
      }
    }

    final perceptualHash = spot.perceptualHash;
    if (perceptualHash == null || perceptualHash.isEmpty) {
      return;
    }

    final recent = await client
        .from('spots')
        .select('perceptual_hash')
        .order('created_at', ascending: false)
        .limit(100);
    for (final row in recent) {
      final existing = row['perceptual_hash'] as String?;
      if (existing != null &&
          perceptualHashDistance(perceptualHash, existing) <= 6) {
        throw StateError('This photo looks too similar to an existing spot.');
      }
    }
  }

  Future<User> _ensureSignedIn() async {
    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    throw StateError('You must sign in before using Racers Vault.');
  }

  Future<String?> _uploadSpotMedia(
    CarSpot spot,
    String userId,
    String spotId,
  ) async {
    final localPath = spot.localMediaPath;
    if (localPath == null || localPath.isEmpty) {
      return spot.mediaUrl;
    }

    final file = File(localPath);
    final extension = _extensionForPath(localPath);
    final objectPath = '$userId/$spotId$extension';

    await client.storage
        .from('spot-media')
        .upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            contentType: _contentTypeForExtension(extension),
            upsert: true,
          ),
        );

    return client.storage.from('spot-media').getPublicUrl(objectPath);
  }

  String _createSpotId() {
    return 'spot-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}

SpotComment _commentFromData(Map<String, dynamic> data) {
  final createdAt = data['created_at'];
  return SpotComment(
    id: data['id'] as String? ?? '',
    spotId: data['spot_id'] as String? ?? '',
    userId: data['user_id'] as String? ?? '',
    username: data['username'] as String? ?? 'Spotter',
    body: data['body'] as String? ?? '',
    createdAt: createdAt is String
        ? DateTime.tryParse(createdAt) ?? DateTime.now()
        : DateTime.now(),
  );
}

AppUser _userFromData(String uid, Map<String, dynamic> data) {
  return AppUser(
    uid: uid,
    username: data['username'] as String? ?? 'Spotter',
    country: data['country'] as String? ?? 'India',
    city: data['city'] as String? ?? 'Mumbai',
  );
}

CarSpot _spotFromData(Map<String, dynamic> data) {
  final rarity = data['rarity'] as String? ?? 'Rare';
  final colors = spotColors[rarity] ?? spotColors['Rare']!;
  final createdAt = data['created_at'];

  return CarSpot(
    id: data['id'] as String? ?? '',
    userId: data['user_id'] as String? ?? '',
    spotter: data['spotter'] as String? ?? 'Spotter',
    city: data['city'] as String? ?? '',
    country: data['country'] as String? ?? '',
    category: data['category'] as String? ?? 'Cars',
    carName: data['car_name'] as String? ?? 'Unknown car',
    rarity: rarity,
    points: data['points'] as int? ?? rarityPoints[rarity] ?? 75,
    caption: data['caption'] as String? ?? '',
    colorA: colors.$1,
    colorB: colors.$2,
    accent: colors.$3,
    likes: data['likes'] as int? ?? 0,
    comments: data['comments'] as int? ?? 0,
    createdAt: createdAt is String
        ? DateTime.tryParse(createdAt) ?? DateTime.now()
        : DateTime.now(),
    mediaUrl: data['media_url'] as String?,
    imageHash: data['image_hash'] as String?,
    perceptualHash: data['perceptual_hash'] as String?,
    captureSource: data['capture_source'] as String? ?? 'unknown',
    trustScore: data['trust_score'] as int? ?? 50,
    verificationStatus: data['verification_status'] as String? ?? 'unverified',
    aiConfidence: (data['ai_confidence'] as num?)?.toDouble() ?? 0,
    recognitionNote: data['recognition_note'] as String? ?? '',
    vehicleMake: data['vehicle_make'] as String? ?? '',
    vehicleModel: data['vehicle_model'] as String? ?? '',
    vehicleGeneration: data['vehicle_generation'] as String? ?? '',
    yearRange: data['year_range'] as String? ?? '',
    bodyType: data['body_type'] as String? ?? '',
    privacyPlateDetected: data['privacy_plate_detected'] as bool? ?? false,
    privacyFaceDetected: data['privacy_face_detected'] as bool? ?? false,
    syntheticImageRisk: (data['synthetic_image_risk'] as num?)?.toDouble() ?? 0,
    manipulationRisk: (data['manipulation_risk'] as num?)?.toDouble() ?? 0,
    locationIntegrity:
        data['location_integrity'] as String? ?? 'profile-fallback',
    securityNotes: data['security_notes'] as String? ?? '',
    blurStatus: data['blur_status'] as String? ?? 'not_needed',
  );
}

String _extensionForPath(String path) {
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex == -1) {
    return '.jpg';
  }

  final extension = path.substring(dotIndex).toLowerCase();
  return switch (extension) {
    '.jpeg' || '.jpg' || '.png' || '.webp' => extension,
    _ => '.jpg',
  };
}

String _contentTypeForExtension(String extension) {
  return switch (extension) {
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
