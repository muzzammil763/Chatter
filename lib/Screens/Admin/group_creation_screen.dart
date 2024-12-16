import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
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
  String? selectedGroupAvatarSeed;
  bool useSimpleGroupAvatar = false;

  final List<String> predefinedSeeds = List.generate(
    60,
    (index) => 'group-avatar-$index',
  );

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
        if (kDebugMode) {
          print('Raw users data: ${snapshot.value}');
        }

        // Handle potential null or unexpected data structure
        if (snapshot.value is Map) {
          setState(() {
            users = (snapshot.value as Map).map((key, value) => MapEntry(
                key.toString(),
                value is Map ? Map<String, dynamic>.from(value) : {}));
          });
        } else {
          if (kDebugMode) {
            print('Users data is not a Map');
          }
          users = {};
        }
      } else {
        if (kDebugMode) {
          print('No users data exists');
        }
        users = {};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading users: $e');
      }
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
      'avatarSeed': selectedGroupAvatarSeed ?? '',
      'useSimpleAvatar': useSimpleGroupAvatar,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF121212),
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
            child: GestureDetector(
              onTap: () => _showAvatarSelectionDialog(),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: useSimpleGroupAvatar
                      ? Text(
                          _groupNameController.text.isNotEmpty
                              ? _groupNameController.text[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : (selectedGroupAvatarSeed != null
                          ? RandomAvatar(
                              selectedGroupAvatarSeed!,
                              height: 80,
                              width: 80,
                            )
                          : const Icon(Icons.add_a_photo, color: Colors.white)),
                ),
              ),
            ),
          ),
          // Group Name TextField
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _groupNameController,
              onChanged: (value) {
                setState(() {}); // Trigger rebuild for avatar
              },
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

  void _showAvatarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'Choose Group Avatar',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text(
                'Use Simple Avatar',
                style: TextStyle(color: Colors.white),
              ),
              value: useSimpleGroupAvatar,
              onChanged: (bool value) {
                setState(() {
                  useSimpleGroupAvatar = value;
                  selectedGroupAvatarSeed = null;
                });
              },
            ),
            if (!useSimpleGroupAvatar)
              SizedBox(
                width: 300,
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: predefinedSeeds.length,
                  itemBuilder: (context, index) {
                    final seed = predefinedSeeds[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedGroupAvatarSeed = seed;
                        });
                        Navigator.pop(context);
                      },
                      child: RandomAvatar(seed),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
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
