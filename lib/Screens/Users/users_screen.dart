import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Services/Notification/notification_service.dart';
import 'package:web_chatter_mobile/Core/Services/Status/user_status_service.dart';
import 'package:web_chatter_mobile/Core/Services/Storage/shared_prefs_service.dart';
import 'package:web_chatter_mobile/Screens/Admin/admin_dashboard.dart';
import 'package:web_chatter_mobile/Screens/Chat/chat_screen.dart';
import 'package:web_chatter_mobile/Screens/Notifications/notification_screen.dart';
import 'package:web_chatter_mobile/Screens/Settings/settings_screen.dart';
import 'package:web_chatter_mobile/Screens/Users/user_profile_screen.dart';

import '../../main.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  final _lastMessagesNotifier =
      ValueNotifier<Map<String, Map<String, dynamic>>>({});
  final Map<String, StreamSubscription> _messageSubscriptions = {};
  late AnimationController _animationController;
  late StreamSubscription _userSubscription;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  Map<dynamic, dynamic> _cachedUsers = {};
  Map<String, Map<String, dynamic>> _cachedLastMessages = {};

  void _subscribeToLastMessage(String chatId, String currentUserId) {
    _messageSubscriptions[chatId]?.cancel();

    _messageSubscriptions[chatId] = FirebaseDatabase.instance
        .ref('chats/$chatId')
        .limitToLast(1)
        .onValue
        .listen((event) {
      if (!mounted) return;

      final messagesMap = event.snapshot.value as Map?;
      if (messagesMap != null && messagesMap.isNotEmpty) {
        final lastMessage = messagesMap.values.first as Map;
        _lastMessagesNotifier.value = {
          ..._lastMessagesNotifier.value,
          chatId: Map<String, dynamic>.from(lastMessage),
        };
        _updateLastMessageCache(chatId, Map<String, dynamic>.from(lastMessage));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeCache();
    _initializeNotifications(); // Move to initState

    _userSubscription = FirebaseDatabase.instance.ref('users').onValue.listen(
      (event) {
        if (!mounted) return;
        final Map<dynamic, dynamic> users = event.snapshot.value as Map? ?? {};
        _updateCache(users);
      },
      onError: (error) {
        if (kDebugMode) {
          print('Error in user subscription: $error');
        }
      },
    );

    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser != null) {
      UserStatusService.startMonitoring(context, currentUser.uid);
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      final notificationService = NotificationService();
      final bool isPermissionGranted =
          await notificationService.checkPermissions();

      if (!isPermissionGranted && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        await notificationService.initialize(navigatorKey);
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  void _initializeCache() {
    if (!mounted) return;
    setState(() {
      _cachedUsers = SharedPrefsService.getCachedUsers();
      _cachedLastMessages = SharedPrefsService.getCachedLastMessages();
    });
  }

  Future<void> _updateCache(Map<dynamic, dynamic> users) async {
    if (!mounted) return;
    await SharedPrefsService.cacheUsers(users);
    if (!mounted) return;
    setState(() {
      _cachedUsers = users;
    });
  }

  void _updateLastMessageCache(
      String chatId, Map<String, dynamic> message) async {
    if (!mounted) return;
    await SharedPrefsService.cacheLastMessage(chatId, message);
    if (!mounted) return;
    setState(() {
      _cachedLastMessages[chatId] = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;

    return Scaffold(
      floatingActionButton: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref('users/${context.read<AuthService>().currentUser?.uid}')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final userData =
                (snapshot.data as DatabaseEvent).snapshot.value as Map?;
            final isAdmin = userData?['isAdmin'] ?? false;

            if (isAdmin) {
              return FloatingActionButton.large(
                shape: const CircleBorder(
                  side: BorderSide(
                    color: Colors.white,
                  ),
                ),
                elevation: 12,
                backgroundColor: const Color(0xFF1F1F1F),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: StreamBuilder(
          stream: FirebaseDatabase.instance
              .ref('users/${currentUser?.uid}')
              .onValue,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final userData =
                  (snapshot.data as DatabaseEvent).snapshot.value as Map?;
              if (userData != null) {
                final useSimpleAvatar = userData['useSimpleAvatar'] ?? false;
                final avatarSeed = userData['avatarSeed'] as String?;
                final email = userData['email'] as String;

                if (useSimpleAvatar ||
                    avatarSeed == null ||
                    avatarSeed.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        email[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Consola',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: RandomAvatar(
                      avatarSeed,
                      height: 32,
                      width: 32,
                    ),
                  ),
                );
              }
            }
            return const SizedBox.shrink();
          },
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: StreamBuilder(
          stream: FirebaseDatabase.instance
              .ref('users/${context.read<AuthService>().currentUser?.uid}')
              .onValue,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final userData =
                  (snapshot.data as DatabaseEvent).snapshot.value as Map?;
              return Text(
                userData?['name'] ?? 'All Users',
                style: const TextStyle(
                  fontFamily: 'Consola',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }
            return const Text(
              'All Users',
              style: TextStyle(
                fontFamily: 'Consola',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                ),
              ),
              StreamBuilder(
                stream: FirebaseDatabase.instance
                    .ref(
                        'notifications/${context.read<AuthService>().currentUser?.uid}')
                    .orderByChild('read')
                    .equalTo(false)
                    .onValue,
                builder: (context, snapshot) {
                  final hasUnread = snapshot.hasData &&
                      (snapshot.data?.snapshot.value as Map?)?.isNotEmpty ==
                          true;

                  if (!hasUnread) return const SizedBox();

                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.person_fill, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                focusNode: _searchFocus,
                cursorOpacityAnimates: true,
                cursorColor: Colors.white,
                controller: _searchController,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Consola',
                ),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontFamily: 'Consola',
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _buildUsersList(currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(currentUser) {
    final usersList = _cachedUsers.entries
        .where(
            (entry) => entry.key != currentUser?.uid) // Filter out current user
        .where((entry) {
          // Filter based on search query
          final userData = Map<String, dynamic>.from(entry.value);
          final userName = (userData['name'] ?? '').toString().toLowerCase();
          final userEmail = (userData['email'] ?? '').toString().toLowerCase();
          return userName.contains(_searchQuery) ||
              userEmail.contains(_searchQuery);
        })
        .map((entry) =>
            MapEntry(entry.key, Map<String, dynamic>.from(entry.value)))
        .toList();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: usersList.isEmpty
              ? Center(
                  child: Text(
                    'No users found',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontFamily: 'Consola',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: usersList.length,
                  itemBuilder: (context, index) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        _slideAnimation.value * (1 - index / usersList.length),
                      ),
                      child: _buildUserCard(context, usersList[index]),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildUserCard(
      BuildContext context, MapEntry<dynamic, Map<String, dynamic>> user) {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid;
    final chatId = getChatId(currentUserId!, user.key);

    Widget buildUserAvatar() {
      final useSimpleAvatar = user.value['useSimpleAvatar'] ?? false;
      final avatarSeed = user.value['avatarSeed'] as String?;
      final email = user.value['email'] as String;

      return Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: useSimpleAvatar || avatarSeed == null || avatarSeed.isEmpty
                  ? Text(
                      email[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Consola',
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : RandomAvatar(
                      avatarSeed,
                      height: 40,
                      width: 40,
                    ),
            ),
          ),
          StreamBuilder(
            stream: FirebaseDatabase.instance.ref('status/${user.key}').onValue,
            builder: (context, statusSnapshot) {
              if (statusSnapshot.hasData) {
                final status = (statusSnapshot.data as DatabaseEvent)
                    .snapshot
                    .value as Map?;
                final isOnline = status?['state'] == 'online';
                return Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF121212),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          _searchController.clear();
          _searchFocus.unfocus();
          setState(() {
            _searchQuery = '';
          });

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUser: user.value,
                otherUserId: user.key,
              ),
            ),
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.all(12),
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  user: user.value,
                  userId: user.key,
                ),
              ),
            );
          },
          child: buildUserAvatar(),
        ),
        title: Text(
          user.value['name'] ?? '',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Consola',
            color: Colors.white,
          ),
        ),
        subtitle: _buildMessagePreview(chatId, currentUserId),
        trailing: StreamBuilder(
          stream: FirebaseDatabase.instance
              .ref('users/$currentUserId/following/${user.key}')
              .onValue,
          builder: (context, followSnapshot) {
            final isFollowing = followSnapshot.hasData &&
                (followSnapshot.data as DatabaseEvent).snapshot.value != null;
            return isFollowing
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Following',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontFamily: 'Consola',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildMessagePreview(String chatId, String currentUserId) {
    if (!_messageSubscriptions.containsKey(chatId)) {
      _subscribeToLastMessage(chatId, currentUserId);
    }

    return ValueListenableBuilder(
      valueListenable: ValueNotifier(_cachedLastMessages[chatId]),
      builder: (context, value, child) {
        if (value == null) {
          return const Text(
            'No messages yet',
            style: TextStyle(
              fontFamily: 'Consola',
              color: Colors.grey,
              fontSize: 14,
            ),
          );
        }

        final messageText = value['text'] as String;
        final isSentByMe = value['senderId'] == currentUserId;
        final isRead = value['read'] ?? false;

        return _buildMessageWidget(messageText, isSentByMe, isRead);
      },
    );
  }

  Widget _buildMessageWidget(String text, bool isSentByMe, bool isRead) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isSentByMe ? 'You: $text' : text,
            style: TextStyle(
              fontFamily: 'Consola',
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight:
                  !isSentByMe && !isRead ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!isSentByMe && !isRead)
          Container(
            margin: const EdgeInsets.only(left: 8),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    _lastMessagesNotifier.dispose();
    _messageSubscriptions.forEach((_, subscription) => subscription.cancel());
    _messageSubscriptions.clear();
    _animationController.dispose();
    _userSubscription.cancel();
    super.dispose();
  }
}
