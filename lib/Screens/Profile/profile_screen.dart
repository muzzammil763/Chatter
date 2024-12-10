import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';
import 'package:web_chatter_mobile/Screens/Users/user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isNameChanged = false;
  String _originalName = '';
  String? _selectedAvatarSeed;
  bool _useSimpleAvatar = false;
  bool _isLoading = false;
  int _followingCount = 0;
  int _followersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) {
      CustomSnackbar.show(
        context,
        'Name cannot be empty',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthService>().currentUser?.uid;
      if (userId != null) {
        await FirebaseDatabase.instance.ref('users/$userId').update({
          'name': _nameController.text,
        });

        setState(() {
          _originalName = _nameController.text;
          _isNameChanged = false;
        });

        if (mounted) {
          CustomSnackbar.show(
            context,
            'Name updated successfully',
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Error updating name: $e',
          isError: true,
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId != null) {
      final userSnapshot =
          await FirebaseDatabase.instance.ref('users/$userId').get();
      final followingSnapshot =
          await FirebaseDatabase.instance.ref('users/$userId/following').get();
      final followersSnapshot =
          await FirebaseDatabase.instance.ref('users/$userId/followers').get();

      if (userSnapshot.value != null) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _originalName = userData['name'] ?? '';
          _selectedAvatarSeed = userData['avatarSeed'];
          _useSimpleAvatar = userData['useSimpleAvatar'] ?? false;
          _followingCount = (followingSnapshot.value as Map?)?.length ?? 0;
          _followersCount = (followersSnapshot.value as Map?)?.length ?? 0;
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthService>().currentUser?.uid;
      if (userId != null) {
        await FirebaseDatabase.instance.ref('users/$userId').update({
          'name': _nameController.text,
          'useSimpleAvatar': _useSimpleAvatar,
          'avatarSeed': _selectedAvatarSeed ?? '',
        });
        if (mounted) {
          CustomSnackbar.show(
            context,
            'Profile updated successfully',
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          'Error updating profile: $e',
          isError: true,
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAvatarBottomSheet() async {
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
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Avatar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Consola',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFF1A1A1A),
                  activeTrackColor: Colors.green.shade800,
                  activeColor: Colors.white,
                  trackOutlineColor: const WidgetStatePropertyAll(Colors.white),
                  title: const Text(
                    'Use Simple Avatar',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                    ),
                  ),
                  value: _useSimpleAvatar,
                  onChanged: (value) {
                    setState(() => _useSimpleAvatar = value);
                    this.setState(() {});
                  },
                ),
                if (!_useSimpleAvatar)
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: predefinedSeeds.length,
                      itemBuilder: (context, index) {
                        final seed = predefinedSeeds[index];
                        final isSelected = seed == _selectedAvatarSeed;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedAvatarSeed = seed);
                            this.setState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.1),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: RandomAvatar(seed),
                          ),
                        );
                      },
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
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateProfile();
                        CustomSnackbar.show(
                          context,
                          'Avatar updated successfully',
                          isError: false,
                        );
                      },
                      child: const Text(
                        'S A V E',
                        style: TextStyle(
                          color: Color(0xFF1F1F1F),
                          fontSize: 16,
                          fontFamily: 'Consola',
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
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
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
                        GestureDetector(
                          onTap: _showAvatarBottomSheet,
                          child: Stack(
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
                                  child: _useSimpleAvatar ||
                                          _selectedAvatarSeed == null
                                      ? Text(
                                          _nameController.text.isNotEmpty
                                              ? _nameController.text[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 40,
                                            fontFamily: 'Consola',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : RandomAvatar(
                                          _selectedAvatarSeed!,
                                          height: 100,
                                          width: 100,
                                        ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2A2A2A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      textSelectionTheme:
                                          const TextSelectionThemeData(
                                        cursorColor: Colors.white,
                                        selectionColor: Colors.white24,
                                        selectionHandleColor: Colors.white,
                                      ),
                                    ),
                                    child: TextField(
                                      textCapitalization:
                                          TextCapitalization.words,
                                      keyboardType: TextInputType.name,
                                      cursorOpacityAnimates: true,
                                      cursorColor: Colors.white,
                                      controller: _nameController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Consola',
                                      ),
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        hintText: 'Your Name',
                                        hintStyle: TextStyle(
                                          color: Colors.grey,
                                          fontFamily: 'Consola',
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _isNameChanged =
                                              value != _originalName;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _isNameChanged
                                      ? Colors.green.shade800
                                      : const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed:
                                      _isNameChanged ? _updateName : null,
                                  icon: Icon(
                                    Icons.check,
                                    color: _isNameChanged
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add this widget after the name TextField container in ProfileScreen
                        Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn('Following', _followingCount,
                                  () {
                                _showFollowingList();
                              }),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              _buildStatColumn('Followers', _followersCount,
                                  () {
                                _showFollowersList();
                              }),
                            ],
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

  Widget _buildStatColumn(String label, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Consola',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontFamily: 'Consola',
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowingList() {
    _showUsersList(true);
  }

  void _showFollowersList() {
    _showUsersList(false);
  }

  void _showUsersList(bool isFollowing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isFollowing ? 'Following' : 'Followers',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Consola',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseDatabase.instance
                      .ref(
                          'users/${context.read<AuthService>().currentUser?.uid}/${isFollowing ? 'following' : 'followers'}')
                      .onValue,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final data = snapshot.data?.snapshot.value as Map?;
                    if (data == null || data.isEmpty) {
                      return Center(
                        child: Text(
                          'No ${isFollowing ? 'following' : 'followers'} yet',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Consola',
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final userId = data.keys.elementAt(index);
                        return FutureBuilder(
                          future: FirebaseDatabase.instance
                              .ref('users/$userId')
                              .get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return const SizedBox();
                            }

                            final userData = userSnapshot.data?.value as Map?;
                            if (userData == null) return const SizedBox();

                            return ListTile(
                              leading: _buildUserAvatar(userData),
                              title: Text(
                                userData['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Consola',
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(
                                      user: Map<String, dynamic>.from(userData),
                                      userId: userId,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(Map userData) {
    final useSimpleAvatar = userData['useSimpleAvatar'] ?? false;
    final avatarSeed = userData['avatarSeed'] as String?;
    final email = userData['email'] as String;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: useSimpleAvatar || avatarSeed == null || avatarSeed.isEmpty
            ? Text(
                email[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
