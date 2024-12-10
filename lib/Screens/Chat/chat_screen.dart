import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Services/Chat/chat_service.dart';
import 'package:web_chatter_mobile/Core/Services/Notification/notification_service.dart';
import 'package:web_chatter_mobile/Core/Services/Status/user_status_service.dart';
import 'package:web_chatter_mobile/Core/Services/Storage/shared_prefs_service.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> otherUser;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.otherUserId,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  String? _currentUserId;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _slideController;
  late AnimationController _fadeController;
  List<MapEntry<String, Map<String, dynamic>>> _cachedMessages = [];
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthService>().currentUser?.uid;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideController.forward();
    _fadeController.forward();
    _initializeCache();
    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser != null) {
      ChatService().enterChat(widget.otherUserId);
    }
    _markMessagesAsRead();
    if (currentUser != null) {
      FirebaseDatabase.instance
          .ref('users/${currentUser.uid}/currentChat')
          .set(getChatId(currentUser.uid, widget.otherUserId));

      UserStatusService.startMonitoring(context, currentUser.uid);
    }
  }

  // Future<void> _clearChatState() async {
  //   final currentUser = context.read<AuthService>().currentUser;
  //   if (currentUser != null) {
  //     try {
  //       await FirebaseDatabase.instance
  //           .ref('users/${currentUser.uid}/currentChat')
  //           .remove();
  //     } catch (e) {
  //       debugPrint('Error clearing chat state: $e');
  //     }
  //   }
  // }

  void _markMessagesAsRead() {
    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser == null) return;

    final chatId = getChatId(currentUser.uid, widget.otherUserId);

    FirebaseDatabase.instance.ref('chats/$chatId').onValue.listen((event) {
      if (!mounted) return;

      final messages = event.snapshot.value as Map<dynamic, dynamic>?;
      if (messages == null) return;

      messages.forEach((key, value) {
        if (value['senderId'] != currentUser.uid && !(value['read'] ?? true)) {
          FirebaseDatabase.instance
              .ref('chats/$chatId/$key')
              .update({'read': true});
        }
      });
    });
  }

  void _initializeCache() async {
    final currentUser = context.read<AuthService>().currentUser;
    final chatId = getChatId(currentUser!.uid, widget.otherUserId);

    setState(() {
      _cachedMessages = _getCachedMessages(chatId);
      _isLoadingMessages = false;
    });

    FirebaseDatabase.instance.ref('chats/$chatId').onValue.listen((event) {
      final messagesMap = event.snapshot.value as Map? ?? {};
      _updateCache(chatId, messagesMap);
    });
  }

  List<MapEntry<String, Map<String, dynamic>>> _getCachedMessages(
      String chatId) {
    try {
      final cachedData = SharedPrefsService.instance.getString('chat_$chatId');
      if (cachedData != null) {
        final decodedData = Map<String, dynamic>.from(json.decode(cachedData));
        return decodedData.entries
            .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value)))
            .toList()
          ..sort((a, b) => (a.value['timestamp'] as int)
              .compareTo(b.value['timestamp'] as int));
      }
    } catch (e) {
      debugPrint('Error loading cached messages: $e');
    }
    return [];
  }

  Future<void> _updateCache(
      String chatId, Map<dynamic, dynamic> messages) async {
    try {
      await SharedPrefsService.instance
          .setString('chat_$chatId', json.encode(messages));
      setState(() {
        _cachedMessages = messages.entries
            .map(
              (e) => MapEntry(
                e.key.toString(),
                Map<String, dynamic>.from(e.value as Map),
              ),
            )
            .toList()
          ..sort((a, b) => (a.value['timestamp'] as int)
              .compareTo(b.value['timestamp'] as int));
      });
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  @override
  void dispose() {
    ChatService().exitChat();
    if (_currentUserId != null) {
      FirebaseDatabase.instance
          .ref('users/$_currentUserId/currentChat')
          .remove()
          .catchError((e) => debugPrint('Error clearing chat state: $e'));
    }
    _messageController.dispose();
    _scrollController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser;
    final chatId = getChatId(currentUser!.uid, widget.otherUserId);

    FirebaseDatabase.instance
        .ref('users/${currentUser.uid}/currentChat')
        .set(chatId);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(
          widget.otherUser['name'],
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref('status/${widget.otherUserId}')
                .onValue,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final status =
                    (snapshot.data as DatabaseEvent).snapshot.value as Map?;
                final isOnline = status?['state'] == 'online';
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A), // Dark container
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontFamily: 'Consola',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green[300] : Colors.grey[400],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : StreamBuilder(
                    stream:
                        FirebaseDatabase.instance.ref('chats/$chatId').onValue,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(
                              fontFamily: 'Consola',
                              color: Colors.white70,
                            ),
                          ),
                        );
                      }

                      List<MapEntry<String, Map<String, dynamic>>> messages =
                          _cachedMessages;

                      if (snapshot.hasData) {
                        final event = snapshot.data as DatabaseEvent;
                        final messagesMap = event.snapshot.value as Map? ?? {};
                        messages = messagesMap.entries
                            .map(
                              (e) => MapEntry(
                                e.key.toString(),
                                Map<String, dynamic>.from(e.value as Map),
                              ),
                            )
                            .toList()
                          ..sort((a, b) => (a.value['timestamp'] as int)
                              .compareTo(b.value['timestamp'] as int));
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].value;
                          final isMe = message['senderId'] == currentUser.uid;
                          final isRead = message['read'] ?? false;

                          final animation = Tween<Offset>(
                            begin: Offset(isMe ? 1 : -1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _slideController,
                            curve: Interval(
                              index / messages.length,
                              (index + 1) / messages.length,
                              curve: Curves.easeOutQuad,
                            ),
                          ));

                          return SlideTransition(
                            position: animation,
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: isMe ? 8 : 16,
                                  top: 12,
                                  bottom: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.white30
                                      : const Color(0xFF2A2A2A),
                                  borderRadius: isMe
                                      ? const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          bottomLeft: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        )
                                      : const BorderRadius.only(
                                          topRight: Radius.circular(16),
                                          bottomLeft: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 5,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        message['text'],
                                        style: const TextStyle(
                                          fontFamily: 'Consola',
                                          color: Colors.white,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        isRead ? Icons.done_all : Icons.done,
                                        size: 16,
                                        color: isRead
                                            ? Colors.white70
                                            : Colors.white38,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          FadeTransition(
            opacity: _fadeController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_fadeController),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, -4),
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          cursorColor: Colors.white,
                          cursorHeight: 24,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          onSubmitted: (_) {
                            FocusScope.of(context).requestFocus(FocusNode());
                          },
                          controller: _messageController,
                          style: const TextStyle(
                            fontFamily: 'Consola',
                            fontSize: 17,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a message ...',
                            hintStyle: TextStyle(
                              fontFamily: 'Consola',
                              color: Colors.grey,
                              fontSize: 17,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: Colors.green.shade800,
                        ),
                        onPressed: () =>
                            _handleSendMessage(currentUser.uid, chatId),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSendMessage(String currentUserId, String chatId) async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final recipientStatus = await FirebaseDatabase.instance
          .ref('users/${widget.otherUserId}/currentChat')
          .get();

      final isRecipientInChat =
          recipientStatus.exists && recipientStatus.value == chatId;

      await FirebaseDatabase.instance.ref('chats/$chatId').push().set({
        'text': messageText,
        'senderId': currentUserId,
        'timestamp': ServerValue.timestamp,
        'read': isRecipientInChat,
      });

      final userSnapshot =
          await FirebaseDatabase.instance.ref('users/$currentUserId').get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final senderName = userData['name'] as String? ?? 'User';

        if (!isRecipientInChat) {
          final notificationService = NotificationService();
          await notificationService.sendChatMessage(
            recipientUserId: widget.otherUserId,
            senderName: senderName,
            messageText: messageText,
            chatId: chatId,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
