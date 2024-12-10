import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_chatter_mobile/App/app_and_wrapper.dart';
import 'package:web_chatter_mobile/Core/Services/Initialization/initialization_service.dart';
import 'package:web_chatter_mobile/Core/Services/Notification/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await InitializationService.initialize();
  await FirebaseMessagingService.initialize();
  final notificationService = NotificationService();
  await notificationService.initialize(navigatorKey);
  runApp(
    ChatterApp(navigatorKey: navigatorKey),
  );
}
