import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Services/Storage/shared_prefs_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupDetails;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupDetails,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<MapEntry<String, Map<String, dynamic>>> _cachedMessages = [];
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _initializeCache();
  }

  void _initializeCache() async {
    final groupId = widget.groupId;

    setState(() {
      _cachedMessages = _getCachedMessages(groupId);
      _isLoadingMessages = false;
    });

    FirebaseDatabase.instance
        .ref('group_chats/$groupId')
        .onValue
        .listen((event) {
      final messagesMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateCache(groupId, messagesMap);
    });
  }

  List<MapEntry<String, Map<String, dynamic>>> _getCachedMessages(
      String groupId) {
    try {
      final cachedData =
          SharedPrefsService.instance.getString('group_chat_$groupId');
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
      String groupId, Map<dynamic, dynamic> messages) async {
    try {
      final convertedMessages = messages.map((key, value) {
        return MapEntry(
            key.toString(), Map<String, dynamic>.from(value as Map));
      });

      await SharedPrefsService.instance
          .setString('group_chat_$groupId', json.encode(convertedMessages));

      setState(() {
        _cachedMessages = convertedMessages.entries.toList()
          ..sort((a, b) => (a.value['timestamp'] as int)
              .compareTo(b.value['timestamp'] as int));
      });
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: widget.groupDetails['avatarSeed'] == null ||
                        widget.groupDetails['avatarSeed'].toString().isEmpty
                    ? Text(
                        widget.groupDetails['name'][0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Consola',
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : RandomAvatar(
                        widget.groupDetails['avatarSeed'],
                        height: 32,
                        width: 32,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.groupDetails['name'],
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Consola',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : StreamBuilder(
                    stream: FirebaseDatabase.instance
                        .ref('group_chats/${widget.groupId}')
                        .onValue,
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
                        final messagesMap =
                            event.snapshot.value as Map<dynamic, dynamic>? ??
                                {};
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
                          final isMe = message['senderId'] == currentUser?.uid;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.white30
                                    : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      message['senderName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontFamily: 'Consola',
                                        color: Colors.yellow,
                                        fontSize: 12,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message['text'] ?? '',
                                    style: const TextStyle(
                                      fontFamily: 'Consola',
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
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
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.yellow),
                  onPressed: () => _handleSendMessage(currentUser?.uid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSendMessage(String? currentUserId) async {
    if (_messageController.text.trim().isEmpty || currentUserId == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      await FirebaseDatabase.instance
          .ref('group_chats/${widget.groupId}')
          .push()
          .set({
        'text': messageText,
        'senderId': currentUserId,
        'senderName':
            context.read<AuthService>().currentUser?.displayName ?? '',
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }
}
