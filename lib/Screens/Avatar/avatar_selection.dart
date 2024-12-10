import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/avatar_manager.dart';
import 'package:web_chatter_mobile/Screens/Users/users_screen.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final String userEmail;
  final Function(String) onAvatarSelected;

  const AvatarSelectionScreen({
    super.key,
    required this.userEmail,
    required this.onAvatarSelected,
  });

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  String? selectedAvatarSeed;
  bool useSimpleAvatar = false;
  final List<String> predefinedSeeds = List.generate(
    60,
    (index) => 'avatar-$index',
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _loadSavedAvatar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;

    setState(() {
      selectedAvatarSeed = prefs.getString('avatar_${widget.userEmail}');
      useSimpleAvatar =
          prefs.getBool('useSimpleAvatar_${widget.userEmail}') ?? false;
    });

    if (currentUser != null) {
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(currentUser.uid)
            .get();

        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;
          final avatarSeed = userData['avatarSeed'] as String?;
          final isSimpleAvatar = userData['useSimpleAvatar'] as bool? ?? false;

          await prefs.setString('avatar_${widget.userEmail}', avatarSeed ?? '');
          await prefs.setBool(
              'useSimpleAvatar_${widget.userEmail}', isSimpleAvatar);

          setState(() {
            selectedAvatarSeed = avatarSeed;
            useSimpleAvatar = isSimpleAvatar;
          });

          AvatarManager.updateCache(
              widget.userEmail, avatarSeed, isSimpleAvatar);
        }
      } catch (e) {
        debugPrint('Error loading avatar from Firebase: $e');
      }
    }
  }

  Future<void> _saveAvatarPreference(String? seed, bool isSimple) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_${widget.userEmail}', seed ?? '');
    await prefs.setBool('useSimpleAvatar_${widget.userEmail}', isSimple);

    final currentUser = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(FirebaseAuth.instance.currentUser!.uid);

    await currentUser.update({
      'avatarSeed': seed ?? '',
      'useSimpleAvatar': isSimple,
    });

    AvatarManager.updateCache(widget.userEmail, seed, isSimple);
    widget.onAvatarSelected(seed ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Choose Avatar',
          style: TextStyle(
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const UsersScreen()),
            );
          },
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.shade800,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: useSimpleAvatar
                      ? Text(
                          widget.userEmail[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 55,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Consola',
                            color: Colors.white,
                          ),
                        )
                      : selectedAvatarSeed == null
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : SizedBox(
                              width: 90,
                              height: 90,
                              child: RandomAvatar(
                                selectedAvatarSeed!,
                                height: 90,
                                width: 90,
                              ),
                            ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A), // Dark container
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF1A1A1A),
              activeTrackColor: Colors.green.shade800,
              activeColor: Colors.white,
              trackOutlineColor: const WidgetStatePropertyAll(Colors.white),
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
                setState(() {
                  useSimpleAvatar = value;
                  _controller.reset();
                  _controller.forward();
                });
                _saveAvatarPreference(selectedAvatarSeed, value);
              },
            ),
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
                  color: Colors.white70,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      setState(() {
                        selectedAvatarSeed = seed;
                        _controller.reset();
                        _controller.forward();
                      });
                      _saveAvatarPreference(seed, false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: RandomAvatar(seed),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Expanded(child: Container()),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                onPressed: () {
                  widget.onAvatarSelected(selectedAvatarSeed ?? '');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const UsersScreen()),
                  );
                },
                child: const Text(
                  'C O N T I N U E',
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
    );
  }
}
