import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Services/Initialization/initialization_service.dart';
import 'package:web_chatter_mobile/Core/Services/Notification/notification_service.dart';
import 'package:web_chatter_mobile/Core/Services/Update/update_service.dart';
import 'package:web_chatter_mobile/Screens/Auth/signup_screen.dart';
import 'package:web_chatter_mobile/Screens/Users/users_screen.dart';
import 'package:web_chatter_mobile/firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  await InitializationService.initialize();

  await FirebaseMessaging.instance.requestPermission();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService().initialize(navigatorKey);

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primaryColor: Colors.black),
        home: Builder(
          builder: (context) => ChatterApp(navigatorKey: navigatorKey),
        ),
      ),
    ),
  );
}

class ChatterApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ChatterApp({super.key, required this.navigatorKey});

  @override
  State<ChatterApp> createState() => _ChatterAppState();
}

class _ChatterAppState extends State<ChatterApp> with WidgetsBindingObserver {
  void checkForUpdates(BuildContext context) {
    UpdateService().checkForUpdates(context, isFromSettings: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseMessagingService.initialize();
      checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF121212),
      ),
      child: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: context.watch<AuthService>().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (snapshot.hasData) {
          return const UsersScreen();
        }

        return const SignUpScreen();
      },
    );
  }
}
