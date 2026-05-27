import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../data/rarity_data.dart';
import '../models/app_user.dart';
import '../models/car_spot.dart';
import '../models/moderation_case.dart';
import '../models/spot_comment.dart';
import 'spot_integrity_service.dart';

abstract class VaultRepository {
  Future<AppUser?> loadCurrentUser();
  Future<AppUser?> loadUserById(String userId);
  Future<AppUser> saveProfile(ProfileDraft draft);
  Stream<List<CarSpot>> watchSpots();
  Future<void> addSpot(CarSpot spot);
  Future<bool> isSpotLiked(String spotId);
  Future<void> setSpotLiked(CarSpot spot, {required bool liked});
  Future<List<SpotComment>> loadComments(String spotId);
  Future<void> addComment(CarSpot spot, AppUser user, String body);
  Future<bool> isFollowing(String userId);
  Future<Set<String>> loadFollowingIds();
  Future<void> setFollowing(String userId, {required bool following});
  Future<void> reportSpot(
    CarSpot spot,
    AppUser user,
    ModerationCaseDraft report,
  );
  Future<List<ModerationCase>> loadModerationQueue();
  Future<void> updateModerationCaseStatus(
    ModerationCase moderationCase, {
    required String status,
    String note,
  });
}

class FirebaseVaultRepository implements VaultRepository {
  FirebaseVaultRepository({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<AppUser?> loadCurrentUser() async {
    final firebaseUser = await _ensureSignedIn();
    final snapshot = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return _userFromData(firebaseUser.uid, snapshot.data()!);
  }

  @override
  Future<AppUser> saveProfile(ProfileDraft draft) async {
    final firebaseUser = await _ensureSignedIn();
    final appUser = AppUser(
      uid: firebaseUser.uid,
      username: draft.username,
      country: draft.country,
      city: draft.city,
      bio: draft.bio,
      avatarUrl: draft.avatarUrl,
    );

    await _firestore.collection('users').doc(appUser.uid).set({
      'username': appUser.username,
      'country': appUser.country,
      'city': appUser.city,
      'totalPoints': 0,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return appUser;
  }

  @override
  Future<AppUser?> loadUserById(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) {
      return null;
    }
    return _userFromData(userId, snapshot.data()!);
  }

  @override
  Stream<List<CarSpot>> watchSpots() {
    return _firestore
        .collection('spots')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => _spotFromDoc(doc)).toList(),
        );
  }

  @override
  Future<void> addSpot(CarSpot spot) async {
    await _ensureNotDuplicate(spot);

    final spotRef = _firestore.collection('spots').doc();
    final userRef = _firestore.collection('users').doc(spot.userId);
    final mediaUrl = await _uploadSpotMedia(spot, spotRef.id);

    await _firestore.runTransaction((transaction) async {
      transaction.set(spotRef, {
        'userId': spot.userId,
        'spotter': spot.spotter,
        'city': spot.city,
        'country': spot.country,
        'category': spot.category,
        'carName': spot.carName,
        'rarity': spot.rarity,
        'points': spot.points,
        'caption': spot.caption,
        'mediaUrl': mediaUrl,
        'imageHash': spot.imageHash,
        'perceptualHash': spot.perceptualHash,
        'captureSource': spot.captureSource,
        'trustScore': spot.trustScore,
        'verificationStatus': spot.verificationStatus,
        'aiConfidence': spot.aiConfidence,
        'recognitionNote': spot.recognitionNote,
        'vehicleMake': spot.vehicleMake,
        'vehicleModel': spot.vehicleModel,
        'vehicleGeneration': spot.vehicleGeneration,
        'yearRange': spot.yearRange,
        'bodyType': spot.bodyType,
        'privacyPlateDetected': spot.privacyPlateDetected,
        'privacyFaceDetected': spot.privacyFaceDetected,
        'syntheticImageRisk': spot.syntheticImageRisk,
        'manipulationRisk': spot.manipulationRisk,
        'locationIntegrity': spot.locationIntegrity,
        'securityNotes': spot.securityNotes,
        'blurStatus': spot.blurStatus,
        'likes': spot.likes,
        'comments': spot.comments,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'totalPoints': FieldValue.increment(spot.points),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<bool> isSpotLiked(String spotId) async {
    final user = await _ensureSignedIn();
    final doc = await _firestore
        .collection('spotLikes')
        .doc('${user.uid}_$spotId')
        .get();
    return doc.exists;
  }

  @override
  Future<void> setSpotLiked(CarSpot spot, {required bool liked}) async {
    final user = await _ensureSignedIn();
    final likeRef = _firestore
        .collection('spotLikes')
        .doc('${user.uid}_${spot.id}');
    final spotRef = _firestore.collection('spots').doc(spot.id);

    await _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      if (liked && !likeSnapshot.exists) {
        transaction.set(likeRef, {
          'userId': user.uid,
          'spotId': spot.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(spotRef, {'likes': FieldValue.increment(1)});
      } else if (!liked && likeSnapshot.exists) {
        transaction.delete(likeRef);
        transaction.update(spotRef, {'likes': FieldValue.increment(-1)});
      }
    });
  }

  @override
  Future<List<SpotComment>> loadComments(String spotId) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('spotId', isEqualTo: spotId)
        .orderBy('createdAt', descending: false)
        .limit(100)
        .get();
    return snapshot.docs.map(_commentFromDoc).toList();
  }

  @override
  Future<void> addComment(CarSpot spot, AppUser user, String body) async {
    final commentRef = _firestore.collection('comments').doc();
    final spotRef = _firestore.collection('spots').doc(spot.id);
    await _firestore.runTransaction((transaction) async {
      transaction.set(commentRef, {
        'spotId': spot.id,
        'userId': user.uid,
        'username': user.username,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(spotRef, {'comments': FieldValue.increment(1)});
    });
  }

  @override
  Future<bool> isFollowing(String userId) async {
    final user = await _ensureSignedIn();
    final doc = await _firestore
        .collection('follows')
        .doc('${user.uid}_$userId')
        .get();
    return doc.exists;
  }

  @override
  Future<Set<String>> loadFollowingIds() async {
    final user = await _ensureSignedIn();
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: user.uid)
        .get();
    return snapshot.docs
        .map((doc) => doc.data()['followingId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> setFollowing(String userId, {required bool following}) async {
    final user = await _ensureSignedIn();
    if (user.uid == userId) {
      return;
    }

    final followRef = _firestore
        .collection('follows')
        .doc('${user.uid}_$userId');
    if (following) {
      await followRef.set({
        'followerId': user.uid,
        'followingId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await followRef.delete();
    }
  }

  @override
  Future<void> reportSpot(
    CarSpot spot,
    AppUser user,
    ModerationCaseDraft report,
  ) async {
    await _firestore.collection('reports').add({
      'spotId': spot.id,
      'reporterId': user.uid,
      'type': report.type,
      'reason': report.reason,
      'details': report.details,
      'suggestedCarName': report.suggestedCarName,
      'priority': report.priority,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<ModerationCase>> loadModerationQueue() async {
    return [];
  }

  @override
  Future<void> updateModerationCaseStatus(
    ModerationCase moderationCase, {
    required String status,
    String note = '',
  }) async {}

  Future<void> _ensureNotDuplicate(CarSpot spot) async {
    final imageHash = spot.imageHash;
    if (imageHash != null && imageHash.isNotEmpty) {
      final exact = await _firestore
          .collection('spots')
          .where('imageHash', isEqualTo: imageHash)
          .limit(1)
          .get();
      if (exact.docs.isNotEmpty) {
        throw StateError('This exact photo is already in Racers Vault.');
      }
    }

    final perceptualHash = spot.perceptualHash;
    if (perceptualHash == null || perceptualHash.isEmpty) {
      return;
    }

    final recent = await _firestore
        .collection('spots')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    for (final doc in recent.docs) {
      final existing = doc.data()['perceptualHash'] as String?;
      if (existing != null &&
          perceptualHashDistance(perceptualHash, existing) <= 6) {
        throw StateError('This photo looks too similar to an existing spot.');
      }
    }
  }

  Future<String?> _uploadSpotMedia(CarSpot spot, String spotId) async {
    final localPath = spot.localMediaPath;
    if (localPath == null || localPath.isEmpty) {
      return spot.mediaUrl;
    }

    final bucket = Firebase.app().options.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw StateError('Firebase Storage bucket is not configured.');
    }

    final token = await _ensureSignedIn().then((user) => user.getIdToken());
    final objectPath = 'spots/${spot.userId}/$spotId.jpg';
    final file = File(localPath);
    final uploadUri = Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o',
      {'uploadType': 'media', 'name': objectPath},
    );

    final response = await http.post(
      uploadUri,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'image/jpeg'},
      body: await file.readAsBytes(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isEmpty
          ? 'No response body'
          : jsonDecode(response.body).toString();
      throw StateError('Image upload failed: ${response.statusCode} $body');
    }

    return Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o/${Uri.encodeComponent(objectPath)}',
      {'alt': 'media'},
    ).toString();
  }

  Future<firebase_auth.User> _ensureSignedIn() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }
}

class InMemoryVaultRepository implements VaultRepository {
  InMemoryVaultRepository({List<CarSpot>? initialSpots})
    : _spots = List.of(initialSpots ?? sampleSpots);

  final List<CarSpot> _spots;
  final Set<String> _following = {};
  final _controller = StreamController<List<CarSpot>>.broadcast();
  AppUser? _currentUser;

  @override
  Future<AppUser?> loadCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<AppUser> saveProfile(ProfileDraft draft) async {
    _currentUser = AppUser(
      uid: 'local-user',
      username: draft.username,
      country: draft.country,
      city: draft.city,
      isModerator: true,
      bio: draft.bio,
      avatarUrl: draft.avatarLocalPath ?? draft.avatarUrl,
    );
    return _currentUser!;
  }

  @override
  Future<AppUser?> loadUserById(String userId) async {
    if (_currentUser?.uid == userId) {
      return _currentUser;
    }
    return null;
  }

  @override
  Stream<List<CarSpot>> watchSpots() {
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_spots));
      final subscription = _controller.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> addSpot(CarSpot spot) async {
    _spots.insert(0, spot);
    _controller.add(List.unmodifiable(_spots));
  }

  @override
  Future<bool> isSpotLiked(String spotId) async => false;

  @override
  Future<void> setSpotLiked(CarSpot spot, {required bool liked}) async {}

  @override
  Future<List<SpotComment>> loadComments(String spotId) async => [];

  @override
  Future<void> addComment(CarSpot spot, AppUser user, String body) async {}

  @override
  Future<bool> isFollowing(String userId) async => _following.contains(userId);

  @override
  Future<Set<String>> loadFollowingIds() async => _following.toSet();

  @override
  Future<void> setFollowing(String userId, {required bool following}) async {
    if (following) {
      _following.add(userId);
    } else {
      _following.remove(userId);
    }
  }

  @override
  Future<void> reportSpot(
    CarSpot spot,
    AppUser user,
    ModerationCaseDraft report,
  ) async {}

  @override
  Future<List<ModerationCase>> loadModerationQueue() async {
    return [];
  }

  @override
  Future<void> updateModerationCaseStatus(
    ModerationCase moderationCase, {
    required String status,
    String note = '',
  }) async {}
}

AppUser _userFromData(String uid, Map<String, dynamic> data) {
  return AppUser(
    uid: uid,
    username: data['username'] as String? ?? 'Spotter',
    country: data['country'] as String? ?? 'India',
    city: data['city'] as String? ?? 'Mumbai',
    isModerator: data['isModerator'] as bool? ?? false,
    bio: data['bio'] as String? ?? '',
    avatarUrl: data['avatarUrl'] as String?,
  );
}

SpotComment _commentFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final createdAt = data['createdAt'];
  return SpotComment(
    id: doc.id,
    spotId: data['spotId'] as String? ?? '',
    userId: data['userId'] as String? ?? '',
    username: data['username'] as String? ?? 'Spotter',
    body: data['body'] as String? ?? '',
    createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
  );
}

CarSpot _spotFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final rarity = data['rarity'] as String? ?? 'Rare';
  final colors = spotColors[rarity] ?? spotColors['Rare']!;
  final createdAt = data['createdAt'];

  return CarSpot(
    id: doc.id,
    userId: data['userId'] as String? ?? '',
    spotter: data['spotter'] as String? ?? 'Spotter',
    city: data['city'] as String? ?? '',
    country: data['country'] as String? ?? '',
    category: data['category'] as String? ?? 'Cars',
    carName: data['carName'] as String? ?? 'Unknown car',
    rarity: rarity,
    points: data['points'] as int? ?? rarityPoints[rarity] ?? 75,
    caption: data['caption'] as String? ?? '',
    colorA: colors.$1,
    colorB: colors.$2,
    accent: colors.$3,
    likes: data['likes'] as int? ?? 0,
    comments: data['comments'] as int? ?? 0,
    createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    mediaUrl: data['mediaUrl'] as String?,
    imageHash: data['imageHash'] as String?,
    perceptualHash: data['perceptualHash'] as String?,
    captureSource: data['captureSource'] as String? ?? 'unknown',
    trustScore: data['trustScore'] as int? ?? 50,
    verificationStatus: data['verificationStatus'] as String? ?? 'unverified',
    aiConfidence: (data['aiConfidence'] as num?)?.toDouble() ?? 0,
    recognitionNote: data['recognitionNote'] as String? ?? '',
    vehicleMake: data['vehicleMake'] as String? ?? '',
    vehicleModel: data['vehicleModel'] as String? ?? '',
    vehicleGeneration: data['vehicleGeneration'] as String? ?? '',
    yearRange: data['yearRange'] as String? ?? '',
    bodyType: data['bodyType'] as String? ?? '',
    privacyPlateDetected: data['privacyPlateDetected'] as bool? ?? false,
    privacyFaceDetected: data['privacyFaceDetected'] as bool? ?? false,
    syntheticImageRisk: (data['syntheticImageRisk'] as num?)?.toDouble() ?? 0,
    manipulationRisk: (data['manipulationRisk'] as num?)?.toDouble() ?? 0,
    locationIntegrity:
        data['locationIntegrity'] as String? ?? 'profile-fallback',
    securityNotes: data['securityNotes'] as String? ?? '',
    blurStatus: data['blurStatus'] as String? ?? 'not_needed',
  );
}
