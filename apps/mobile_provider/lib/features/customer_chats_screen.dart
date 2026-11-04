import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/provider_api_service.dart';

const Color ink = Color(0xFF182435);
const Color orange = Color(0xFFFF6B1A);
const Color muted = Color(0xFF687382);
const Color card = Color(0xFFFFFFFF);
const Color line = Color(0xFFE9E0D5);
const Color cream = Color(0xFFFBF6EE);

class CustomerChatsScreen extends StatefulWidget {
  const CustomerChatsScreen({super.key, required this.session, this.onBack});
  final ProviderSession session;
  final VoidCallback? onBack;

  @override
  State<CustomerChatsScreen> createState() => _CustomerChatsScreenState();
}

class _CustomerChatsScreenState extends State<CustomerChatsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _activeConversation;

  // Active chat state
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_activeConversation != null) {
        _refreshMessagesSilently();
      } else {
        _loadConversations(silent: true);
      }
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = await ProviderApiService.fetchChatConversations(widget.session.providerId);
      if (mounted) {
        setState(() {
          _conversations = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openConversation(Map<String, dynamic> convo) async {
    setState(() {
      _activeConversation = convo;
      _loadingMessages = true;
      _messages = [];
    });

    final customerId = convo['customer_id']?.toString() ?? '';
    if (customerId.isEmpty) return;

    try {
      final msgs = await ProviderApiService.fetchChatMessages(
        providerId: widget.session.providerId,
        customerId: customerId,
      );
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _refreshMessagesSilently() async {
    if (_activeConversation == null) return;
    final customerId = _activeConversation!['customer_id']?.toString() ?? '';
    if (customerId.isEmpty) return;

    try {
      final msgs = await ProviderApiService.fetchChatMessages(
        providerId: widget.session.providerId,
        customerId: customerId,
      );
      if (mounted && msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? attachment}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && attachment == null) return;

    final customerId = _activeConversation!['customer_id']?.toString() ?? '';
    _messageController.clear();

    // Optimistic local add
    final optimisticMsg = {
      'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
      'provider_id': widget.session.providerId,
      'customer_id': customerId,
      'sender_role': 'provider',
      'sender_name': widget.session.businessName,
      'message': text.isNotEmpty ? text : 'Sent an attachment',
      'attachment_url': attachment,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    try {
      await ProviderApiService.sendChatMessage(
        providerId: widget.session.providerId,
        customerId: customerId,
        senderId: widget.session.providerId,
        message: text.isNotEmpty ? text : 'Sent an attachment',
        senderRole: 'provider',
        senderName: widget.session.businessName,
        attachmentUrl: attachment,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: const Color(0xFFC0392B)),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await _sendMessage(attachment: dataUri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeConversation != null) {
      return _buildChatThreadView();
    }
    return _buildConversationListView();
  }

  Widget _buildConversationListView() {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        title: const Text('Customer Chats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: orange))
          : _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 64, color: muted),
                        const SizedBox(height: 16),
                        const Text(
                          'No customer messages yet',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'When subscribers or customers send inquiries or food questions from the app, their messages will appear here in real time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _loadConversations(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Chats'),
                          style: ElevatedButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: line),
                  itemBuilder: (ctx, idx) {
                    final convo = _conversations[idx];
                    final name = convo['customer_name']?.toString() ?? 'Customer';
                    final lastMsg = convo['last_message']?.toString() ?? '';
                    final unread = (convo['unread_count'] as int?) ?? 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFEDD5),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: orange),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ink)),
                          ),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(12)),
                              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: unread > 0 ? ink : muted, fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal),
                      ),
                      onTap: () => _openConversation(convo),
                    );
                  },
                ),
    );
  }

  Widget _buildChatThreadView() {
    final name = _activeConversation!['customer_name']?.toString() ?? 'Customer';

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Customer Inquiries', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _activeConversation = null);
            _loadConversations(silent: true);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator(color: orange))
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Send a reply below.', style: TextStyle(color: muted, fontSize: 13)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = _messages[idx];
                          final isProvider = msg['sender_role'] == 'provider';
                          final attachment = msg['attachment_url']?.toString();

                          return Align(
                            alignment: isProvider ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isProvider ? orange : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isProvider ? 16 : 4),
                                  bottomRight: Radius.circular(isProvider ? 4 : 16),
                                ),
                                border: isProvider ? null : Border.all(color: line),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isProvider ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (attachment != null && attachment.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: attachment.startsWith('data:image')
                                          ? Image.memory(base64Decode(attachment.split(',').last), height: 160, fit: BoxFit.cover)
                                          : Image.network(attachment, height: 160, fit: BoxFit.cover),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                    msg['message']?.toString() ?? '',
                                    style: TextStyle(
                                      color: isProvider ? Colors.white : ink,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Message input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: line)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_camera_outlined, color: muted),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: line)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: orange,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(),
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
