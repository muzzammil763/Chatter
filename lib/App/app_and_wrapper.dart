import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Services/Chat/chat_service.dart';
import 'package:web_chatter_mobile/Core/Services/Update/update_service.dart';
import 'package:web_chatter_mobile/Screens/Auth/signup_screen.dart';
import 'package:web_chatter_mobile/Screens/Users/users_screen.dart';

class ChatterApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ChatterApp({super.key, required this.navigatorKey});

  @override
  State<ChatterApp> createState() => _ChatterAppState();
}

class _ChatterAppState extends State<ChatterApp> with WidgetsBindingObserver {
  Future<void> _checkForUpdates() async {
    await UpdateService().checkForUpdates(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ChatService().onAppResume();
        break;
      case AppLifecycleState.paused:
        ChatService().onAppPause();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: AnnotatedRegion(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF121212),
        ),
        child: MaterialApp(
          navigatorKey: widget.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primaryColor: Colors.black),
          home: const AuthWrapper(),
        ),
      ),
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
