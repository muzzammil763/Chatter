import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  final DatabaseReference _updateRef =
      FirebaseDatabase.instance.ref('appUpdate');

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Check if user has dismissed this version's update dialog
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final snapshot = await _updateRef.get();
      if (!snapshot.exists || !context.mounted) return;

      final updateInfo = snapshot.value as Map<dynamic, dynamic>;
      final latestVersion = updateInfo['latestVersion'] as String;
      final dontShowKey = 'dontShow_$latestVersion';

      // If user chose not to show this version again, respect that choice
      if (prefs.getBool(dontShowKey) == true) return;

      if (_isUpdateRequired(currentVersion, latestVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, updateInfo);
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  bool _isUpdateRequired(String currentVersion, String latestVersion) {
    List<int> current = currentVersion.split('.').map(int.parse).toList();
    List<int> latest = latestVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (current[i] < latest[i]) return true;
      if (current[i] > latest[i]) return false;
    }
    return false;
  }

  Future<void> _requestTestAccess(BuildContext context, String email) async {
    try {
      final ref = FirebaseDatabase.instance.ref('updateAccessRequests').push();
      await ref.set({
        'email': email,
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
        'currentVersion': (await PackageInfo.fromPlatform()).version,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Access request sent successfully. An admin will review your request.',
              style: TextStyle(fontFamily: 'Consola'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error sending request: $e',
              style: TextStyle(fontFamily: 'Consola'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpdateDialog(
      BuildContext context, Map<dynamic, dynamic> updateInfo) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          bool dontShowAgain = false;
          final emailController = TextEditingController();

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
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
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update,
                      color: Colors.blue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Version ${updateInfo['latestVersion']} Available',
                    style: const TextStyle(
                      fontFamily: 'Consola',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (updateInfo['whatsNew'] != null) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "What's New",
                            style: TextStyle(
                              fontFamily: 'Consola',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(updateInfo['whatsNew'] as Map<dynamic, dynamic>)
                              .values
                              .map((feature) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "• ",
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontFamily: 'Consola',
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            feature.toString(),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontFamily: 'Consola',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to Update:',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          updateInfo['updateInstructions'] as String? ??
                              'To update, you need to be added to our testing program. Please submit your email below.',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Consola',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Consola',
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontFamily: 'Consola',
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1F1F1F),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: dontShowAgain,
                    onChanged: (value) {
                      setState(() => dontShowAgain = value ?? false);
                    },
                    title: const Text(
                      "Don't show this version again",
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Consola',
                      ),
                    ),
                    checkColor: const Color(0xFF1F1F1F),
                    activeColor: Colors.white,
                    side: const BorderSide(color: Colors.grey),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.grey),
                              ),
                            ),
                            onPressed: () async {
                              if (dontShowAgain) {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(
                                  'dontShow_${updateInfo['latestVersion']}',
                                  true,
                                );
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text(
                              'Later',
                              style: TextStyle(
                                color: Colors.grey,
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
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (emailController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter your email',
                                      style: TextStyle(fontFamily: 'Consola'),
                                    ),
                                  ),
                                );
                                return;
                              }
                              _requestTestAccess(context, emailController.text);
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Request Access',
                              style: TextStyle(
                                fontFamily: 'Consola',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
