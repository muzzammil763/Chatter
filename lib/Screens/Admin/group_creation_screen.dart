import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

class AdminGroupCreationScreen extends StatefulWidget {
  const AdminGroupCreationScreen({super.key});

  @override
  State<AdminGroupCreationScreen> createState() =>
      _AdminGroupCreationScreenState();
}

class _AdminGroupCreationScreenState extends State<AdminGroupCreationScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  Set<String> selectedUsers = {};
  Map<String, dynamic> users = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('users').get();
      if (snapshot.exists) {
        // Print the raw value to understand its structure
        print('Raw users data: ${snapshot.value}');

        // Handle potential null or unexpected data structure
        if (snapshot.value is Map) {
          setState(() {
            users = (snapshot.value as Map).map((key, value) => MapEntry(
                key.toString(),
                value is Map ? Map<String, dynamic>.from(value) : {}));
          });
        } else {
          print('Users data is not a Map');
          users = {};
        }
      } else {
        print('No users data exists');
        users = {};
      }
    } catch (e) {
      print('Error loading users: $e');
      users = {};
    }
  }

  void _createGroup() {
    if (_groupNameController.text.isEmpty || selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter group name and select users')),
      );
      return;
    }

    final groupRef = FirebaseDatabase.instance.ref('groups').push();
    groupRef.set({
      'name': _groupNameController.text,
      'members': {for (var userId in selectedUsers) userId: true},
      'createdAt': ServerValue.timestamp,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Create Group',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Enter Group Name',
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users.entries.elementAt(index);
                final isSelected = selectedUsers.contains(user.key);

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
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedUsers.remove(user.key);
                        } else {
                          selectedUsers.add(user.key);
                        }
                      });
                    },
                    leading: _buildUserAvatar(user.value),
                    title: Text(
                      user.value['name'] ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Consola',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _createGroup,
              child: const Text(
                'Create Group',
                style: TextStyle(
                  color: Color(0xFF121212),
                  fontFamily: 'Consola',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(dynamic userData) {
    if (userData is! Map) {
      return Container(
        width: 48,
        height: 48,
        color: Colors.grey,
      );
    }

    final useSimpleAvatar = userData['useSimpleAvatar'] ?? false;
    final avatarSeed = userData['avatarSeed'] as String?;
    final email = userData['email'] as String? ?? 'N/A';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: useSimpleAvatar || avatarSeed == null || avatarSeed.isEmpty
            ? Text(
                email.isNotEmpty ? email[0].toUpperCase() : '?',
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
    );
  }
}
