import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

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
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatCacheKey(customerId));
      if (raw != null && raw.isNotEmpty) {
        final cached = (jsonDecode(raw) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? attachment}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && attachment == null) return;
    if (_activeConversation == null) return;

    _messageController.clear();
    final customerId = _activeConversation!['customer_id']?.toString() ?? '';
    final msgText = text.isNotEmpty ? text : 'Photo attachment';

    setState(() {
      _messages.add({
        'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
        'provider_id': widget.session.providerId,
        'customer_id': customerId,
        'sender_role': 'provider',
        'sender_name': widget.session.businessName,
        'message': msgText,
        'attachment_url': attachment,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatCacheKey(customerId), jsonEncode(_messages));
    } catch (_) {}

    try {
      await ProviderApiService.sendChatMessage(
        providerId: widget.session.providerId,
        customerId: customerId,
        message: msgText,
        senderRole: 'provider',
        senderName: widget.session.businessName,
        senderId: widget.session.userId,
        attachmentUrl: attachment,
      );
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, 'Failed to send: $e', isError: true);
      }
    }
  }

  Future<void> _pickAndSendPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await _sendMessage(attachment: 'data:image/jpeg;base64,${base64Encode(bytes)}');
      }
    } catch (e) {
      if (mounted) showPartnerNotice(context, 'Failed to select photo: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeConversation != null) {
      return _buildThreadView();
    }

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 26), onPressed: widget.onBack)
            : null,
        title: const Text('Customer Messages'),
      ),
      body: RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: () => _loadConversations(),
        child: _loading
            ? const PartnerSkeletonList(itemCount: 4, cardHeight: 80)
            : _conversations.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 48),
                      CardSurface(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 44, color: ThaliColors.muted),
                            SizedBox(height: 12),
                            Text('No Messages Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                            SizedBox(height: 6),
                            Text(
                              'Messages sent by subscribers from their Thali app appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ThaliColors.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final convo = _conversations[i];
                      final name = convo['customer_name']?.toString().trim().isNotEmpty == true
                          ? convo['customer_name'].toString()
                          : 'Subscriber';
                      final lastMsg = convo['last_message']?.toString() ?? '';
                      return CardSurface(
                        onTap: () => _openConversation(convo),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: ThaliColors.primarySoft,
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(color: ThaliColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: ThaliColors.ink)),
                                  const SizedBox(height: 3),
                                  Text(
                                    lastMsg,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: ThaliColors.muted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: ThaliColors.muted),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildThreadView() {
    final customerName = _activeConversation?['customer_name']?.toString().trim().isNotEmpty == true
        ? _activeConversation!['customer_name'].toString()
        : 'Subscriber';

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 26),
          onPressed: () {
            setState(() => _activeConversation = null);
            _loadConversations();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Text('Thali Subscriber', style: TextStyle(fontSize: 11, color: ThaliColors.greenDark, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingMessages
                ? const PartnerLoadingView(label: 'Loading messages...')
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg['sender_role'] == 'provider';
                      final attachment = msg['attachment_url']?.toString();
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? ThaliColors.primary : ThaliColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: isMe ? null : Border.all(color: ThaliColors.stroke),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (attachment != null && attachment.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: attachment.startsWith('data:image')
                                      ? Image.memory(base64Decode(attachment.split(',').last), height: 150, fit: BoxFit.cover)
                                      : Image.network(attachment, height: 150, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                msg['message']?.toString() ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : ThaliColors.ink,
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: ThaliColors.card,
              border: Border(top: BorderSide(color: ThaliColors.stroke)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_camera_outlined, color: ThaliColors.muted),
                  onPressed: _pickAndSendPhoto,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Reply to customer...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: ThaliColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
