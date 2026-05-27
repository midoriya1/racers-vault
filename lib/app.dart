import 'dart:async';

import 'package:flutter/material.dart';

import 'design/rv_colors.dart';
import 'design/rv_theme.dart';
import 'models/app_user.dart';
import 'models/car_spot.dart';
import 'screens/add_spot_page.dart';
import 'screens/discover_page.dart';
import 'screens/feed_page.dart';
import 'screens/leaderboard_page.dart';
import 'screens/login_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/player_profile_page.dart';
import 'screens/profile_page.dart';
import 'screens/spot_detail_page.dart';
import 'screens/vault_page.dart';
import 'services/auth_service.dart';
import 'services/car_recognition_service.dart';
import 'services/vault_repository.dart';
import 'widgets/rv_glass.dart';

class RacersVaultApp extends StatelessWidget {
  const RacersVaultApp({
    super.key,
    required this.repository,
    this.authService = const AnonymousVaultAuthService(),
    this.carRecognitionService = const MockCarRecognitionService(),
  });

  final VaultRepository repository;
  final VaultAuthService authService;
  final CarRecognitionService carRecognitionService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Racers Vault',
      theme: RvTheme.dark(),
      home: VaultHomePage(
        repository: repository,
        authService: authService,
        carRecognitionService: carRecognitionService,
      ),
    );
  }
}

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({
    super.key,
    required this.repository,
    required this.authService,
    required this.carRecognitionService,
  });

  final VaultRepository repository;
  final VaultAuthService authService;
  final CarRecognitionService carRecognitionService;

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  int _selectedIndex = 0;
  AppUser? _currentUser;
  List<CarSpot> _spots = [];
  bool _isLoading = true;
  bool _isPosting = false;
  bool _needsLogin = false;
  Set<String> _followingUserIds = {};
  CarSpot? _pendingSpot;
  String? _pendingUploadError;
  String? _errorMessage;
  StreamSubscription<List<CarSpot>>? _spotsSubscription;

  @override
  void initState() {
    super.initState();
    _loadApp();
  }

  @override
  void dispose() {
    _spotsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadApp() async {
    try {
      final authUser = await widget.authService.restoreSession();
      if (widget.authService.requiresLogin && authUser == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _needsLogin = true;
          _isLoading = false;
        });
        return;
      }

      final user = await widget.repository.loadCurrentUser();
      final followingUserIds = user == null
          ? <String>{}
          : await widget.repository.loadFollowingIds();
      _spotsSubscription = widget.repository.watchSpots().listen((spots) {
        if (!mounted) {
          return;
        }

        setState(() {
          _spots = spots;
        });
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
        _followingUserIds = followingUserIds;
        _needsLogin = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  int get _totalPoints {
    final user = _currentUser;
    if (user == null) {
      return 0;
    }

    return _spots
        .where((spot) => spot.spotter == user.username)
        .fold(0, (total, spot) => total + spot.points);
  }

  List<CarSpot> get _mySpots {
    final user = _currentUser;
    if (user == null) {
      return [];
    }

    return _spots.where((spot) => spot.spotter == user.username).toList();
  }

  Future<void> _openAddSpot() async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    final newSpot = await Navigator.of(context).push<CarSpot>(
      MaterialPageRoute(
        builder: (_) => AddSpotPage(
          currentUser: user,
          carRecognitionService: widget.carRecognitionService,
        ),
      ),
    );

    if (newSpot == null) {
      return;
    }

    await _postSpot(newSpot);
  }

  Future<void> _postSpot(CarSpot newSpot) async {
    setState(() {
      _isPosting = true;
      _pendingUploadError = null;
    });

    try {
      await widget.repository.addSpot(newSpot);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedIndex = 0;
        _isPosting = false;
        _pendingSpot = null;
        _pendingUploadError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newSpot.carName} added for ${newSpot.points} pts'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPosting = false;
        _pendingSpot = newSpot;
        _pendingUploadError = _friendlyUploadError(error);
      });
    }
  }

  Future<void> _retryPendingUpload() async {
    final pendingSpot = _pendingSpot;
    if (pendingSpot == null || _isPosting) {
      return;
    }

    await _postSpot(pendingSpot);
  }

  String _friendlyUploadError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('Storage') || text.contains('bucket')) {
      return 'Media upload failed. Check Supabase Storage and try again.';
    }
    if (text.contains('duplicate') || text.contains('already')) {
      return text;
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'Network failed while uploading. Retry when your connection is stable.';
    }
    return text;
  }

  Future<void> _openSpotDetail(CarSpot spot) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpotDetailPage(
          spot: spot,
          currentUser: user,
          repository: widget.repository,
          onSpotterSelected: _openPlayerProfile,
        ),
      ),
    );
  }

  Future<void> _openPlayerProfile(String username) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(
          username: username,
          spots: _spots,
          currentUser: user,
          repository: widget.repository,
          onSpotSelected: _openSpotDetail,
          onFollowChanged: _refreshFollowingIds,
        ),
      ),
    );
  }

  Future<void> _refreshFollowingIds() async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    try {
      final followingUserIds = await widget.repository.loadFollowingIds();
      if (!mounted) {
        return;
      }
      setState(() {
        _followingUserIds = followingUserIds;
      });
    } catch (_) {
      // Keep the existing feed if the refresh fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _LoadingPage();
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _ErrorPage(message: errorMessage, onRetry: _retry);
    }

    if (_needsLogin) {
      return LoginPage(authService: widget.authService, onDone: _retry);
    }

    final user = _currentUser;
    if (user == null) {
      return OnboardingPage(
        onComplete: (draft) async {
          final newUser = await widget.repository.saveProfile(draft);
          final followingUserIds = await widget.repository.loadFollowingIds();
          setState(() {
            _currentUser = newUser;
            _followingUserIds = followingUserIds;
          });
        },
      );
    }

    final pages = [
      FeedPage(
        spots: _spots,
        totalPoints: _totalPoints,
        currentUser: user,
        followingUserIds: _followingUserIds,
        onSpotSelected: _openSpotDetail,
      ),
      DiscoverPage(
        spots: _spots,
        currentUser: user,
        onSpotSelected: _openSpotDetail,
      ),
      LeaderboardPage(
        spots: _spots,
        currentUser: user,
        onSpotterSelected: _openPlayerProfile,
      ),
      VaultPage(
        spots: _mySpots,
        totalPoints: _totalPoints,
        currentUser: user,
        onSpotSelected: _openSpotDetail,
      ),
      ProfilePage(
        spots: _mySpots,
        totalPoints: _totalPoints,
        currentUser: user,
        onSignOut: _signOut,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.9),
            radius: 1.1,
            colors: [Color(0xFF172033), RvColors.obsidian],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(child: pages[_selectedIndex]),
            if (_pendingSpot != null && !_isPosting)
              Positioned(
                left: 12,
                right: 12,
                top: MediaQuery.of(context).padding.top + 8,
                child: _PendingUploadBanner(
                  spot: _pendingSpot!,
                  message: _pendingUploadError ?? 'Upload failed.',
                  onRetry: _retryPendingUpload,
                  onDismiss: () {
                    setState(() {
                      _pendingSpot = null;
                      _pendingUploadError = null;
                    });
                  },
                ),
              ),
            if (_isPosting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: _PostingIndicator()),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isPosting ? null : _openAddSpot,
        backgroundColor: RvColors.crimson,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Scan'),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: RvColors.carbon.withValues(alpha: 0.92),
        indicatorColor: RvColors.crimson.withValues(alpha: 0.24),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed_rounded),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Rank',
          ),
          NavigationDestination(
            icon: Icon(Icons.garage_outlined),
            selectedIcon: Icon(Icons.garage_rounded),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _spotsSubscription?.cancel();
    _spotsSubscription = null;
    await _loadApp();
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
    await _spotsSubscription?.cancel();
    _spotsSubscription = null;
    setState(() {
      _selectedIndex = 0;
      _currentUser = null;
      _spots = [];
      _followingUserIds = {};
      _pendingSpot = null;
      _pendingUploadError = null;
      _needsLogin = widget.authService.requiresLogin;
    });
  }
}

class _PendingUploadBanner extends StatelessWidget {
  const _PendingUploadBanner({
    required this.spot,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final CarSpot spot;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: RvGlass(
        padding: const EdgeInsets.all(12),
        borderColor: RvColors.crimson.withValues(alpha: 0.5),
        glowColor: RvColors.crimson,
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, color: RvColors.crimson),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${spot.carName} is pending',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RvColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RvColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostingIndicator extends StatelessWidget {
  const _PostingIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RvColors.carbon,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RvColors.border),
        boxShadow: [
          BoxShadow(
            color: RvColors.electricBlue.withValues(alpha: 0.22),
            blurRadius: 24,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Adding to vault...',
              style: TextStyle(
                color: RvColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: RvColors.crimson,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not connect to Racers Vault',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: RvColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: RvColors.mutedText),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
