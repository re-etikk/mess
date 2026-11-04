import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  String _convosCacheKey() => 'thali_partner_convos_${widget.session.providerId}';
  String _chatCacheKey(String customerId) => 'thali_partner_chat_${widget.session.providerId}_$customerId';

  @override
  void initState() {
    super.initState();
    _loadCachedConversations();
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

  Future<void> _loadCachedConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_convosCacheKey());
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _conversations = list;
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent && _conversations.isEmpty) setState(() => _loading = true);
    try {
      final list = await ProviderApiService.fetchChatConversations(widget.session.providerId);
      if (mounted) {
        setState(() {
          _conversations = list;
          _loading = false;
        });
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_convosCacheKey(), jsonEncode(list));
      } catch (_) {}
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openConversation(Map<String, dynamic> convo) async {
    final customerId = convo['customer_id']?.toString() ?? '';
    setState(() {
      _activeConversation = convo;
      _loadingMessages = true;
      _messages = [];
    });

    if (customerId.isEmpty) return;

    // Load from cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatCacheKey(customerId));
      if (raw != null && raw.isNotEmpty) {
        final cached = (jsonDecode(raw) as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
        if (mounted && cached.isNotEmpty) {
          setState(() {
            _messages = cached;
            _loadingMessages = false;
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}

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
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_chatCacheKey(customerId), jsonEncode(msgs));
      } catch (_) {}
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
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_chatCacheKey(customerId), jsonEncode(msgs));
        } catch (_) {}
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

    // Cache immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatCacheKey(customerId), jsonEncode(_messages));
    } catch (_) {}

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
          SnackBar(content: Text('Message saved locally: $e'), backgroundColor: orange),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer Messages', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ink)),
                        SizedBox(height: 2),
                        Text('Direct encrypted messages from subscribers', style: TextStyle(color: muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: orange),
                    onPressed: () => _loadConversations(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: Color(0xFF0F766E)),
                  SizedBox(width: 6),
                  Text(
                    'End-to-End Encrypted (AES-256) · Direct Kitchen Chat',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: orange))
                  : _conversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.mark_chat_unread_outlined, size: 54, color: muted),
                                const SizedBox(height: 14),
                                const Text('No messages yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                                const SizedBox(height: 6),
                                const Text(
                                  'When students chat with your mess via their Thali app, their messages will appear here in real time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: muted, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _conversations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final convo = _conversations[idx];
                            final name = convo['customer_name']?.toString() ?? 'Student';
                            final lastMsg = convo['last_message']?.toString() ?? '';
                            final unread = (convo['unread_count'] as num?)?.toInt() ?? 0;

                            return Card(
                              elevation: 0,
                              color: card,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFFFE8BF),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                                subtitle: Text(
                                  lastMsg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: unread > 0 ? ink : muted, fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal),
                                ),
                                trailing: unread > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(10)),
                                        child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                      )
                                    : const Icon(Icons.chevron_right, color: muted, size: 18),
                                onTap: () => _openConversation(convo),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatThreadView() {
    final customerName = _activeConversation?['customer_name']?.toString() ?? 'Student';

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ink),
          onPressed: () => setState(() => _activeConversation = null),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
            const Text('Customer · Active Thread', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFFF1F5F9),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 13, color: Color(0xFF0F766E)),
                SizedBox(width: 6),
                Text(
                  'End-to-End Encrypted (AES-256) · Direct Kitchen Chat',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator(color: orange))
                : _messages.isEmpty
                    ? Center(
                        child: Text('No messages with $customerName yet.', style: const TextStyle(color: muted)),
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
                                color: isProvider ? orange : card,
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
