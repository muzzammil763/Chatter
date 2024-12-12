import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
                          'Click the Update Now button below to download the latest version.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Consola',
                      ),
                    ),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not launch $url'),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('Error launching URL: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error launching URL: $e'),
                              ),
                            );
                          }
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Update Now',
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
      ),
    );
  }
}
