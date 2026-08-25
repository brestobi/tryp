import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/trip_service.dart';

class RideChatSheet extends StatefulWidget {
  final TripService tripService;
  final String rideId;
  final String currentUserId;
  final String otherPartyName;

  const RideChatSheet({
    super.key,
    required this.tripService,
    required this.rideId,
    required this.currentUserId,
    required this.otherPartyName,
  });

  @override
  State<RideChatSheet> createState() => _RideChatSheetState();
}

class _RideChatSheetState extends State<RideChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<RideChatMessage> _messages = [];
  RealtimeChannel? _messageSubscription;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageSubscription = widget.tripService.subscribeToRideMessages(
      rideId: widget.rideId,
      onMessage: _receiveMessage,
    );
    unawaited(_loadMessages());
  }

  @override
  void dispose() {
    _messageSubscription?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await widget.tripService.getRideMessages(widget.rideId);
    if (!mounted) return;
    setState(() {
      for (final message in messages) {
        if (_messages.every((existing) => existing.id != message.id)) {
          _messages.add(message);
        }
      }
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _isLoading = false;
    });
    _scrollToLatest();
  }

  void _receiveMessage(RideChatMessage message) {
    if (!mounted || _messages.any((existing) => existing.id == message.id)) {
      return;
    }
    setState(() {
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final message = await widget.tripService.sendRideMessage(
      rideId: widget.rideId,
      message: body,
    );
    if (!mounted) return;

    if (message == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message could not be sent.')),
      );
    } else {
      _messageController.clear();
      _receiveMessage(message);
    }
    setState(() => _isSending = false);
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TRYPColors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.chat_rounded, color: TRYPColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat with ${widget.otherPartyName}',
                            style: TRYPTypography.titleMedium,
                          ),
                          Text(
                            'Available until this ride ends',
                            style: TRYPTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: TRYPColors.primary,
                        ),
                      )
                    : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Send a message to coordinate pickup.',
                          style: TRYPTypography.bodyMedium.copyWith(
                            color: TRYPColors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMine =
                              message.senderId == widget.currentUserId;
                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? TRYPColors.primary
                                    : TRYPColors.inputFill,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: isMine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.body,
                                    style: TRYPTypography.bodyMedium.copyWith(
                                      color: isMine
                                          ? TRYPColors.white
                                          : TRYPColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: TRYPTypography.bodySmall.copyWith(
                                      color: isMine
                                          ? TRYPColors.white.withValues(
                                              alpha: 0.75,
                                            )
                                          : TRYPColors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          counterText: '',
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      tooltip: 'Send message',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
