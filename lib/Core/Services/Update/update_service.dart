import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final DatabaseReference _updateRef =
      FirebaseDatabase.instance.ref('appUpdate');

  Future<void> checkForUpdates(BuildContext context,
      {bool isFromSettings = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final snapshot = await _updateRef.get();
      if (!snapshot.exists || !context.mounted) return;

      final updateInfo = snapshot.value as Map<dynamic, dynamic>;
      final latestVersion = updateInfo['latestVersion'] as String;

      if (_isUpdateRequired(currentVersion, latestVersion)) {
        if (context.mounted) {
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

  void _showUpdateDialog(BuildContext context, Map<dynamic, dynamic> updateInfo,
      bool isFromSettings) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SharedUpdateDialog(
        updateInfo: updateInfo,
        isFromSettings: isFromSettings,
        userEmail: '',
      ),
    );
  }
}

class _SharedUpdateDialog extends StatefulWidget {
  final Map<dynamic, dynamic> updateInfo;
  final bool isFromSettings;
  final String userEmail;

  const _SharedUpdateDialog({
    required this.updateInfo,
    required this.isFromSettings,
    required this.userEmail,
  });

  @override
  State<_SharedUpdateDialog> createState() => _SharedUpdateDialogState();
}

class _SharedUpdateDialogState extends State<_SharedUpdateDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
              const Icon(
                Icons.system_update_alt,
                color: Colors.blue,
                size: 50,
              ),
              const SizedBox(height: 24),
              Text(
                'Version ${widget.updateInfo['latestVersion']} Available',
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
                          fontSize: 18,
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
              const SizedBox(height: 16),
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
                      'Update Process Guide',
                      style: TextStyle(
                        fontFamily: 'Consola',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildUpdateStep(
                      '1. Start Update',
                      'Tap "Update Now" button to open Firebase App Distribution page',
                    ),
                    _buildUpdateStep(
                      '2. Sign Up',
                      'Enter your email to receive the app test invitation',
                    ),
                    _buildUpdateStep(
                      '3. Wait for Confirmation',
                      'Brief loading screen will appear with a message about email invitation',
                    ),
                    _buildUpdateStep(
                      '4. Check Email',
                      'Click "Get Started" in the received email invitation',
                    ),
                    _buildUpdateStep(
                      '5. Download App',
                      'Find and click the download button for the latest APK',
                    ),
                    _buildUpdateStep(
                      '6. Install',
                      'Open APK, install new version, and enjoy updates!',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '🔔 Pro Tip: Allow installation from unknown sources in device settings',
                      style: TextStyle(
                        color: Colors.blue[200],
                        fontFamily: 'Consola',
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          color: Colors.grey,
                        )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final url = widget.updateInfo['url'] as String;
                          try {
                            final Uri parsedUrl = Uri.parse(url);
                            if (await canLaunchUrl(parsedUrl)) {
                              await launchUrl(
                                parsedUrl,
                                mode: LaunchMode.platformDefault,
                              );
                            } else {
                              if (await canLaunchUrl(parsedUrl)) {
                                await launch(url);
                              } else {
                                CustomSnackbar.show(
                                    context, 'Could not launch $url');
                              }
                            }
                          } catch (e) {
                            // debugPrint('Error launching URL: $e');
                            CustomSnackbar.show(
                                context, 'Error launching URL: $e');
                          }
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Update Now',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      ),
    );
  }

  Widget _buildUpdateStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: Colors.blue[300],
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Consola',
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontFamily: 'Consola',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
