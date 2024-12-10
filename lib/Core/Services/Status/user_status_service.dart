import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:web_chatter_mobile/Core/Services/Storage/shared_prefs_service.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/avatar_manager.dart';
import 'package:web_chatter_mobile/Screens/Auth/login_screen.dart';

class UserStatusService {
  static void startMonitoring(BuildContext context, String userId) {
    FirebaseDatabase.instance
        .ref('users/$userId/disabled')
        .onValue
        .listen((event) {
      final isDisabled = event.snapshot.value as bool? ?? false;

      if (isDisabled && context.mounted) {
        _showDisabledBottomSheet(context, userId);
      }
    });
  }

  static Future<void> _showDisabledBottomSheet(
      BuildContext context, String userId) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StreamBuilder(
          stream:
              FirebaseDatabase.instance.ref('users/$userId/disabled').onValue,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final isDisabled =
                  (snapshot.data as DatabaseEvent).snapshot.value as bool? ??
                      false;
              if (!isDisabled) {
                Navigator.of(ctx).pop();
              }
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: PopScope(
                canPop: false,
                child: Container(
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
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Access Revoked',
                        style: TextStyle(
                          fontFamily: 'Consola',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Your access to this application has been revoked. Please contact support for more information.',
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
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              await SharedPrefsService.clearAll();
                              await AvatarManager.clearCache();
                              if (ctx.mounted) {
                                Navigator.of(ctx).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text(
                              'Sign Out',
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
      },
    );
  }
}
