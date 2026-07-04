import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_message.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_extension_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';

/// Real-time chat between user and accountability partner.
/// Uses Firestore stream — messages appear instantly on both sides.
class AccountabilityChatScreen extends StatefulWidget {
  final AccountabilityPartner partner;

  const AccountabilityChatScreen({super.key, required this.partner});

  @override
  State<AccountabilityChatScreen> createState() =>
      _AccountabilityChatScreenState();
}

class _AccountabilityChatScreenState extends State<AccountabilityChatScreen> {
  final _svc = AccountabilityExtensionService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  MessageType _selectedType = MessageType.encouragement;
  bool _sending = false;
  int _previousMessageCount = 0;

  String get _myUid => AccountabilityService().currentUid ?? '';

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollCtrl.hasClients) return true;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final currentScroll = _scrollCtrl.offset;
    return (maxScroll - currentScroll) <= 150.0;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || widget.partner.partnerUid == null) return;

    setState(() => _sending = true);
    _textCtrl.clear();

    // Determine receiver: if I am the owner, send to partnerUid; otherwise send to ownerUid
    final receiverUid = widget.partner.ownerUid == _myUid
        ? widget.partner.partnerUid!
        : widget.partner.ownerUid;

    await _svc.sendMessage(
      receiverUid: receiverUid,
      partnershipId: widget.partner.id,
      text: text,
      type: _selectedType,
    );

    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.partner.partnerName,
      ),
      body: Column(
        children: [
          // Type selector
          _buildTypeSelector(),
          // Messages
          Expanded(child: _buildMessageList()),
          // Input
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: MessageType.values.map((t) {
            final selected = _selectedType == t;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '${t.emoji} ${t.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? AppColors.primary : Colors.grey[700],
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<AccountabilityMessage>>(
      stream: _svc.messagesStream(widget.partner.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snap.data ?? [];
        if (messages.isEmpty) {
          _previousMessageCount = 0;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No messages yet. Say something!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              ],
            ),
          );
        }
        // Only auto-scroll if a new message arrived and user was near bottom
        if (messages.length > _previousMessageCount && _isNearBottom()) {
          _scrollToBottom();
        }
        _previousMessageCount = messages.length;
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: messages.length,
          itemBuilder: (_, i) =>
              _MessageBubble(msg: messages[i], myUid: _myUid),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Write a message…',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _sending ? Colors.grey[300] : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AccountabilityMessage msg;
  final String myUid;

  const _MessageBubble({required this.msg, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.senderUid == myUid;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  msg.senderName,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${msg.type.emoji} ${msg.type.label}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                DateFormat('h:mm a').format(msg.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
