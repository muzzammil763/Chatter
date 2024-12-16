import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Core/Services/Notification/notification_service.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final Map<String, bool> _selectedUsers = {};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  Map<String, dynamic> users = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final snapshot = await FirebaseDatabase.instance.ref('users').get();
    if (snapshot.exists) {
      setState(() {
        users = Map<String, dynamic>.from(snapshot.value as Map);
      });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      for (var user in users.keys) {
        _selectedUsers[user] = _selectAll;
      }
    });
  }

  Future<void> _sendNotifications() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      CustomSnackbar.show(
        context,
        'Please enter both title and body for the notification',
        isError: true,
      );
      return;
    }

    final selectedUsers = _selectedUsers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedUsers.isEmpty) {
      CustomSnackbar.show(
        context,
        'Please select at least one user',
        isError: true,
      );
      return;
    }

    try {
      for (var userId in selectedUsers) {
        final userToken = users[userId]['fcmToken'];
        if (userToken != null) {
          await NotificationService().sendNotificationToToken(
            token: userToken,
            title: _titleController.text,
            body: _bodyController.text,
            data: {
              'type': 'admin_notification',
              'title': _titleController.text,
              'body': _bodyController.text,
              'imageUrl': _imageUrlController.text,
            },
          );
        }
      }

      CustomSnackbar.show(context, 'Notifications sent successfully!');
      Navigator.pop(context);
    } catch (e) {
      CustomSnackbar.show(
        context,
        'Error sending notifications: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Send Notifications',
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(
                  controller: _titleController,
                  hint: 'Notification Title',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bodyController,
                  hint: 'Notification Body',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _imageUrlController,
                  hint: 'Image URL (Optional)',
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFF1A1A1A),
                  activeTrackColor: Colors.green.shade800,
                  activeColor: Colors.white,
                  trackOutlineColor: const WidgetStatePropertyAll(Colors.white),
                  hoverColor: Colors.transparent,
                  title: const Text(
                    'Select All Users',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  value: _selectAll,
                  onChanged: (value) => _toggleSelectAll(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users.entries.elementAt(index);
                final isSelected = _selectedUsers[user.key] ?? false;
                final useSimpleAvatar = user.value['useSimpleAvatar'] ?? false;
                final avatarSeed = user.value['avatarSeed'] as String?;
                final email = user.value['email'] as String;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    onTap: () {
                      setState(() {
                        _selectedUsers[user.key] =
                            !((_selectedUsers[user.key] ?? false));
                      });
                    },
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: useSimpleAvatar ||
                                avatarSeed == null ||
                                avatarSeed.isEmpty
                            ? Text(
                                email[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Consola',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : RandomAvatar(
                                avatarSeed,
                                height: 48,
                                width: 48,
                              ),
                      ),
                    ),
                    title: Text(
                      user.value['name'] ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Consola',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.value['email'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontFamily: 'Consola',
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'FCM: ${user.value['fcmToken'] ?? 'Not available'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontFamily: 'Consola',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                        color: isSelected ? Colors.white : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Color(0xFF121212),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _sendNotifications,
                child: const Text(
                  'S E N D  N O T I F I C A T I O N S',
                  style: TextStyle(
                    fontFamily: 'Consola',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF121212),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Consola',
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Consola',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
