import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'Analytics',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder(
        future: FirebaseDatabase.instance.ref('users').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final usersMap = (snapshot.data?.value as Map?) ?? {};
          final totalUsers = usersMap.length;
          int onlineUsers = 0;
          int usersWithAvatar = 0;
          int usersWithSimpleAvatar = 0;
          int adminUsers = 0;
          int disabledUsers = 0;

          for (var user in usersMap.values) {
            if (user['avatarSeed'] != null &&
                user['avatarSeed'].toString().isNotEmpty) {
              usersWithAvatar++;
            }
            if (user['useSimpleAvatar'] == true) {
              usersWithSimpleAvatar++;
            }
            if (user['isAdmin'] == true) {
              adminUsers++;
            }
            if (user['disabled'] == true) {
              disabledUsers++;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAnalyticCard(
                'Total Users',
                totalUsers.toString(),
                Icons.people_outline,
              ),
              const SizedBox(height: 16),
              StreamBuilder(
                stream: FirebaseDatabase.instance.ref('status').onValue,
                builder: (context, statusSnapshot) {
                  if (statusSnapshot.hasData) {
                    final statusMap =
                        (statusSnapshot.data?.snapshot.value as Map?) ?? {};
                    onlineUsers = statusMap.values
                        .where((status) => status['state'] == 'online')
                        .length;
                  }
                  return Column(
                    children: [
                      _buildAnalyticCard(
                        'Online Users',
                        onlineUsers.toString(),
                        Icons.online_prediction,
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticCard(
                        'Offline Users',
                        (totalUsers - onlineUsers).toString(),
                        Icons.offline_bolt_outlined,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildAnalyticCard(
                'Users with Avatar',
                usersWithAvatar.toString(),
                Icons.face,
              ),
              const SizedBox(height: 16),
              _buildAnalyticCard(
                'Users with Simple Avatar',
                usersWithSimpleAvatar.toString(),
                Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildAnalyticCard(
                'Admin Users',
                adminUsers.toString(),
                Icons.admin_panel_settings_outlined,
              ),
              const SizedBox(height: 16),
              _buildAnalyticCard(
                'Disabled Users',
                disabledUsers.toString(),
                Icons.block_outlined,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnalyticCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Consola',
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Consola',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
