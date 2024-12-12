import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final DatabaseReference _updateRef =
      FirebaseDatabase.instance.ref('appUpdate');

  Future<void> checkForUpdates(BuildContext context,
      {bool isFromSettings = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final snapshot = await _updateRef.get();
      if (!snapshot.exists || !context.mounted) return;

      final updateInfo = snapshot.value as Map<dynamic, dynamic>;
      final latestVersion = updateInfo['latestVersion'] as String;
      final dontShowKey = 'shown_$latestVersion';

      // Only check for "don't show" if not coming from settings
      if (!isFromSettings && prefs.getBool(dontShowKey) == true) return;

      if (_isUpdateRequired(currentVersion, latestVersion)) {
        if (context.mounted) {
          // Mark as shown immediately when showing from startup
          if (!isFromSettings) {
            await prefs.setBool(dontShowKey, true);
          }
          _showUpdateDialog(context, updateInfo, isFromSettings);
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

  Future<void> requestTestAccess(BuildContext context, String email) async {
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
          const SnackBar(
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
              style: const TextStyle(fontFamily: 'Consola'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpdateDialog(BuildContext context, Map<dynamic, dynamic> updateInfo,
      bool isFromSettings) {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) return;

    FirebaseDatabase.instance
        .ref('updateAccessRequests')
        .orderByChild('email')
        .equalTo(currentUser.email)
        .once()
        .then((snapshot) {
      final hasExistingRequest = snapshot.snapshot.value != null;
      final existingRequestData = hasExistingRequest
          ? (snapshot.snapshot.value as Map).values.first as Map
          : null;

      showModalBottomSheet(
        context: context,
        isDismissible: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _SharedUpdateDialog(
          updateInfo: updateInfo,
          isFromSettings: isFromSettings,
          hasExistingRequest: hasExistingRequest,
          existingRequestData: existingRequestData,
          userEmail: currentUser.email ?? '',
        ),
      );
    });
  }
}

class _SharedUpdateDialog extends StatefulWidget {
  final Map<dynamic, dynamic> updateInfo;
  final bool isFromSettings;
  final bool hasExistingRequest;
  final Map<dynamic, dynamic>? existingRequestData;
  final String userEmail;

  const _SharedUpdateDialog({
    required this.updateInfo,
    required this.isFromSettings,
    required this.hasExistingRequest,
    required this.existingRequestData,
    required this.userEmail,
  });

  @override
  State<_SharedUpdateDialog> createState() => _SharedUpdateDialogState();
}

class _SharedUpdateDialogState extends State<_SharedUpdateDialog> {
  late final TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(
      text: widget.hasExistingRequest
          ? widget.existingRequestData!['email']
          : widget.userEmail,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              feature,
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Consola',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
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
                child: Icon(
                  widget.hasExistingRequest
                      ? Icons.update_disabled
                      : Icons.system_update,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.hasExistingRequest
                    ? 'Update Access Requested'
                    : 'Version ${widget.updateInfo['latestVersion']} Available',
                style: const TextStyle(
                  fontFamily: 'Consola',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.updateInfo['whatsNew'] != null) ...[
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
                      ...(() {
                        final whatsNew = widget.updateInfo['whatsNew'];
                        if (whatsNew is List) {
                          return whatsNew.map((feature) =>
                              _buildFeatureItem(feature.toString()));
                        } else if (whatsNew is Map) {
                          return whatsNew.values.map((feature) =>
                              _buildFeatureItem(feature.toString()));
                        }
                        return <Widget>[];
                      })(),
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
                      widget.updateInfo['updateInstructions'] as String? ??
                          'To update, you need to be added to our testing program. Please submit your email below.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Consola',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.hasExistingRequest) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Request sent with email: ${widget.existingRequestData!['email']}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Consola',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
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
                  ],
                ),
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Consola',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (widget.hasExistingRequest) ...[
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
                            UpdateService().requestTestAccess(
                              context,
                              widget.existingRequestData!['email'],
                            );
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Resend Request',
                            style: TextStyle(
                              fontFamily: 'Consola',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
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
                            UpdateService().requestTestAccess(
                              context,
                              emailController.text,
                            );
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
