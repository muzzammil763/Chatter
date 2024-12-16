import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Screens/Admin/admin_chat_viewer.dart';

class AdminChatMonitoring extends StatefulWidget {
  const AdminChatMonitoring({super.key});

  @override
  State<AdminChatMonitoring> createState() => _AdminChatMonitoringState();
}

class _AdminChatMonitoringState extends State<AdminChatMonitoring> {
  String? selectedUser1;
  String? selectedUser2;
  Map<String, dynamic> users = {};

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'Monitor Chat',
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
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Select two users to view their conversation',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Consola',
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users.entries.elementAt(index);
                final isSelected =
                    user.key == selectedUser1 || user.key == selectedUser2;
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
                        if (user.key == selectedUser1) {
                          selectedUser1 = null;
                        } else if (user.key == selectedUser2) {
                          selectedUser2 = null;
                        } else {
                          selectedUser1 ??= user.key;
                          selectedUser2 ??=
                              selectedUser1 == user.key ? null : user.key;
                        }
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
                    subtitle: Text(
                      user.value['email'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontFamily: 'Consola',
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 16,
                              color: Color(0xFF121212),
                            ),
                          )
                        : null,
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
                onPressed: selectedUser1 != null && selectedUser2 != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminChatViewer(
                              user1: MapEntry(
                                selectedUser1!,
                                users[selectedUser1]!,
                              ),
                              user2: MapEntry(
                                selectedUser2!,
                                users[selectedUser2]!,
                              ),
                            ),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  'V I E W  C H A T',
                  style: TextStyle(
                    fontFamily: 'Consola',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: selectedUser1 != null && selectedUser2 != null
                        ? const Color(0xFF121212)
                        : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
