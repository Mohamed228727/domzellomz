import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:egypttest/global/passengers_model.dart';
import 'package:egypttest/global/payment_model.dart';
import 'package:egypttest/global/chat_model.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all registered users for transfer selection
  static Future<List<PassengerModel>> getAllRegisteredUsers() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      print('🎯 Loading all registered users...');

      final querySnapshot = await _firestore
          .collection('passengers')
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .get();

      List<PassengerModel> users = [];
      for (var doc in querySnapshot.docs) {
        try {
          final passenger = PassengerModel.fromFirestore(doc);
          // Only include users with complete profiles
          if (passenger.isProfileComplete) {
            users.add(passenger);
          }
        } catch (e) {
          print('Error parsing user ${doc.id}: $e');
        }
      }

      // Sort by name
      users.sort((a, b) {
        String nameA = '${a.fname ?? ''} ${a.lname ?? ''}'.trim();
        String nameB = '${b.fname ?? ''} ${b.lname ?? ''}'.trim();
        if (nameA.isEmpty) nameA = a.name ?? '';
        if (nameB.isEmpty) nameB = b.name ?? '';
        return nameA.compareTo(nameB);
      });

      print('✅ Loaded ${users.length} registered users');
      return users;
    } catch (e) {
      print('❌ Error getting registered users: $e');
      return [];
    }
  }

  // Transfer money between users and create/update chat
  static Future<TransferResult> transferMoney({
    required String receiverId,
    required double amount,
    String? message,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        return TransferResult(success: false, error: 'User not authenticated');
      }

      if (currentUserId == receiverId) {
        return TransferResult(success: false, error: 'Cannot transfer to yourself');
      }

      if (amount <= 0) {
        return TransferResult(success: false, error: 'Amount must be greater than 0');
      }

      print('🎯 Starting transfer: $amount EGP from $currentUserId to $receiverId');

      // Get sender and receiver data
      final sender = await PassengerModel.getPassenger(currentUserId);
      final receiver = await PassengerModel.getPassenger(receiverId);

      if (sender == null) {
        return TransferResult(success: false, error: 'Sender not found');
      }

      if (receiver == null) {
        return TransferResult(success: false, error: 'Receiver not found');
      }

      // Check if sender has sufficient balance
      if (!sender.hasSufficientBalance(amount)) {
        return TransferResult(
          success: false, 
          error: 'Insufficient balance. You have ${sender.balanceWithCurrency}'
        );
      }

      print('✅ Balance check passed. Performing transfer...');

      // Perform the transfer
      // Update sender balance
      final newSenderBalance = sender.balance - amount;
      await _firestore.collection('passengers').doc(currentUserId).update({
        'balance': newSenderBalance,
      });

      // Update receiver balance
      final newReceiverBalance = receiver.balance + amount;
      await _firestore.collection('passengers').doc(receiverId).update({
        'balance': newReceiverBalance,
      });

      print('✅ Balances updated successfully');

      // Create transaction records
      final senderTransaction = TransactionModel.createTransfer(
        passengerId: currentUserId,
        amount: -amount, // Negative for debit
        balanceAfter: newSenderBalance,
        transferType: 'sent',
        otherUserId: receiverId,
        description: 'Transfer to ${receiver.fname ?? receiver.name ?? 'User'}',
      );

      final receiverTransaction = TransactionModel.createTransfer(
        passengerId: receiverId,
        amount: amount, // Positive for credit
        balanceAfter: newReceiverBalance,
        transferType: 'received',
        otherUserId: currentUserId,
        description: 'Transfer from ${sender.fname ?? sender.name ?? 'User'}',
      );

      // Save transaction records
      await senderTransaction.saveToFirestore();
      await receiverTransaction.saveToFirestore();

      print('✅ Transaction records saved');

      // Create or get existing chat
      final chatId = await ChatModel.getOrCreateChat(receiverId);

      print('✅ Chat created/retrieved: $chatId');

      // Send transfer notification message
      final transferMessage = message?.isNotEmpty == true 
          ? 'Transfer: ${amount.toStringAsFixed(2)} EGP\nMessage: $message'
          : 'Transfer: ${amount.toStringAsFixed(2)} EGP';

      await MessageModel.sendMessage(
        chatId: chatId,
        text: transferMessage,
        messageType: 'transfer',
        transferAmount: amount,
      );

      print('✅ Transfer message sent to chat');

      return TransferResult(
        success: true,
        chatId: chatId,
        message: 'Successfully transferred ${amount.toStringAsFixed(2)} EGP',
      );

    } catch (e) {
      print('❌ Error transferring money: $e');
      return TransferResult(success: false, error: 'Transfer failed: ${e.toString()}');
    }
  }

  // Get user's chat list - WITH FALLBACK SUPPORT
  static Stream<List<ChatModel>> getUserChats() {
    try {
      print('🎯 Getting user chats...');
      return ChatModel.getUserChatsStream().handleError((error) {
        print('🔥 Main chat stream failed, using fallback: $error');
        return ChatModel.getUserChatsStreamFallback();
      });
    } catch (e) {
      print('🔥 Chat stream setup failed, using fallback: $e');
      return ChatModel.getUserChatsStreamFallback();
    }
  }

  // Send a message
  static Future<void> sendMessage({
    required String chatId,
    required String text,
    String messageType = 'text',
    double? transferAmount,
  }) async {
    return await MessageModel.sendMessage(
      chatId: chatId,
      text: text,
      messageType: messageType,
      transferAmount: transferAmount,
    );
  }

  // Get messages stream for a chat
  static Stream<List<MessageModel>> getMessages(String chatId) {
    return MessageModel.getMessagesStream(chatId);
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String chatId) async {
    return await MessageModel.markAllMessagesAsRead(chatId);
  }

  // Set typing status
  static Future<void> setTyping(String chatId, bool isTyping) async {
    return await ChatModel.setTyping(chatId, isTyping);
  }

  // Get typing status stream
  static Stream<List<String>> getTypingUsers(String chatId) {
    return ChatModel.getTypingUsersStream(chatId);
  }

  // Search users for transfer
  static Future<List<PassengerModel>> searchUsers(String query) async {
    if (query.isEmpty) return await getAllRegisteredUsers();

    final allUsers = await getAllRegisteredUsers();
    final queryLower = query.toLowerCase();

    return allUsers.where((user) {
      final fullName = '${user.fname ?? ''} ${user.lname ?? ''}'.toLowerCase();
      final name = (user.name ?? '').toLowerCase();
      final email = (user.email ?? '').toLowerCase();
      
      return fullName.contains(queryLower) ||
             name.contains(queryLower) ||
             email.contains(queryLower);
    }).toList();
  }

  // Create or get existing chat between two users (for backward compatibility)
  static Future<String> createOrGetChat(String otherUserId) async {
    return await ChatModel.getOrCreateChat(otherUserId);
  }
}