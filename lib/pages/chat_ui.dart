import 'dart:async';
import 'package:flutter/material.dart';
import 'package:egypttest/service/chat.dart';
import 'package:egypttest/global/passengers_model.dart';
import 'package:egypttest/global/chat_model.dart';
import 'package:egypttest/pages/HomeScreen.dart';
import 'package:egypttest/pages/bus_routes_page.dart';
import 'package:egypttest/pages/wallet.dart';

class ChatUI extends StatefulWidget {
  const ChatUI({super.key});

  @override
  State<ChatUI> createState() => _ChatUIState();
}

class _ChatUIState extends State<ChatUI> {
  int selectedIndex = 1; // Chat is selected
  final Color selectedColor = const Color(0xFF38B6FF);
  final Color unselectedColor = Colors.grey;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF141A57),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_to_mobile),
            onPressed: () => _showTransferDialog(),
            tooltip: 'Send Money',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: ChatService.getUserChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('Error loading chats: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No conversations yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Send money to someone to start chatting',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showTransferDialog(),
                          icon: const Icon(Icons.send_to_mobile),
                          label: const Text('Send Money'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141A57),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return _buildChatTile(chat);
                  },
                );
              },
            ),
          ),
          // Bottom Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIconButton(Icons.departure_board, 0),
                _buildIconButton(Icons.groups, 1),
                _buildIconButton(Icons.home, 2),
                _buildIconButton(Icons.credit_card, 3),
                _buildIconButton(Icons.more_horiz, 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatModel chat) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xFF141A57),
        child: chat.otherUser.imgUrl?.isNotEmpty == true
            ? ClipOval(
                child: Image.network(
                  chat.otherUser.imgUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(chat.otherUserName),
                ),
              )
            : _buildDefaultAvatar(chat.otherUserName),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.otherUserName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF38B6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: chat.isTyping
                    ? Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 12,
                            child: _buildTypingIndicator(),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'typing...',
                            style: TextStyle(
                              color: Color(0xFF38B6FF),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                chat.formattedTime,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualChatPage(chat: chat),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        _buildDot(0),
        const SizedBox(width: 2),
        _buildDot(1),
        const SizedBox(width: 2),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeInOut,
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFF38B6FF),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildIconButton(IconData icon, int index) {
    return IconButton(
      icon: Icon(icon, color: selectedIndex == index ? selectedColor : unselectedColor),
      onPressed: () => _handleNavigation(index),
    );
  }

  void _handleNavigation(int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BusRoutesPage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Wallet()),
      );
    }
  }

  void _showTransferDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransferMoneyPage(),
      ),
    );
  }
}

// Individual Chat Page
class IndividualChatPage extends StatefulWidget {
  final ChatModel chat;

  const IndividualChatPage({super.key, required this.chat});

  @override
  State<IndividualChatPage> createState() => _IndividualChatPageState();
}

class _IndividualChatPageState extends State<IndividualChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when entering chat
    ChatService.markMessagesAsRead(widget.chat.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    // Stop typing when leaving chat
    if (_isTyping) {
      ChatService.setTyping(widget.chat.id, false);
    }
    super.dispose();
  }

  void _onMessageChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
      ChatService.setTyping(widget.chat.id, true);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() {
          _isTyping = false;
        });
        ChatService.setTyping(widget.chat.id, false);
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Stop typing
    if (_isTyping) {
      _isTyping = false;
      ChatService.setTyping(widget.chat.id, false);
      _typingTimer?.cancel();
    }

    // Send message
    ChatService.sendMessage(
      chatId: widget.chat.id,
      text: text,
    );

    // Clear input
    _messageController.clear();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A57),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: widget.chat.otherUser.imgUrl?.isNotEmpty == true
                  ? ClipOval(
                      child: Image.network(
                        widget.chat.otherUser.imgUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          widget.chat.otherUserName.isNotEmpty ? widget.chat.otherUserName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFF141A57),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      widget.chat.otherUserName.isNotEmpty ? widget.chat.otherUserName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF141A57),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<List<String>>(
                    stream: ChatService.getTypingUsers(widget.chat.id),
                    builder: (context, snapshot) {
                      final typingUsers = snapshot.data ?? [];
                      if (typingUsers.isNotEmpty) {
                        return const Text(
                          'typing...',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_to_mobile),
            onPressed: () => _showQuickTransfer(),
            tooltip: 'Send Money',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: ChatService.getMessages(widget.chat.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onMessageChanged,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF141A57),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.isCurrentUser;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF141A57),
              child: widget.chat.otherUser.imgUrl?.isNotEmpty == true
                  ? ClipOval(
                      child: Image.network(
                        widget.chat.otherUser.imgUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          widget.chat.otherUserName.isNotEmpty ? widget.chat.otherUserName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    )
                  : Text(
                      widget.chat.otherUserName.isNotEmpty ? widget.chat.otherUserName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isTransfer
                    ? const Color(0xFF4CAF50)
                    : isMe
                        ? const Color(0xFF141A57)
                        : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isTransfer && message.transferAmount != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Transfer: ${message.transferAmount!.toStringAsFixed(2)} EGP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (message.text.contains('Message:')) ...[
                      const SizedBox(height: 4),
                      Text(
                        message.text.split('Message:')[1].trim(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ] else ...[
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.formattedTime,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.readBy.length > 1 ? Icons.done_all : Icons.done,
                          size: 16,
                          color: message.readBy.length > 1 ? const Color(0xFF4CAF50) : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF38B6FF),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  void _showQuickTransfer() {
    showDialog(
      context: context,
      builder: (context) => QuickTransferDialog(
        recipient: widget.chat.otherUser,
        onTransferComplete: () {
          // Refresh the chat after transfer
          setState(() {});
        },
      ),
    );
  }
}

// Transfer Money Page
class TransferMoneyPage extends StatefulWidget {
  const TransferMoneyPage({super.key});

  @override
  State<TransferMoneyPage> createState() => _TransferMoneyPageState();
}

class _TransferMoneyPageState extends State<TransferMoneyPage> {
  final TextEditingController _searchController = TextEditingController();
  List<PassengerModel> _users = [];
  List<PassengerModel> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await ChatService.getAllRegisteredUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
      );
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final fullName = '${user.fname ?? ''} ${user.lname ?? ''}'.toLowerCase();
          final name = (user.name ?? '').toLowerCase();
          final email = (user.email ?? '').toLowerCase();
          final searchQuery = query.toLowerCase();

          return fullName.contains(searchQuery) ||
                 name.contains(searchQuery) ||
                 email.contains(searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
        backgroundColor: const Color(0xFF141A57),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No users found'
                                  : 'No users match your search',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserTile(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(PassengerModel user) {
    final userName = '${user.fname ?? ''} ${user.lname ?? ''}'.trim().isNotEmpty
        ? '${user.fname} ${user.lname}'
        : user.name ?? 'User';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xFF141A57),
        child: user.imgUrl?.isNotEmpty == true
            ? ClipOval(
                child: Image.network(
                  user.imgUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: user.email?.isNotEmpty == true
          ? Text(user.email!, style: TextStyle(color: Colors.grey[600]))
          : null,
      trailing: const Icon(Icons.send_to_mobile, color: Color(0xFF38B6FF)),
      onTap: () => _showTransferDialog(user),
    );
  }

  void _showTransferDialog(PassengerModel recipient) {
    showDialog(
      context: context,
      builder: (context) => TransferDialog(
        recipient: recipient,
        onTransferComplete: () {
          Navigator.pop(context); // Close transfer page
          Navigator.pop(context); // Go back to chat list
        },
      ),
    );
  }
}

// Transfer Dialog
class TransferDialog extends StatefulWidget {
  final PassengerModel recipient;
  final VoidCallback onTransferComplete;

  const TransferDialog({
    super.key,
    required this.recipient,
    required this.onTransferComplete,
  });

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final recipientName = '${widget.recipient.fname ?? ''} ${widget.recipient.lname ?? ''}'.trim().isNotEmpty
        ? '${widget.recipient.fname} ${widget.recipient.lname}'
        : widget.recipient.name ?? 'User';

    return AlertDialog(
      title: Text('Send Money to $recipientName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (EGP)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.money),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Message (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.message),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleTransfer,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF141A57),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _handleTransfer() async {
    final amountText = _amountController.text.trim();
    final message = _messageController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ChatService.transferMoney(
        receiverId: widget.recipient.id!,
        amount: amount,
        message: message.isNotEmpty ? message : null,
      );

      if (result.success) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Transfer successful'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onTransferComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Transfer failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }
}

// Quick Transfer Dialog (from individual chat)
class QuickTransferDialog extends StatefulWidget {
  final PassengerModel recipient;
  final VoidCallback onTransferComplete;

  const QuickTransferDialog({
    super.key,
    required this.recipient,
    required this.onTransferComplete,
  });

  @override
  State<QuickTransferDialog> createState() => _QuickTransferDialogState();
}

class _QuickTransferDialogState extends State<QuickTransferDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final recipientName = '${widget.recipient.fname ?? ''} ${widget.recipient.lname ?? ''}'.trim().isNotEmpty
        ? '${widget.recipient.fname} ${widget.recipient.lname}'
        : widget.recipient.name ?? 'User';

    return AlertDialog(
      title: Text('Send Money to $recipientName'),
      content: TextField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Amount (EGP)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.money),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleTransfer,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF141A57),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _handleTransfer() async {
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ChatService.transferMoney(
        receiverId: widget.recipient.id!,
        amount: amount,
      );

      if (result.success) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Transfer successful'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onTransferComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Transfer failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }
}