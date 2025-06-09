import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:egypttest/global/passengers_model.dart';

// Transfer result model
class TransferResult {
  final bool success;
  final String? error;
  final String? message;
  final String? chatId;

  TransferResult({
    required this.success,
    this.error,
    this.message,
    this.chatId,
  });
}

// Chat model
class ChatModel {
  final String id;
  final PassengerModel otherUser;
  final String lastMessage;
  final Timestamp? lastMessageTimestamp;
  final String lastMessageSender;
  final int unreadCount;
  final List<String> typingUsers;

  ChatModel({
    required this.id,
    required this.otherUser,
    required this.lastMessage,
    this.lastMessageTimestamp,
    required this.lastMessageSender,
    required this.unreadCount,
    required this.typingUsers,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc, PassengerModel otherUser) {
    final data = doc.data() as Map<String, dynamic>;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final unreadData = data['unreadCount'] as Map<String, dynamic>? ?? {};

    return ChatModel(
      id: doc.id,
      otherUser: otherUser,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTimestamp: data['lastMessageTimestamp'],
      lastMessageSender: data['lastMessageSender'] ?? '',
      unreadCount: unreadData[currentUserId] ?? 0,
      typingUsers: List<String>.from(data['typingUsers'] ?? []),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'participants': [FirebaseAuth.instance.currentUser?.uid, otherUser.id],
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp ?? FieldValue.serverTimestamp(),
      'lastMessageSender': lastMessageSender,
      'unreadCount': {
        FirebaseAuth.instance.currentUser?.uid ?? '': 0,
        otherUser.id ?? '': unreadCount,
      },
      'typingUsers': typingUsers,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get formattedTime {
    if (lastMessageTimestamp == null) return '';
    
    final now = DateTime.now();
    final messageTime = lastMessageTimestamp!.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String get otherUserName {
    return '${otherUser.fname ?? ''} ${otherUser.lname ?? ''}'.trim().isNotEmpty
        ? '${otherUser.fname} ${otherUser.lname}'
        : otherUser.name ?? 'User';
  }

  bool get isTyping {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return typingUsers.any((userId) => userId != currentUserId);
  }

  // Create a new chat
  static Future<String> createChat(String otherUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    // Create chat ID by sorting user IDs to ensure consistency
    final List<String> userIds = [currentUserId, otherUserId];
    userIds.sort();
    final chatId = '${userIds[0]}_${userIds[1]}';

    final chatData = {
      'participants': [currentUserId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSender': '',
      'unreadCount': {
        currentUserId: 0,
        otherUserId: 0,
      },
      'typingUsers': <String>[],
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set(chatData, SetOptions(merge: true));

    return chatId;
  }

  // Get or create chat between two users
  static Future<String> getOrCreateChat(String otherUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    // Create chat ID by sorting user IDs to ensure consistency
    final List<String> userIds = [currentUserId, otherUserId];
    userIds.sort();
    final chatId = '${userIds[0]}_${userIds[1]}';

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        await createChat(otherUserId);
      }

      return chatId;
    } catch (e) {
      print('Error creating/getting chat: $e');
      throw e;
    }
  }

  // Get user's chats stream - ROBUST VERSION WITH ERROR HANDLING
  static Stream<List<ChatModel>> getUserChatsStream() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      print('🔥 No current user found');
      return Stream.value([]);
    }

    print('🎯 Starting chat stream for user: $currentUserId');

    try {
      // First, try the simple query without ordering
      return FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .snapshots()
          .asyncMap((snapshot) async {
        print('🎯 Received ${snapshot.docs.length} chat documents');
        List<ChatModel> chats = [];

        for (var doc in snapshot.docs) {
          try {
            final chatData = doc.data();
            
            // Validate required fields exist
            if (!chatData.containsKey('participants') || 
                chatData['participants'] == null ||
                (chatData['participants'] as List).isEmpty) {
              print('Skipping chat ${doc.id}: missing or invalid participants');
              continue;
            }

            final participants = List<String>.from(chatData['participants']);
            
            // Find the other user
            final otherUserIds = participants.where((id) => id != currentUserId).toList();
            if (otherUserIds.isEmpty) {
              print('Skipping chat ${doc.id}: no other participants found');
              continue;
            }
            
            final otherUserId = otherUserIds.first;
            print('🎯 Processing chat ${doc.id} with user: $otherUserId');

            // Get other user's data with timeout
            try {
              final otherUser = await PassengerModel.getPassenger(otherUserId)
                  .timeout(const Duration(seconds: 10));
              
              if (otherUser != null) {
                final chat = ChatModel.fromFirestore(doc, otherUser);
                chats.add(chat);
                print('✅ Successfully added chat with ${chat.otherUserName}');
              } else {
                print('⚠️ Skipping chat ${doc.id}: other user not found');
              }
            } catch (e) {
              print('❌ Error getting user $otherUserId for chat ${doc.id}: $e');
              continue;
            }
          } catch (e) {
            print('❌ Error parsing chat ${doc.id}: $e');
            continue;
          }
        }

        // Sort chats by last message timestamp (newest first)
        chats.sort((a, b) {
          final aTime = a.lastMessageTimestamp;
          final bTime = b.lastMessageTimestamp;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime);
        });

        print('🎯 Loaded ${chats.length} chats successfully');
        return chats;
      }).handleError((error) {
        print('🔥 Error in chat stream: $error');
        return <ChatModel>[]; // Return empty list on error
      });
    } catch (e) {
      print('🔥 Error setting up chat stream: $e');
      return Stream.value(<ChatModel>[]);
    }
  }

  // Alternative method that works without any indexes - FALLBACK
  static Stream<List<ChatModel>> getUserChatsStreamFallback() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    print('🔄 Using fallback chat stream method');

    // Get all chats and filter in client
    return FirebaseFirestore.instance
        .collection('chats')
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatModel> chats = [];

      for (var doc in snapshot.docs) {
        try {
          final chatData = doc.data();
          
          // Check if current user is in participants
          final participants = List<String>.from(chatData['participants'] ?? []);
          if (!participants.contains(currentUserId)) continue;

          // Find the other user
          final otherUserId = participants.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          
          if (otherUserId.isEmpty) continue;

          // Get other user's data
          final otherUser = await PassengerModel.getPassenger(otherUserId);
          if (otherUser != null) {
            final chat = ChatModel.fromFirestore(doc, otherUser);
            chats.add(chat);
          }
        } catch (e) {
          print('Error parsing chat ${doc.id}: $e');
        }
      }

      // Sort by timestamp
      chats.sort((a, b) {
        if (a.lastMessageTimestamp == null && b.lastMessageTimestamp == null) return 0;
        if (a.lastMessageTimestamp == null) return 1;
        if (b.lastMessageTimestamp == null) return -1;
        return b.lastMessageTimestamp!.compareTo(a.lastMessageTimestamp!);
      });

      print('🔄 Fallback method loaded ${chats.length} chats');
      return chats;
    });
  }

  // Update chat metadata
  static Future<void> updateChatMetadata({
    required String chatId,
    required String lastMessage,
    required String senderId,
  }) async {
    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final participants = List<String>.from(chatData['participants']);
        final otherUserId = participants.firstWhere((id) => id != senderId);

        // Update unread count for other user
        final currentUnreadCount = chatData['unreadCount'] as Map<String, dynamic>? ?? {};
        final otherUserUnread = (currentUnreadCount[otherUserId] ?? 0) + 1;

        await chatRef.update({
          'lastMessage': lastMessage,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastMessageSender': senderId,
          'unreadCount.$otherUserId': otherUserUnread,
        });
      }
    } catch (e) {
      print('Error updating chat metadata: $e');
      throw e;
    }
  }

  // Mark messages as read
  static Future<void> markAsRead(String chatId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Reset unread count for current user
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({
        'unreadCount.$currentUserId': 0,
      });
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  // Set typing status
  static Future<void> setTyping(String chatId, bool isTyping) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      
      if (isTyping) {
        await chatRef.update({
          'typingUsers': FieldValue.arrayUnion([currentUserId]),
        });
      } else {
        await chatRef.update({
          'typingUsers': FieldValue.arrayRemove([currentUserId]),
        });
      }
    } catch (e) {
      print('Error setting typing status: $e');
    }
  }

  // Get typing users stream
  static Stream<List<String>> getTypingUsersStream(String chatId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <String>[];
      
      final typingUsers = List<String>.from(doc.data()?['typingUsers'] ?? []);
      // Remove current user from typing list
      return typingUsers.where((userId) => userId != currentUserId).toList();
    });
  }
}

// Message model
class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final Timestamp? timestamp;
  final String type;
  final List<String> readBy;
  final double? transferAmount;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    this.timestamp,
    required this.type,
    required this.readBy,
    this.transferAmount,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MessageModel(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'],
      type: data['type'] ?? 'text',
      readBy: List<String>.from(data['readBy'] ?? []),
      transferAmount: data['transferAmount']?.toDouble(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'type': type,
      'readBy': readBy,
    };

    if (transferAmount != null) {
      data['transferAmount'] = transferAmount;
    }

    return data;
  }

  bool get isCurrentUser {
    return senderId == FirebaseAuth.instance.currentUser?.uid;
  }

  bool get isRead {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return readBy.contains(currentUserId);
  }

  String get formattedTime {
    if (timestamp == null) return '';
    
    final messageTime = timestamp!.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(messageTime.year, messageTime.month, messageTime.day);

    if (messageDate == today) {
      // Today - show time only
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday';
    } else {
      // Older - show date
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }

  bool get isTransfer {
    return type == 'transfer';
  }

  // Send a message
  static Future<void> sendMessage({
    required String chatId,
    required String text,
    String messageType = 'text',
    double? transferAmount,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final messageData = {
        'text': text,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': messageType,
        'readBy': [currentUserId],
        if (transferAmount != null) 'transferAmount': transferAmount,
      };

      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat metadata
      await ChatModel.updateChatMetadata(
        chatId: chatId,
        lastMessage: text,
        senderId: currentUserId,
      );

    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  // Get messages stream for a chat
  static Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  // Mark individual messages as read
  static Future<void> markMessageAsRead(String chatId, String messageId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (messageDoc.exists) {
        final readBy = List<String>.from(messageDoc.data()?['readBy'] ?? []);
        if (!readBy.contains(currentUserId)) {
          readBy.add(currentUserId);
          await messageRef.update({'readBy': readBy});
        }
      }
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Mark all unread messages in chat as read
  static Future<void> markAllMessagesAsRead(String chatId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // First mark chat as read
      await ChatModel.markAsRead(chatId);

      // Then mark individual messages as read
      final unreadMessages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('readBy', whereNotIn: [
            [currentUserId]
          ])
          .get();

      final batch = FirebaseFirestore.instance.batch();
      
      for (var doc in unreadMessages.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(currentUserId)) {
          readBy.add(currentUserId);
          batch.update(doc.reference, {'readBy': readBy});
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all messages as read: $e');
    }
  }
}