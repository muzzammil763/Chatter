import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  Future<void> _followBack(BuildContext context, String userId) async {
    final currentUserId = context.read<AuthService>().currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final currentUserSnapshot =
          await FirebaseDatabase.instance.ref('users/$currentUserId').get();

      final currentUserName =
          (currentUserSnapshot.value as Map?)?['name'] as String?;
      if (currentUserName == null) return;

      await FirebaseDatabase.instance
          .ref('users/$currentUserId/following/$userId')
          .set(true);
      await FirebaseDatabase.instance
          .ref('users/$userId/followers/$currentUserId')
          .set(true);

      await FirebaseDatabase.instance.ref('notifications/$userId').push().set({
        'type': 'follow',
        'senderId': currentUserId,
        'senderName': currentUserName,
        'message': '$currentUserName started following you back',
        'timestamp': ServerValue.timestamp,
        'read': false
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error following back: $e')),
        );
      }
    }
  }

  Future<void> _showNotificationDetails(
      BuildContext context, Map notification) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
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
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['type']?.toString().toUpperCase() ??
                          'NOTIFICATION',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Consola',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification['message'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Consola',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatTimestamp(notification['timestamp'] as int),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Consola',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _readAllNotifications(BuildContext context) async {
    final currentUserId = context.read<AuthService>().currentUser?.uid;
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('notifications/$currentUserId')
          .get();

      if (snapshot.value != null) {
        final notifications = snapshot.value as Map<dynamic, dynamic>;
        final updates = <String, dynamic>{};

        notifications.forEach((key, value) {
          updates['notifications/$currentUserId/$key/read'] = true;
        });

        await FirebaseDatabase.instance.ref().update(updates);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking notifications as read: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications(BuildContext context) async {
    final currentUserId = context.read<AuthService>().currentUser?.uid;
    try {
      await FirebaseDatabase.instance
          .ref('notifications/$currentUserId')
          .remove();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing notifications: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotification(
      BuildContext context, String currentUserId, String notificationId) async {
    try {
      await FirebaseDatabase.instance
          .ref('notifications/$currentUserId/$notificationId')
          .remove();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F1F),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Mark All as Read',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Consola',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Are you sure you want to mark all notifications as read?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Consola',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _readAllNotifications(context);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Mark All as Read',
                            style: TextStyle(
                              color: Color(0xFF1F1F1F),
                              fontFamily: 'Consola',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white10,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Consola',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F1F),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Clear All Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Consola',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Are you sure you want to clear all notifications?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Consola',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _clearAllNotifications(context);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Consola',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white10,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Consola',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref('notifications/$currentUserId')
            .orderByChild('timestamp')
            .onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final notifications = snapshot.data?.snapshot.value as Map? ?? {};

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Consola',
                ),
              ),
            );
          }

          final sortedNotifications = notifications.entries.toList()
            ..sort((a, b) => (b.value['timestamp'] as int)
                .compareTo(a.value['timestamp'] as int));

          return ListView.builder(
            itemCount: sortedNotifications.length,
            itemBuilder: (context, index) {
              final notification = sortedNotifications[index].value as Map;
              final notificationId = sortedNotifications[index].key;
              final isRead = notification['read'] ?? false;

              return Dismissible(
                key: Key(notificationId),
                background: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.red.withOpacity(0.8),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  _deleteNotification(context, currentUserId!, notificationId);
                },
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          notification['message'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Consola',
                          ),
                        ),
                        subtitle: Text(
                          _formatTimestamp(notification['timestamp'] as int),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontFamily: 'Consola',
                          ),
                        ),
                        trailing: notification['type'] == 'follow'
                            ? StreamBuilder<DatabaseEvent>(
                                stream: FirebaseDatabase.instance
                                    .ref(
                                        'users/$currentUserId/following/${notification['senderId']}')
                                    .onValue,
                                builder: (context,
                                    AsyncSnapshot<DatabaseEvent> snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox();
                                  }

                                  final isFollowing =
                                      snapshot.data?.snapshot.value != null;

                                  if (isFollowing) return const SizedBox();

                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _followBack(
                                      context,
                                      notification['senderId'],
                                    ),
                                    child: const Text(
                                      'Follow Back',
                                      style: TextStyle(
                                        color: Color(0xFF1F1F1F),
                                        fontFamily: 'Consola',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : null,
                        onTap: () {
                          _showNotificationDetails(context, notification);
                          if (!isRead) {
                            FirebaseDatabase.instance
                                .ref(
                                    'notifications/$currentUserId/$notificationId')
                                .update({'read': true});
                          }
                        },
                      ),
                    ),
                    if (!isRead)
                      Positioned(
                        top: 16,
                        right: 24,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
