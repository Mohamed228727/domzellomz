import 'package:cloud_firestore/cloud_firestore.dart';

// Transaction Model - For wallet movements (top-ups, balance changes)
enum TransactionType {
  topUp,     // Adding money to wallet
  payment,   // Paying for bus ride
  refund,    // Money returned
  bonus,     // Promotional credits
  transfer,  // Money transfer between users - ADDED FOR CHAT SYSTEM
}

class TransactionModel {
  String? id;
  String passengerId;
  TransactionType type;
  double amount;
  double balanceAfter;
  String description;
  String? routeId;        // For bus payments
  String? busId;          // For bus payments
  String? paymentMethod;  // 'card', 'cash', 'promotion', 'sent', 'received', etc.
  Timestamp createdAt;
  Map<String, dynamic>? metadata; // Extra info if needed

  TransactionModel({
    this.id,
    required this.passengerId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.routeId,
    this.busId,
    this.paymentMethod,
    required this.createdAt,
    this.metadata,
  });

  // Convert from Firestore document
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      passengerId: data['passenger_id'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => TransactionType.payment,
      ),
      amount: (data['amount'] ?? 0.0).toDouble(),
      balanceAfter: (data['balance_after'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      routeId: data['route_id'],
      busId: data['bus_id'],
      paymentMethod: data['payment_method'],
      createdAt: data['created_at'] ?? Timestamp.now(),
      metadata: data['metadata'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      'passenger_id': passengerId,
      'type': type.toString().split('.').last,
      'amount': amount,
      'balance_after': balanceAfter,
      'description': description,
      'created_at': createdAt,
    };

    if (routeId != null) data['route_id'] = routeId;
    if (busId != null) data['bus_id'] = busId;
    if (paymentMethod != null) data['payment_method'] = paymentMethod;
    if (metadata != null) data['metadata'] = metadata;

    return data;
  }

  // Save transaction to Firestore
  Future<void> saveToFirestore() async {
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('transactions')
        .doc();
    
    await docRef.set(toFirestore());
    id = docRef.id;
  }

  // Create top-up transaction
  static TransactionModel createTopUp({
    required String passengerId,
    required double amount,
    required double balanceAfter,
    required String paymentMethod,
    String? description,
  }) {
    return TransactionModel(
      passengerId: passengerId,
      type: TransactionType.topUp,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description ?? 'Wallet top-up via $paymentMethod',
      paymentMethod: paymentMethod,
      createdAt: Timestamp.now(),
    );
  }

  // Create bus payment transaction
  static TransactionModel createBusPayment({
    required String passengerId,
    required double amount,
    required double balanceAfter,
    required String routeId,
    required String busId,
    String? description,
  }) {
    return TransactionModel(
      passengerId: passengerId,
      type: TransactionType.payment,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description ?? 'Bus ride payment',
      routeId: routeId,
      busId: busId,
      paymentMethod: 'wallet',
      createdAt: Timestamp.now(),
    );
  }

  // Create refund transaction
  static TransactionModel createRefund({
    required String passengerId,
    required double amount,
    required double balanceAfter,
    String? description,
    String? originalTransactionId,
  }) {
    return TransactionModel(
      passengerId: passengerId,
      type: TransactionType.refund,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description ?? 'Refund',
      paymentMethod: 'refund',
      createdAt: Timestamp.now(),
      metadata: originalTransactionId != null 
          ? {'original_transaction_id': originalTransactionId}
          : null,
    );
  }

  // ADDED: Create transfer transaction for chat system
  static TransactionModel createTransfer({
    required String passengerId,
    required double amount,
    required double balanceAfter,
    required String transferType, // 'sent' or 'received'
    required String otherUserId,
    required String description,
  }) {
    return TransactionModel(
      passengerId: passengerId,
      type: TransactionType.transfer,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description,
      paymentMethod: transferType, // Use paymentMethod field to store 'sent' or 'received'
      createdAt: Timestamp.now(),
      metadata: {
        'otherUserId': otherUserId,
        'transferType': transferType,
      },
    );
  }

  // Get user's transaction history
  static Future<List<TransactionModel>> getPassengerTransactions(
    String passengerId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection('transactions')
        .where('passenger_id', isEqualTo: passengerId)
        .orderBy('created_at', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    QuerySnapshot snapshot = await query.get();
    
    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList();
  }

  // Helper methods for UI display
  String get formattedAmount {
    return amount.toStringAsFixed(2);
  }

  String get amountWithCurrency {
    return '${formattedAmount} EGP';
  }

  // UPDATED: Type display name with transfer support
  String get typeDisplayName {
    switch (type) {
      case TransactionType.topUp:
        return 'Top Up';
      case TransactionType.payment:
        return 'Bus Payment';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.bonus:
        return 'Bonus';
      case TransactionType.transfer:
        // Check if it's sent or received from paymentMethod field
        return paymentMethod == 'sent' ? 'Money Sent' : 'Money Received';
    }
  }

  // UPDATED: Debit check with transfer support
  bool get isDebit {
    return type == TransactionType.payment ||
           (type == TransactionType.transfer && paymentMethod == 'sent');
  }

  // UPDATED: Credit check with transfer support
  bool get isCredit {
    return type == TransactionType.topUp || 
           type == TransactionType.refund || 
           type == TransactionType.bonus ||
           (type == TransactionType.transfer && paymentMethod == 'received');
  }

  String get formattedDate {
    DateTime date = createdAt.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Payment Model - For bus reservation payments
enum PaymentStatus {
  hold,      // Payment pending
  complete,  // Payment successful
  reject,    // Payment failed/rejected
}

class PaymentModel {
  String? id;
  double amount;
  String passengerId;
  String paymentDate;
  String paymentId;
  String reservationId;
  PaymentStatus status;
  String? routeId;        // Added for route tracking
  String? busId;          // Added for bus tracking  
  String? paymentMethod;  // Added for payment method tracking

  PaymentModel({
    this.id,
    required this.amount,
    required this.passengerId,
    required this.paymentDate,
    required this.paymentId,
    required this.reservationId,
    required this.status,
    this.routeId,
    this.busId,
    this.paymentMethod,
  });

  // Convert from Firestore document
  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      amount: (data['amount'] ?? 0.0).toDouble(),
      passengerId: data['passenger_id'] ?? '',
      paymentDate: data['payment_date'] ?? '',
      paymentId: data['payment_id'] ?? '',
      reservationId: data['reservation_id'] ?? '',
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => PaymentStatus.hold,
      ),
      routeId: data['route_id'],
      busId: data['bus_id'],
      paymentMethod: data['payment_method'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      'amount': amount,
      'passenger_id': passengerId,
      'payment_date': paymentDate,
      'payment_id': paymentId,
      'reservation_id': reservationId,
      'status': status.toString().split('.').last,
    };

    if (routeId != null) data['route_id'] = routeId;
    if (busId != null) data['bus_id'] = busId;
    if (paymentMethod != null) data['payment_method'] = paymentMethod;

    return data;
  }

  // Save payment to Firestore
  Future<void> saveToFirestore() async {
    if (id != null) {
      // Update existing payment
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(id)
          .set(toFirestore(), SetOptions(merge: true));
    } else {
      // Create new payment
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('payments')
          .doc();
      
      await docRef.set(toFirestore());
      id = docRef.id;
    }
  }

  // Create new payment
  static PaymentModel createPayment({
    required double amount,
    required String passengerId,
    required String reservationId,
    required String routeId,
    required String busId,
    String? paymentMethod,
    PaymentStatus status = PaymentStatus.hold,
  }) {
    String paymentId = 'PAY_${DateTime.now().millisecondsSinceEpoch}';
    String paymentDate = DateTime.now().toIso8601String();

    return PaymentModel(
      amount: amount,
      passengerId: passengerId,
      paymentDate: paymentDate,
      paymentId: paymentId,
      reservationId: reservationId,
      status: status,
      routeId: routeId,
      busId: busId,
      paymentMethod: paymentMethod ?? 'wallet',
    );
  }

  // Get passenger's payments
  static Future<List<PaymentModel>> getPassengerPayments(
    String passengerId, {
    int limit = 50,
  }) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('payments')
        .where('passenger_id', isEqualTo: passengerId)
        .orderBy('payment_date', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs
        .map((doc) => PaymentModel.fromFirestore(doc))
        .toList();
  }

  // Update payment status
  Future<void> updateStatus(PaymentStatus newStatus) async {
    if (id == null) return;

    status = newStatus;
    await FirebaseFirestore.instance
        .collection('payments')
        .doc(id)
        .update({'status': newStatus.toString().split('.').last});
  }

  // Helper methods for UI display
  String get formattedAmount {
    return amount.toStringAsFixed(2);
  }

  String get amountWithCurrency {
    return '${formattedAmount} EGP';
  }

  String get statusDisplayName {
    switch (status) {
      case PaymentStatus.hold:
        return 'Pending';
      case PaymentStatus.complete:
        return 'Completed';
      case PaymentStatus.reject:
        return 'Failed';
    }
  }

  bool get isCompleted {
    return status == PaymentStatus.complete;
  }

  bool get isPending {
    return status == PaymentStatus.hold;
  }

  bool get isFailed {
    return status == PaymentStatus.reject;
  }

  String get formattedDate {
    try {
      DateTime date = DateTime.parse(paymentDate);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return paymentDate;
    }
  }
}