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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await InitializationService.initialize();

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
  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    await UpdateService().checkForUpdates(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      FirebaseMessagingService.initialize();
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
            body: Center(child: CircularProgressIndicator()),
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
