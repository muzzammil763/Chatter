import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateInfo {
  final String latestVersion;
  final String minSupportedVersion;
  final int latestVersionCode;
  final String url;

  UpdateInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.latestVersionCode,
    required this.url,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latestVersion'],
      minSupportedVersion: json['minSupportedVersion'],
      latestVersionCode: json['latestVersionCode'],
      url: json['url'],
    );
  }
}

class UpdateService {
  double? downloadProgress;
  static const String updateUrl =
      'https://raw.githubusercontent.com/muzzammil763/Chatter/master/update-config.json';

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!context.mounted) return;
      final currentVersion = packageInfo.version;
      if (kDebugMode) {
        print('Current Version: $currentVersion');
      }

      final response = await http.get(Uri.parse(updateUrl));
      if (!context.mounted) return;

      if (kDebugMode) {
        print('Response Status: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final updateInfo = UpdateInfo.fromJson(json.decode(response.body));
        if (kDebugMode) print('Latest Version: ${updateInfo.latestVersion}');

        // Compare with latest version instead of minimum supported version
        if (_isUpdateRequired(currentVersion, updateInfo.latestVersion)) {
          if (kDebugMode) print('Update Required');
          if (context.mounted) {
            _showUpdateDialog(context, updateInfo.url);
          }
        } else {
          if (kDebugMode) print('No Update Required');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error checking for updates: $e');
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

  void _showUpdateDialog(BuildContext context, String downloadUrl) {
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: PopScope(
            canPop: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
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
                      color: Colors.grey[300],
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
                  const Text(
                    'Update Available',
                    style: TextStyle(
                      fontFamily: 'Consola',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'A new version is available. Please update to continue using the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Consola',
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            _downloadAndInstallUpdate(ctx, downloadUrl),
                        child: const Text(
                          'Update Now',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            color: Colors.white,
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
        );
      },
    );
  }

  void _showPermissionDialog(
      BuildContext context, String title, String message) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Consola',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Consola',
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Consola',
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await openAppSettings();
                          },
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(
                              fontFamily: 'Consola',
                              color: Colors.white,
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
    );
  }

  Future<void> _downloadAndInstallUpdate(
      BuildContext context, String downloadUrl) async {
    BuildContext? progressContext;
    try {
      if (kDebugMode) {
        print('Starting download process...');
        print('Download URL: $downloadUrl');
      }

      if (Platform.isAndroid) {
        if (kDebugMode) {
          print('Requesting permissions...');
        }

        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final androidVersion = androidInfo.version.sdkInt;

        if (kDebugMode) {
          print('Android SDK Version: $androidVersion');
        }

        if (androidVersion >= 30) {
          final installStatus =
              await Permission.requestInstallPackages.request();
          if (!installStatus.isGranted) {
            if (context.mounted) {
              _showPermissionDialog(
                context,
                'Installation Permission',
                'Please allow app installation from this source to update the app.',
              );
            }
            return;
          }
        } else {
          final storageStatus = await Permission.storage.request();
          final installStatus =
              await Permission.requestInstallPackages.request();

          if (!storageStatus.isGranted || !installStatus.isGranted) {
            if (context.mounted) {
              _showPermissionDialog(
                context,
                'Permissions Required',
                'Storage and installation permissions are required to update the app.',
              );
            }
            return;
          }
        }
      }

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (ctx) {
          progressContext = ctx;
          return StatefulBuilder(
            builder: (context, setProgressState) {
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: PopScope(
                  canPop: false,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
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
                            Icons.download,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Downloading Update',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            '${(downloadProgress ?? 0).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontFamily: 'Consola',
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: LinearProgressIndicator(
                            value: (downloadProgress ?? 0) / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${dir.path}/app-update.apk';
      if (kDebugMode) {
        print('Download path: $filePath');
      }

      final dio = Dio();
      dio.options.followRedirects = true;
      dio.options.validateStatus = (status) => status! < 500;

      final response = await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100);
            if (progressContext != null && progressContext!.mounted) {
              (progressContext! as Element).markNeedsBuild();
              downloadProgress = progress;
            }
            if (kDebugMode) {
              print('Download Progress: ${progress.toStringAsFixed(0)}%');
            }
          }
        },
      );

      if (kDebugMode) {
        print('Download response status: ${response.statusCode}');
      }

      if (context.mounted) {
        Navigator.pop(context);
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found');
      }

      if (kDebugMode) {
        print('File size: ${await file.length()} bytes');
      }

      if (Platform.isAndroid) {
        if (kDebugMode) {
          print('Installing APK...');
        }
        final result = await OpenFile.open(filePath);
        if (kDebugMode) {
          print('Install result: ${result.message}');
        }

        if (result.type != ResultType.done) {
          throw Exception('Failed to install: ${result.message}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error downloading update: $e');
        print('Stack trace: $stackTrace');
      }

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          useRootNavigator: true,
          builder: (ctx) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Download Error',
                    style: TextStyle(
                      fontFamily: 'Consola',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Consola',
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontFamily: 'Consola',
                            color: Colors.white,
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
        );
      }
    }
  }
}
