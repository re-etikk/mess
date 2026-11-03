import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  final String providerId;
  final String providerName;

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Timer? _pollTimer;

  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.thali.store',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _startPolling();
    });
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
      _loadMessages(silent: true);
    });
  }

  String _getCustomerId() {
    final state = AppStateScope.of(context, listen: false);
    if (state.customerId.isNotEmpty) return state.customerId;
    if (state.customerEmail.isNotEmpty) return state.customerEmail.replaceAll('@', '_').replaceAll('.', '_');
    return 'student_guest';
  }

  String _getCustomerName() {
    final state = AppStateScope.of(context, listen: false);
    return state.customerName.isNotEmpty ? state.customerName : 'Student';
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final customerId = _getCustomerId();

    try {
      final uri = Uri.parse('$_defaultBaseUrl/api/chat/messages?provider_id=${widget.providerId}&customer_id=$customerId');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['messages'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
        if (mounted) {
          final countChanged = list.length != _messages.length;
          setState(() {
            _messages = list;
            _loading = false;
          });
          if (countChanged) _scrollToBottom();
        }
      } else {
        if (mounted && !silent) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
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

    final customerId = _getCustomerId();
    final customerName = _getCustomerName();
    _messageController.clear();

    // Optimistic local add
    final optimisticMsg = {
      'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
      'provider_id': widget.providerId,
      'customer_id': customerId,
      'sender_role': 'customer',
      'sender_name': customerName,
      'message': text.isNotEmpty ? text : 'Sent a photo attachment',
      'attachment_url': attachment,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    try {
      final uri = Uri.parse('$_defaultBaseUrl/api/chat/messages');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider_id': widget.providerId,
          'customer_id': customerId,
          'sender_id': customerId,
          'sender_role': 'customer',
          'sender_name': customerName,
          'message': text.isNotEmpty ? text : 'Sent a photo attachment',
          'attachment_url': attachment,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendPhoto() async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick photo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.providerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Mess Partner Chat', style: TextStyle(color: MessColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: MessColors.orange))
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 54, color: MessColors.muted),
                              const SizedBox(height: 14),
                              Text('Chat with ${widget.providerName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: MessColors.ink)),
                              const SizedBox(height: 6),
                              const Text(
                                'Ask about today\'s special menu, timing adjustments, delivery details, or payment questions.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: MessColors.muted, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = _messages[idx];
                          final isCustomer = msg['sender_role'] == 'customer';
                          final attachment = msg['attachment_url']?.toString();

                          return Align(
                            alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isCustomer ? MessColors.orangeDark : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isCustomer ? 16 : 4),
                                  bottomRight: Radius.circular(isCustomer ? 4 : 16),
                                ),
                                border: isCustomer ? null : Border.all(color: MessColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                                      color: isCustomer ? Colors.white : MessColors.ink,
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
              border: Border(top: BorderSide(color: MessColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_camera_outlined, color: MessColors.muted),
                  onPressed: _pickAndSendPhoto,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: MessColors.border)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: MessColors.orangeDark,
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
