// admin_feedback_screen.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _responseController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _markAsRead(String feedbackId) async {
    try {
      await FirebaseDatabase.instance
          .ref('feedback/$feedbackId')
          .update({'read': true});
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Error marking feedback as read',
          isError: true,
        );
      }
    }
  }

  Future<void> _showResponseDialog(
      Map<String, dynamic> feedback, String feedbackId) async {
    _responseController.text = feedback['response'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Respond to Feedback',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _responseController,
          maxLines: 4,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
          ),
          decoration: InputDecoration(
            hintText: 'Type your response...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontFamily: 'Consola',
            ),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Consola',
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (_responseController.text.trim().isEmpty) {
                CustomSnackbar.show(
                  context,
                  'Please enter a response',
                  isError: true,
                );
                return;
              }

              try {
                await FirebaseDatabase.instance
                    .ref('feedback/$feedbackId')
                    .update({
                  'response': _responseController.text,
                  'status': 'responded',
                  'respondedAt': ServerValue.timestamp,
                });

                // Send notification to user
                await FirebaseDatabase.instance
                    .ref('notifications/${feedback['userId']}')
                    .push()
                    .set({
                  'type': 'feedback_response',
                  'title': 'Feedback Response',
                  'message':
                      'Admin has responded to your feedback: ${_responseController.text}',
                  'timestamp': ServerValue.timestamp,
                  'read': false,
                });

                if (mounted) {
                  Navigator.pop(context);
                  CustomSnackbar.show(
                    context,
                    'Response sent successfully',
                    isError: false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  CustomSnackbar.show(
                    context,
                    'Error sending response',
                    isError: true,
                  );
                }
              }
            },
            child: const Text(
              'Send Response',
              style: TextStyle(
                fontFamily: 'Consola',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFeedback(String feedbackId) async {
    try {
      await FirebaseDatabase.instance.ref('feedback/$feedbackId').remove();
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Feedback deleted successfully',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Error deleting feedback',
          isError: true,
        );
      }
    }
  }

  Widget _buildFeedbackCard(
      Map<String, dynamic> feedback, String feedbackId, bool showUnread) {
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(feedback['timestamp'] as int? ?? 0);
    final isUnread = !(feedback['read'] as bool? ?? false);
    final hasResponse = feedback['response'] != null &&
        feedback['response'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showUnread && isUnread
              ? Colors.blue
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded && isUnread) {
            _markAsRead(feedbackId);
          }
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.feedback_outlined,
            color: showUnread && isUnread ? Colors.blue : Colors.white,
          ),
        ),
        title: Text(
          feedback['userName'] ?? 'Unknown User',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: showUnread && isUnread ? FontWeight.bold : null,
          ),
        ),
        subtitle: Text(
          '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Consola',
          ),
        ),
        trailing: showUnread && isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    feedback['feedback'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                    ),
                  ),
                ),
                if (hasResponse) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Response:',
                          style: TextStyle(
                            color: Colors.blue,
                            fontFamily: 'Consola',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feedback['response'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Consola',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.reply, color: Colors.blue),
                      label: const Text(
                        'Respond',
                        style: TextStyle(
                          color: Colors.blue,
                          fontFamily: 'Consola',
                        ),
                      ),
                      onPressed: () =>
                          _showResponseDialog(feedback, feedbackId),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.red,
                          fontFamily: 'Consola',
                        ),
                      ),
                      onPressed: () => _deleteFeedback(feedbackId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          'User Feedback',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Unread'),
            Tab(text: 'Responded'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Unread Feedback
                StreamBuilder(
                  stream: FirebaseDatabase.instance
                      .ref('feedback')
                      .orderByChild('read')
                      .equalTo(false)
                      .onValue,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (!snapshot.hasData ||
                        snapshot.data?.snapshot.value == null) {
                      return const Center(
                        child: Text(
                          'No unread feedback',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Consola',
                          ),
                        ),
                      );
                    }

                    final feedbackMap =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    final feedbackList = feedbackMap.entries
                        .map((e) => MapEntry(
                            e.key, Map<String, dynamic>.from(e.value as Map)))
                        .toList()
                      ..sort((a, b) => (b.value['timestamp'] as int)
                          .compareTo(a.value['timestamp'] as int));

                    return ListView.builder(
                      itemCount: feedbackList.length,
                      itemBuilder: (context, index) {
                        final feedback = feedbackList[index];
                        return _buildFeedbackCard(
                            feedback.value, feedback.key, true);
                      },
                    );
                  },
                ),

                // Responded Feedback
                StreamBuilder(
                  stream: FirebaseDatabase.instance
                      .ref('feedback')
                      .orderByChild('status')
                      .equalTo('responded')
                      .onValue,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (!snapshot.hasData ||
                        snapshot.data?.snapshot.value == null) {
                      return const Center(
                        child: Text(
                          'No responded feedback',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Consola',
                          ),
                        ),
                      );
                    }

                    final feedbackMap =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    final feedbackList = feedbackMap.entries
                        .map((e) => MapEntry(
                            e.key, Map<String, dynamic>.from(e.value as Map)))
                        .toList()
                      ..sort((a, b) => (b.value['timestamp'] as int)
                          .compareTo(a.value['timestamp'] as int));

                    return ListView.builder(
                      itemCount: feedbackList.length,
                      itemBuilder: (context, index) {
                        final feedback = feedbackList[index];
                        return _buildFeedbackCard(
                            feedback.value, feedback.key, false);
                      },
                    );
                  },
                ),

                // All Feedback
                StreamBuilder(
                  stream: FirebaseDatabase.instance
                      .ref('feedback')
                      .orderByChild('timestamp')
                      .onValue,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (!snapshot.hasData ||
                        snapshot.data?.snapshot.value == null) {
                      return const Center(
                        child: Text(
                          'No feedback yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Consola',
                          ),
                        ),
                      );
                    }

                    final feedbackMap =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    final feedbackList = feedbackMap.entries
                        .map((e) => MapEntry(
                            e.key, Map<String, dynamic>.from(e.value as Map)))
                        .toList()
                      ..sort((a, b) => (b.value['timestamp'] as int)
                          .compareTo(a.value['timestamp'] as int));

                    return ListView.builder(
                      itemCount: feedbackList.length,
                      itemBuilder: (context, index) {
                        final feedback = feedbackList[index];
                        return _buildFeedbackCard(
                            feedback.value, feedback.key, true);
                      },
                    );
                  },
                ),
              ],
            ),
      floatingActionButton: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref('feedback')
            .orderByChild('read')
            .equalTo(false)
            .onValue,
        builder: (context, snapshot) {
          final hasUnread =
              snapshot.hasData && snapshot.data?.snapshot.value != null;

          return FloatingActionButton.extended(
            backgroundColor: hasUnread ? Colors.blue : Colors.grey,
            onPressed: hasUnread
                ? () async {
                    try {
                      final feedbackRef =
                          FirebaseDatabase.instance.ref('feedback');
                      final snapshot = await feedbackRef
                          .orderByChild('read')
                          .equalTo(false)
                          .get();

                      if (snapshot.value != null) {
                        final updates = <String, dynamic>{};
                        (snapshot.value as Map<dynamic, dynamic>)
                            .forEach((key, value) {
                          updates['$key/read'] = true;
                        });
                        await feedbackRef.update(updates);

                        if (mounted) {
                          CustomSnackbar.show(
                            context,
                            'All feedback marked as read',
                            isError: false,
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        CustomSnackbar.show(
                          context,
                          'Error marking feedback as read',
                          isError: true,
                        );
                      }
                    }
                  }
                : null,
            icon: const Icon(Icons.done_all),
            label: const Text(
              'Mark All as Read',
              style: TextStyle(
                fontFamily: 'Consola',
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _responseController.dispose();
    super.dispose();
  }
}
