import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/bite_model.dart';
import '../services/content_service.dart';
import '../services/subscription_service.dart';
import '../widgets/subscription_gate.dart';
import '../widgets/locked_bite_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContentService _contentService = ContentService();
  late final SubscriptionService _subscriptionService;
  BiteModel? _todaysBite;
  List<BiteModel> _catchUpBites = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingComments = false;
  String _errorMessage = '';
  String _loadingMessage = 'Loading content...';
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  Map<String, int> _commentCountCache = {};
  
  // Sequential release system variables - cached for performance
  bool _isTodaysBiteUnlocked = false;
  DateTime? _nextUnlockTime;
  Duration _timeUntilUnlock = Duration.zero;
  DateTime? _lastUnlockCalculation;
  BiteModel? _cachedTodaysBite;

  @override
  void initState() {
    super.initState();
    _subscriptionService = SubscriptionService();
    _loadContent();
    _startContentRefreshTimer();
    _startCountdownTimer();
  }

  void _startContentRefreshTimer() {
    // Refresh content every 30 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _refreshContent();
    });
  }
  
  void _startCountdownTimer() {
    // Update countdown every second for unlock timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextUnlockTime != null) {
        final now = DateTime.now();
        final difference = _nextUnlockTime!.difference(now);
        
        if (difference.isNegative) {
          // Time to unlock! Refresh content
          setState(() {
            _isTodaysBiteUnlocked = true;
            _timeUntilUnlock = Duration.zero;
          });
          _refreshContent();
        } else {
          setState(() {
            _timeUntilUnlock = difference;
          });
        }
      }
    });
  }

  Future<void> _refreshContent() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final todaysBite = await _contentService.getTodaysBite();
      final catchUpBites = await _contentService.getCatchUpBites();

      // Load comment counts for all bites (similar to dinner table)
      BiteModel? todaysBiteWithComments;
      if (todaysBite != null) {
        final todaysCommentCount = await _getCommentCount(todaysBite.id);
        todaysBiteWithComments = todaysBite.copyWith(commentCount: todaysCommentCount);
        print('DEBUG: Refresh - Today\'s bite ${todaysBite.id} has $todaysCommentCount comments');
      }

      List<BiteModel> catchUpBitesWithComments = [];
      for (var bite in catchUpBites) {
        final commentCount = await _getCommentCount(bite.id);
        catchUpBitesWithComments.add(bite.copyWith(commentCount: commentCount));
        print('DEBUG: Refresh - Bite ${bite.id} (${bite.title}) has $commentCount comments');
      }

      // Simulate sequential release logic
      final now = DateTime.now();
      final unlockHour = 9; // 9 AM unlock time
      final todayUnlockTime = DateTime(now.year, now.month, now.day, unlockHour);
      
      bool isUnlocked = now.isAfter(todayUnlockTime);
      DateTime? nextUnlock;
      
      if (!isUnlocked) {
        nextUnlock = todayUnlockTime;
      }

      setState(() {
        _todaysBite = todaysBiteWithComments;
        _catchUpBites = catchUpBitesWithComments;
        _isTodaysBiteUnlocked = isUnlocked;
        _nextUnlockTime = nextUnlock;
        _isRefreshing = false;
      });
    } catch (e) {
      print('DEBUG: Error refreshing content: $e');
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadContent() async {
    final stopwatch = Stopwatch()..start();
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _loadingMessage = 'Loading content...';
      });

      print('PERF: Home - Starting content load...');
      
      final todaysBiteStopwatch = Stopwatch()..start();
      BiteModel? todaysBite;
      
      // Check if we have a cached today's bite for the current day
      if (_cachedTodaysBite != null && 
          _lastUnlockCalculation != null &&
          _lastUnlockCalculation!.day == DateTime.now().day &&
          _lastUnlockCalculation!.month == DateTime.now().month &&
          _lastUnlockCalculation!.year == DateTime.now().year) {
        // Use cached today's bite
        todaysBite = _cachedTodaysBite;
        print('PERF: Home - Used cached today\'s bite');
      } else {
        // Fetch and cache today's bite
        todaysBite = await _contentService.getTodaysBite();
        _cachedTodaysBite = todaysBite;
        print('PERF: Home - Fetched and cached today\'s bite');
      }
      
      todaysBiteStopwatch.stop();
      print('PERF: Home - getTodaysBite took ${todaysBiteStopwatch.elapsedMilliseconds}ms');

      final catchUpStopwatch = Stopwatch()..start();
      final catchUpBites = await _contentService.getCatchUpBites();
      catchUpStopwatch.stop();
      print('PERF: Home - getCatchUpBites took ${catchUpStopwatch.elapsedMilliseconds}ms');

      // Load comment counts for all bites (similar to dinner table)
      setState(() {
        _loadingMessage = 'Loading discussions...';
        _isLoadingComments = true;
      });
      
      final commentStopwatch = Stopwatch()..start();
      BiteModel? todaysBiteWithComments;
      if (todaysBite != null) {
        final todaysCommentCount = await _getCommentCount(todaysBite.id);
        todaysBiteWithComments = todaysBite.copyWith(commentCount: todaysCommentCount);
        print('DEBUG: Today\'s bite ${todaysBite.id} has $todaysCommentCount comments');
      }

      List<BiteModel> catchUpBitesWithComments = [];
      for (var bite in catchUpBites) {
        final commentCount = await _getCommentCount(bite.id);
        catchUpBitesWithComments.add(bite.copyWith(commentCount: commentCount));
        print('DEBUG: Bite ${bite.id} (${bite.title}) has $commentCount comments');
      }
      commentStopwatch.stop();
      print('PERF: Home - Loading ${catchUpBites.length + 1} comment counts took ${commentStopwatch.elapsedMilliseconds}ms');

      // Initialize sequential release logic - use cache if valid
      final releaseStopwatch = Stopwatch()..start();
      final now = DateTime.now();
      bool isUnlocked;
      DateTime? nextUnlock;
      
      // Check if we can use cached unlock calculation (valid for same day)
      if (_lastUnlockCalculation != null && 
          _lastUnlockCalculation!.day == now.day &&
          _lastUnlockCalculation!.month == now.month &&
          _lastUnlockCalculation!.year == now.year) {
        // Use cached values
        isUnlocked = _isTodaysBiteUnlocked;
        nextUnlock = _nextUnlockTime;
        print('PERF: Home - Used cached unlock calculation');
      } else {
        // Calculate new unlock status
        final unlockHour = 9; // 9 AM unlock time
        final todayUnlockTime = DateTime(now.year, now.month, now.day, unlockHour);
        
        isUnlocked = now.isAfter(todayUnlockTime);
        if (!isUnlocked) {
          nextUnlock = todayUnlockTime;
        }
        
        // Cache the calculation
        _lastUnlockCalculation = now;
        print('PERF: Home - Calculated new unlock status');
      }
      releaseStopwatch.stop();
      print('PERF: Home - Release logic took ${releaseStopwatch.elapsedMilliseconds}ms');

      setState(() {
        _todaysBite = todaysBiteWithComments;
        _catchUpBites = catchUpBitesWithComments;
        _isTodaysBiteUnlocked = isUnlocked;
        _nextUnlockTime = nextUnlock;
        _isLoading = false;
        _isLoadingComments = false;
        _loadingMessage = '';
      });
      
      stopwatch.stop();
      print('PERF: Home - Total _loadContent took ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      stopwatch.stop();
      print('PERF: Home - _loadContent FAILED after ${stopwatch.elapsedMilliseconds}ms: $e');
      setState(() {
        _errorMessage = 'Oops! Having trouble fetching today\'s wisdom. Give us a moment to sort this out.';
        _isLoading = false;
      });
    }
  }

  Future<int> _getCommentCount(String biteId) async {
    // Check cache first for performance
    if (_commentCountCache.containsKey(biteId)) {
      return _commentCountCache[biteId]!;
    }
    
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('comments')
          .where('biteId', isEqualTo: biteId)
          .get();
      final count = commentsSnapshot.docs.length;
      
      // Cache the result
      _commentCountCache[biteId] = count;
      return count;
    } catch (e) {
      print('DEBUG: Error getting comment count for bite $biteId: $e');
      return 0;
    }
  }

  // Method to refresh comment counts for specific bite (called when returning from comments)
  Future<void> _refreshBiteCommentCount(String biteId) async {
    try {
      final newCommentCount = await _getCommentCount(biteId);
      print('DEBUG: Refreshing comment count for bite $biteId: $newCommentCount');
      
      // Update today's bite if it matches
      if (_todaysBite?.id == biteId) {
        setState(() {
          _todaysBite = _todaysBite!.copyWith(commentCount: newCommentCount);
        });
      }
      
      // Update catch-up bites if any match
      final updatedCatchUpBites = _catchUpBites.map((bite) {
        if (bite.id == biteId) {
          return bite.copyWith(commentCount: newCommentCount);
        }
        return bite;
      }).toList();
      
      if (updatedCatchUpBites != _catchUpBites) {
        setState(() {
          _catchUpBites = updatedCatchUpBites;
        });
      }
    } catch (e) {
      print('DEBUG: Error refreshing comment count for bite $biteId: $e');
    }
  }

  void _navigateToPlayer(BiteModel bite) {
    // Always navigate to player without any premium checks
    Navigator.of(context).pushNamed('/player', arguments: bite);
  }

  void _navigateToLibrary() {
    Navigator.of(context).pushNamed('/library');
  }


  Widget _buildTodaysBiteSection() {
    if (_todaysBite == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Today\'s Bite',
                style: GoogleFonts.crimsonText(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF56500),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(
                Icons.schedule,
                size: 48,
                color: Color(0xFFF56500),
              ),
              const SizedBox(height: 12),
              const Text(
                'Today\'s wisdom is still simmering.\nCheck back in a bit!',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Main content
          InkWell(
            onTap: _isTodaysBiteUnlocked ? () => _navigateToPlayer(_todaysBite!) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with unlock status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTodaysBiteUnlocked 
                          ? [const Color(0xFFF56500), const Color(0xFFFFB366)]
                          : [Colors.grey.shade400, Colors.grey.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DAY',
                          style: TextStyle(
                            color: _isTodaysBiteUnlocked 
                                ? const Color(0xFFF56500) 
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _todaysBite!.dayNumber.toString(),
                          style: TextStyle(
                            color: _isTodaysBiteUnlocked 
                                ? const Color(0xFFF56500) 
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _isTodaysBiteUnlocked ? 'TODAY\'S BITE' : 'COMING SOON',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (!_isTodaysBiteUnlocked && _timeUntilUnlock.inSeconds > 0)
                            Text(
                              'Unlocks in ${_formatDuration(_timeUntilUnlock)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Thumbnail with lock overlay
                AspectRatio(
                  aspectRatio: 16 / 10, // Slightly taller as requested
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _todaysBite!.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _todaysBite!.thumbnailUrl,
                              fit: BoxFit.cover,
                              color: _isTodaysBiteUnlocked ? null : Colors.grey,
                              colorBlendMode: _isTodaysBiteUnlocked ? null : BlendMode.saturation,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFF56500),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                      
                      // Lock overlay
                      if (!_isTodaysBiteUnlocked)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                if (_timeUntilUnlock.inSeconds > 0)
                                  Text(
                                    'Unlocks in\n${_formatDuration(_timeUntilUnlock)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      
                      // "NEW" badge for unlocked content
                      if (_isTodaysBiteUnlocked)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF56500),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _todaysBite!.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: _isTodaysBiteUnlocked ? Colors.black : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isTodaysBiteUnlocked 
                            ? _todaysBite!.description
                            : 'This bite will be available soon. Get ready for some fresh wisdom!',
                        style: TextStyle(
                          color: _isTodaysBiteUnlocked ? Colors.grey : Colors.grey.shade500,
                          fontSize: 16,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: _isTodaysBiteUnlocked 
                                ? const Color(0xFFF56500) 
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _todaysBite!.formattedDuration,
                            style: TextStyle(
                              color: _isTodaysBiteUnlocked 
                                  ? const Color(0xFFF56500) 
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _isTodaysBiteUnlocked ? () => _navigateToPlayer(_todaysBite!) : null,
                            icon: Icon(_isTodaysBiteUnlocked ? Icons.play_circle_filled : Icons.lock),
                            label: Text(_isTodaysBiteUnlocked ? 'Listen Now' : 'Locked'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTodaysBiteUnlocked 
                                  ? const Color(0xFFF56500) 
                                  : Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreshBitesWaitingSection() {
    if (_catchUpBites.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no catch-up bites
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🍂 Fresh Bites Waiting',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Catch up on ${_catchUpBites.length} missed ${_catchUpBites.length == 1 ? 'bite' : 'bites'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _navigateToLibrary,
                child: const Text('VIEW ALL'),
              ),
            ],
          ),
        ),
        
        // Vertical list of catch-up bites (much better UX!)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _catchUpBites.length.clamp(0, 3), // Show max 3
          itemBuilder: (context, index) {
            final bite = _catchUpBites[index];
            return _buildCatchUpCard(bite);
          },
        ),
      ],
    );
  }

  Widget _buildCatchUpCard(BiteModel bite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToPlayer(bite),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: bite.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: bite.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFFF56500),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bite.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF56500).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DAY ${bite.dayNumber}',
                            style: const TextStyle(
                              color: Color(0xFFF56500),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bite.formattedDuration,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        if (bite.commentCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF56500),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.chat_bubble,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${bite.commentCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Play button
              IconButton(
                onPressed: () => _navigateToPlayer(bite),
                icon: const Icon(
                  Icons.play_circle_filled,
                  color: Color(0xFFF56500),
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${twoDigits(minutes)}m';
    } else if (minutes > 0) {
      return '${minutes}m ${twoDigits(seconds)}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pumpkin Bites',
          style: GoogleFonts.alice(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: const Color(0xFFF56500),
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: const Color(0xFFF56500).withOpacity(0.1),
        actions: [
          // Notification icon (can be implemented later)
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFF56500),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                  if (_isLoadingComments) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'This might take a moment...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.refresh,
                          size: 48,
                          color: Color(0xFFF56500),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadContent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF56500),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshContent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      const TrialStatusWidget(),
                      _buildTodaysBiteSectionWithAccess(),
                      _buildFreshBitesSectionWithAccess(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTodaysBiteSectionWithAccess() {
    return StreamBuilder<bool>(
      stream: _subscriptionService.subscriptionStatusStream,
      initialData: _subscriptionService.hasContentAccess,
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        
        if (hasAccess || _subscriptionService.hasContentAccess) {
          // User has access - show normal content
          return _buildTodaysBiteSection();
        } else {
          // Trial expired - show locked bite using user's NEXT sequential bite
          return FutureBuilder<BiteModel?>(
            future: _contentService.getUsersNextBite(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasData && snapshot.data != null) {
                return LockedBiteWidget(
                  bite: snapshot.data!,
                  title: "Today's Bite",
                );
              } else {
                // Fallback to subscription gate if no bite available
                return const SubscriptionGate(
                  child: SizedBox.shrink(),
                  customMessage: "Today's Story",
                );
              }
            },
          );
        }
      },
    );
  }

  Widget _buildFreshBitesSectionWithAccess() {
    return StreamBuilder<bool>(
      stream: _subscriptionService.subscriptionStatusStream,
      initialData: _subscriptionService.hasContentAccess,
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        
        if (hasAccess || _subscriptionService.hasContentAccess) {
          // User has access - show normal content
          return _buildFreshBitesWaitingSection();
        } else if (_catchUpBites.isNotEmpty) {
          // Trial expired - show user's most recent available bite as locked preview
          return LockedBiteWidget(
            bite: _catchUpBites.first, // This is already user-specific from the fixed getCatchUpBites
            title: "Fresh Stories",
          );
        } else {
          // No content available - show subscription gate
          return const SubscriptionGate(
            child: SizedBox.shrink(),
            customMessage: "Fresh Stories",
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _commentCountCache.clear();
    super.dispose();
  }
}