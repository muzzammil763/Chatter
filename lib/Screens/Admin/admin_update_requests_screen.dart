// admin_update_requests_screen.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminUpdateRequestsScreen extends StatelessWidget {
  const AdminUpdateRequestsScreen({super.key});

  Future<void> _handleRequest(
      String requestId, String email, bool approved) async {
    try {
      if (approved) {
        // Add to Firebase App Distribution testers
        // You'll need to implement this using your preferred method
        // (Firebase Admin SDK, Cloud Functions, or your backend)

        // Update request status
        await FirebaseDatabase.instance
            .ref('updateAccessRequests/$requestId')
            .update({
          'status': 'approved',
          'approvedAt': ServerValue.timestamp,
        });

        // Send notification to user
        await FirebaseDatabase.instance
            .ref('notifications/$requestId')
            .push()
            .set({
          'type': 'update_access',
          'title': 'Update Access Approved',
          'message':
              'Your request for app update access has been approved. Check your email for instructions.',
          'timestamp': ServerValue.timestamp,
          'read': false,
        });
      } else {
        // Update request status
        await FirebaseDatabase.instance
            .ref('updateAccessRequests/$requestId')
            .update({
          'status': 'rejected',
          'rejectedAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      debugPrint('Error handling request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Update Access Requests',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref('updateAccessRequests')
            .orderByChild('timestamp')
            .onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests =
              snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
          if (requests == null || requests.isEmpty) {
            return const Center(
              child: Text(
                'No pending requests',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Consola',
                ),
              ),
            );
          }

          final requestList = requests.entries.toList()
            ..sort((a, b) => (b.value['timestamp'] as int)
                .compareTo(a.value['timestamp'] as int));

          return ListView.builder(
            itemCount: requestList.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final request = requestList[index];
              final data = request.value as Map<dynamic, dynamic>;
              final status = data['status'] as String;
              final timestamp =
                  DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.3),
                  ),
                ),
                child: ExpansionTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                    ),
                  ),
                  title: Text(
                    data['email'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Consola',
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontFamily: 'Consola',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Current Version',
                              data['currentVersion'] as String),
                          const SizedBox(height: 8),
                          if (status == 'pending')
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _handleRequest(request.key,
                                        data['email'] as String, false),
                                    child: const Text(
                                      'Reject',
                                      style: TextStyle(
                                        fontFamily: 'Consola',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _handleRequest(request.key,
                                        data['email'] as String, true),
                                    child: const Text(
                                      'Approve',
                                      style: TextStyle(
                                        fontFamily: 'Consola',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (status != 'pending')
                            Text(
                              status == 'approved'
                                  ? 'Request approved'
                                  : 'Request rejected',
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontFamily: 'Consola',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_outlined;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
