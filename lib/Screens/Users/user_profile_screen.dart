import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';
import 'package:web_chatter_mobile/Screens/Chat/chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String userId;
  final bool isCurrentUser;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _postCount = 0;
  String _joinedDate = '';
  String _lastActive = '';
  bool _isSendingFeedback = false;
  final _feedbackController = TextEditingController();
  bool _isFollowing = false;
  int _followingCount = 0;
  int _followersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _checkFollowStatus();
  }

  Future<void> _loadUserStats() async {
    final userRef = FirebaseDatabase.instance.ref('users/${widget.userId}');
    final statsSnapshot = await Future.wait([
      userRef.child('messageCount').get(),
      userRef.child('createdAt').get(),
      userRef.child('lastActive').get(),
      userRef.child('following').get(),
      userRef.child('followers').get(),
    ]);

    if (mounted) {
      setState(() {
        _postCount = (statsSnapshot[0].value ?? 0) as int;
        _joinedDate = _formatTimestamp(statsSnapshot[1].value as int? ?? 0);
        _lastActive = _formatLastActive(statsSnapshot[2].value as int? ?? 0);
        _followingCount = statsSnapshot[3].children.length;
        _followersCount = statsSnapshot[4].children.length;
      });
    }
  }

  Future<void> _checkFollowStatus() async {
    if (widget.isCurrentUser) return;

    final currentUserId = context.read<AuthService>().currentUser?.uid;
    if (currentUserId == null) return;

    final followSnapshot = await FirebaseDatabase.instance
        .ref('users/$currentUserId/following/${widget.userId}')
        .get();

    if (mounted) {
      setState(() {
        _isFollowing = followSnapshot.exists;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = context.read<AuthService>().currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isFollowing = !_isFollowing);

    try {
      if (_isFollowing) {
        // Follow user
        await Future.wait([
          FirebaseDatabase.instance
              .ref('users/$currentUserId/following/${widget.userId}')
              .set(true),
          FirebaseDatabase.instance
              .ref('users/${widget.userId}/followers/$currentUserId')
              .set(true),
          FirebaseDatabase.instance
              .ref('notifications/${widget.userId}')
              .push()
              .set({
            'type': 'follow',
            'senderId': currentUserId,
            'senderName': context.read<AuthService>().currentUser?.displayName,
            'message':
                '${context.read<AuthService>().currentUser?.displayName} started following you',
            'timestamp': ServerValue.timestamp,
            'read': false,
          }),
        ]);
      } else {
        // Unfollow user
        await Future.wait([
          FirebaseDatabase.instance
              .ref('users/$currentUserId/following/${widget.userId}')
              .remove(),
          FirebaseDatabase.instance
              .ref('users/${widget.userId}/followers/$currentUserId')
              .remove(),
        ]);
      }

      _loadUserStats(); // Refresh counts
    } catch (e) {
      setState(() => _isFollowing = !_isFollowing); // Revert on error
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Error updating follow status',
          isError: true,
        );
      }
    }
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'N/A';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatLastActive(int timestamp) {
    if (timestamp == 0) return 'Never';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return _formatTimestamp(timestamp);
    }
  }

  void _showFeedbackDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Send Feedback',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Consola',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Consola',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your feedback here...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Consola',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[700]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[700]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSendingFeedback ? null : _submitFeedback,
                    child: _isSendingFeedback
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Feedback',
                            style: TextStyle(
                              fontFamily: 'Consola',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      CustomSnackbar.show(
        context,
        'Please enter your feedback',
        isError: true,
      );
      return;
    }

    setState(() => _isSendingFeedback = true);

    try {
      final currentUser = context.read<AuthService>().currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final feedbackRef = FirebaseDatabase.instance.ref('feedback').push();
      await feedbackRef.set({
        'userId': currentUser.uid,
        'userName': widget.user['name'],
        'userEmail': widget.user['email'],
        'feedback': _feedbackController.text,
        'timestamp': ServerValue.timestamp,
        'read': false,
        'status': 'pending',
        'response': '',
      });

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(
          context,
          'Feedback submitted successfully',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Error submitting feedback: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingFeedback = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar Section
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: widget.user['useSimpleAvatar'] ||
                              widget.user['avatarSeed'] == null
                          ? Text(
                              widget.user['email'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontFamily: 'Consola',
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : RandomAvatar(
                              widget.user['avatarSeed'],
                              height: 100,
                              width: 100,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'Consola',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.user['email'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Consola',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Follow/Message Button
                  if (!widget.isCurrentUser)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _toggleFollow,
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: _isFollowing
                                ? Colors.white
                                : const Color(0xFF121212),
                            fontSize: 16,
                            fontFamily: 'Consola',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Stats Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Consola',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Following', '$_followingCount'),
                  _buildStatRow('Followers', '$_followersCount'),
                  _buildStatRow('Messages Sent', '$_postCount'),
                  _buildStatRow('Joined', _joinedDate),
                  _buildStatRow('Last Active', _lastActive),
                ],
              ),
            ),

            // Actions Section
            if (!widget.isCurrentUser) ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    _buildActionButton(
                      'Send Message',
                      Icons.message_outlined,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              otherUser: widget.user,
                              otherUserId: widget.userId,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      'Send Feedback',
                      Icons.feedback_outlined,
                      _showFeedbackDialog,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'Consola',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Consola',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}
