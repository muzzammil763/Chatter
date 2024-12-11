import 'package:flutter/material.dart';
import 'package:web_chatter_mobile/Screens/Admin/admin_all_user.dart';
import 'package:web_chatter_mobile/Screens/Admin/admin_analytics.dart';
import 'package:web_chatter_mobile/Screens/Admin/admin_chat_monitoring.dart';
import 'package:web_chatter_mobile/Screens/Admin/admin_dev_mode.dart';
import 'package:web_chatter_mobile/Screens/Admin/admin_notification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminItems = [
      {
        'title': 'All Users',
        'icon': Icons.people_outline,
        'screen': const AdminUsersScreen(),
      },
      {
        'title': 'Analytics',
        'icon': Icons.analytics_outlined,
        'screen': const AdminAnalyticsScreen(),
      },
      {
        'title': 'Monitor Chat',
        'icon': Icons.chat_bubble_outline,
        'screen': const AdminChatMonitoring(),
      },
      {
        'title': 'Dev Mode',
        'icon': Icons.developer_mode,
        'screen': const DevModeScreen(),
      },
      {
        'title': 'Notifications',
        'icon': Icons.notifications_outlined,
        'screen': const AdminNotificationsScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: adminItems.length,
              itemBuilder: (context, index) {
                return _buildAdminItem(
                  context,
                  adminItems[index]['title'] as String,
                  adminItems[index]['icon'] as IconData,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => adminItems[index]['screen'] as Widget,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2A2A),
                        // Darker icon background
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Consola',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
