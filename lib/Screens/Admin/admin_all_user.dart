import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseDatabase.instance.ref('users').get();
      if (snapshot.value != null) {
        final usersMap = snapshot.value as Map<dynamic, dynamic>;
        _users = usersMap.entries
            .map((e) => {
                  'id': e.key,
                  ...Map<String, dynamic>.from(e.value as Map),
                })
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'All Users',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => _showEditUserBottomSheet(context, user),
                    contentPadding: const EdgeInsets.all(16),
                    leading: _buildUserAvatar(user),
                    title: Text(
                      user['name'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'Consola',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      user['email'] ?? '',
                      style: TextStyle(
                        fontFamily: 'Consola',
                        color: Colors.grey[400],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> user) {
    final useSimpleAvatar = user['useSimpleAvatar'] ?? false;
    final avatarSeed = user['avatarSeed'] as String?;
    final email = user['email'] as String;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: useSimpleAvatar || avatarSeed == null || avatarSeed.isEmpty
            ? Text(
                email[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'Consola',
                  fontWeight: FontWeight.bold,
                ),
              )
            : RandomAvatar(
                avatarSeed,
                height: 40,
                width: 40,
              ),
      ),
    );
  }

  Future<void> _showEditUserBottomSheet(
      BuildContext context, Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']);
    bool isDisabled = user['disabled'] ?? false;
    bool isAdmin = user['isAdmin'] ?? false;
    bool useSimpleAvatar = user['useSimpleAvatar'] ?? false;
    String? selectedAvatarSeed = user['avatarSeed'];
    final List<String> predefinedSeeds =
        List.generate(60, (index) => 'avatar-$index');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: StatefulBuilder(
          builder: (context, setState) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: Navigator.of(context).pop,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Edit User',
                            style: TextStyle(
                              fontFamily: 'Consola',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          const IconButton(
                            onPressed: null,
                            icon: Icon(
                              Icons.arrow_back,
                              color: Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          cursorColor: Colors.white,
                          controller: nameController,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Consola',
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(20),
                            border: InputBorder.none,
                            hintText: 'Full Name',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontFamily: 'Consola',
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SwitchListTile(
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFF1A1A1A),
                        activeTrackColor: Colors.green.shade800,
                        activeColor: Colors.white,
                        trackOutlineColor:
                            const WidgetStatePropertyAll(Colors.white),
                        hoverColor: Colors.transparent,
                        title: const Text(
                          'Use Simple Avatar',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        value: useSimpleAvatar,
                        onChanged: (value) {
                          setState(() => useSimpleAvatar = value);
                        },
                      ),
                      SwitchListTile(
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFF1A1A1A),
                        activeTrackColor: Colors.green.shade800,
                        activeColor: Colors.white,
                        trackOutlineColor:
                            const WidgetStatePropertyAll(Colors.white),
                        hoverColor: Colors.transparent,
                        title: const Text(
                          'Account Disabled',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        value: isDisabled,
                        onChanged: (value) {
                          setState(() => isDisabled = value);
                        },
                      ),
                      SwitchListTile(
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFF1A1A1A),
                        activeTrackColor: Colors.green.shade800,
                        activeColor: Colors.white,
                        trackOutlineColor:
                            const WidgetStatePropertyAll(Colors.white),
                        hoverColor: Colors.transparent,
                        title: const Text(
                          'Admin Access',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        value: isAdmin,
                        onChanged: (value) {
                          setState(() => isAdmin = value);
                        },
                      ),
                      if (!useSimpleAvatar) ...[
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Select an avatar',
                            style: TextStyle(
                              fontFamily: 'Consola',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: predefinedSeeds.length,
                          itemBuilder: (context, index) {
                            final seed = predefinedSeeds[index];
                            final isSelected = seed == selectedAvatarSeed;
                            return GestureDetector(
                              onTap: () {
                                setState(() => selectedAvatarSeed = seed);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.1),
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: RandomAvatar(seed),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
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
                      onPressed: () async {
                        try {
                          await FirebaseDatabase.instance
                              .ref('users/${user['id']}')
                              .update({
                            'name': nameController.text,
                            'disabled': isDisabled,
                            'isAdmin': isAdmin,
                            'useSimpleAvatar': useSimpleAvatar,
                            'avatarSeed': selectedAvatarSeed ?? '',
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadUsers();
                            CustomSnackbar.show(
                              context,
                              'User updated successfully',
                              isError: false,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            CustomSnackbar.show(
                              context,
                              'Error updating user: $e',
                              isError: true,
                            );
                          }
                        }
                      },
                      child: const Text(
                        'S A V E',
                        style: TextStyle(
                          fontFamily: 'Consola',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F1F1F),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
