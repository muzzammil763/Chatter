import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminChatViewer extends StatefulWidget {
  final MapEntry<String, dynamic> user1;
  final MapEntry<String, dynamic> user2;

  const AdminChatViewer({
    super.key,
    required this.user1,
    required this.user2,
  });

  @override
  State<AdminChatViewer> createState() => _AdminChatViewerState();
}

class _AdminChatViewerState extends State<AdminChatViewer> {
  final _scrollController = ScrollController();
  List<MapEntry<String, Map<String, dynamic>>> messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  void _loadMessages() {
    final chatId = getChatId(widget.user1.key, widget.user2.key);
    setState(() => _isLoading = true);

    FirebaseDatabase.instance.ref('chats/$chatId').onValue.listen((event) {
      if (!mounted) return;

      final messagesMap = event.snapshot.value as Map? ?? {};
      setState(() {
        messages = messagesMap.entries
            .map((e) => MapEntry(
                  e.key.toString(),
                  Map<String, dynamic>.from(e.value as Map),
                ))
            .toList()
          ..sort((a, b) => (a.value['timestamp'] as int)
              .compareTo(b.value['timestamp'] as int));
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chat Monitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${widget.user1.value['name']} - ${widget.user2.value['name']}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Consola',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            )
          : messages.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages between these users',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Consola',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].value;
                    final isUser1 = message['senderId'] == widget.user1.key;
                    final sender =
                        isUser1 ? widget.user1.value : widget.user2.value;
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(
                      message['timestamp'] as int,
                    );

                    return Align(
                      alignment: isUser1
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isUser1
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: isUser1
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser1
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    sender['name'],
                                    style: TextStyle(
                                      color:
                                          isUser1 ? Colors.white : Colors.white,
                                      fontFamily: 'Consola',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message['text'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Consola',
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontFamily: 'Consola',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
