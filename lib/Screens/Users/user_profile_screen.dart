import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _optimisticIsFollowing = false;
  bool _hasInitialData = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = context.read<AuthService>().currentUser?.uid;
    if (currentUserId != null) {
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/$currentUserId/following/${widget.userId}')
            .get();
        if (mounted) {
          setState(() {
            _optimisticIsFollowing = snapshot.value != null;
            _hasInitialData = true; // Set the flag when we have initial data
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _optimisticIsFollowing = false;
            _hasInitialData = true;
          });
        }
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = context.read<AuthService>().currentUser?.uid;
    if (currentUserId == null) return;

    // Store the current state before toggling
    final wasFollowing = _optimisticIsFollowing;

    // Optimistically update UI
    setState(() {
      _optimisticIsFollowing = !_optimisticIsFollowing;
    });

    try {
      final currentUserSnapshot =
          await FirebaseDatabase.instance.ref('users/$currentUserId').get();

      final currentUserData = currentUserSnapshot.value as Map?;
      final currentUserName = currentUserData?['name'] as String?;

      if (currentUserName == null) {
        throw Exception('Could not get current user data');
      }

      if (wasFollowing) {
        // Unfollow
        await Future.wait([
          FirebaseDatabase.instance
              .ref('users/$currentUserId/following/${widget.userId}')
              .remove(),
          FirebaseDatabase.instance
              .ref('users/${widget.userId}/followers/$currentUserId')
              .remove(),
        ]);
      } else {
        // Follow
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
            'senderName': currentUserName,
            'message': '$currentUserName started following you',
            'timestamp': ServerValue.timestamp,
            'read': false
          })
        ]);
      }

      if (mounted) {
        CustomSnackbar.show(
          context,
          !wasFollowing ? 'Following user' : 'Unfollowed user',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticIsFollowing = wasFollowing;
        });
        CustomSnackbar.show(
          context,
          'Error updating follow status. Please try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final useSimpleAvatar = widget.user['useSimpleAvatar'] ?? false;
    final avatarSeed = widget.user['avatarSeed'] as String?;
    final email = widget.user['email'] as String;
    final currentUserId = context.read<AuthService>().currentUser?.uid;

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
      body: !_hasInitialData
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
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
                            child: useSimpleAvatar || avatarSeed == null
                                ? Text(
                                    email[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontFamily: 'Consola',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : RandomAvatar(
                                    avatarSeed,
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _optimisticIsFollowing
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _toggleFollow,
                            child: Text(
                              _optimisticIsFollowing ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: _optimisticIsFollowing
                                    ? Colors.white
                                    : const Color(0xFF1F1F1F),
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
                ],
              ),
            ),
    );
  }
}
