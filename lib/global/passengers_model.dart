import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:egypttest/global/payment_model.dart';
import 'dart:math';

class PassengerModel {
  String? id;
  String? fname;
  String? lname;
  String? gender;
  String? passengerId;
  String? phoneNumber;
  String? email;
  String? name;
  String? imgUrl;
  double balance;  // Added wallet balance
  Timestamp? createdAt;

  PassengerModel({
    this.id,
    this.fname,
    this.lname,
    this.gender,
    this.passengerId,
    this.phoneNumber,
    this.email,
    this.name,
    this.imgUrl,
    this.balance = 0.0,  // Default balance is 0
    this.createdAt,
  });

  // Convert from Firestore document
  factory PassengerModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PassengerModel(
      id: doc.id,
      fname: data['fname'],
      lname: data['lname'],
      gender: data['gender'],
      passengerId: data['passenger_id'],
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      name: data['name'],
      imgUrl: data['imgUrl'],
      balance: (data['balance'] ?? 0.0).toDouble(),  // Added balance parsing
      createdAt: data['createdAt'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {};
    
    if (id != null) data['id'] = id;
    if (fname != null) data['fname'] = fname;
    if (lname != null) data['lname'] = lname;
    if (gender != null) data['gender'] = gender;
    if (passengerId != null) data['passenger_id'] = passengerId;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (email != null) data['email'] = email;
    if (name != null) data['name'] = name;
    if (imgUrl != null) data['imgUrl'] = imgUrl;
    data['balance'] = balance;  // Always include balance
    if (createdAt != null) data['createdAt'] = createdAt;
    
    return data;
  }

  // Generate passenger ID
  static String generatePassengerId(String firstName) {
    Random random = Random();
    int randomNumber = 100 + random.nextInt(801); // Generates 100-900
    return "${firstName.toLowerCase()}_$randomNumber";
  }

  // Create passenger from phone auth
  static PassengerModel createFromPhoneAuth({
    required String uid,
    required String phoneNumber,
  }) {
    return PassengerModel(
      id: uid,
      phoneNumber: phoneNumber,
      balance: 0.0,  // Start with zero balance
      createdAt: Timestamp.now(),
    );
  }

  // Create passenger from Google auth
  static PassengerModel createFromGoogleAuth({
    required String uid,
    required String email,
    required String name,
    required String imgUrl,
  }) {
    return PassengerModel(
      id: uid,
      email: email,
      name: name,
      imgUrl: imgUrl,
      balance: 0.0,  // Start with zero balance
      createdAt: Timestamp.now(),
    );
  }

  // Complete profile (add personal details)
  PassengerModel completeProfile({
    required String firstName,
    required String lastName,
    required String gender,
  }) {
    return PassengerModel(
      id: this.id,
      fname: firstName,
      lname: lastName,
      gender: gender,
      passengerId: generatePassengerId(firstName),
      phoneNumber: this.phoneNumber,
      email: this.email,
      name: this.name,
      imgUrl: this.imgUrl,
      balance: this.balance,  // Preserve existing balance
      createdAt: this.createdAt,
    );
  }

  // Check if profile is complete
  bool get isProfileComplete {
    return fname != null && 
           fname!.isNotEmpty && 
           lname != null && 
           lname!.isNotEmpty && 
           gender != null && 
           gender!.isNotEmpty;
  }

  // Save to Firestore
  Future<void> saveToFirestore() async {
    if (id == null) {
      throw Exception('Cannot save passenger without ID');
    }
    
    await FirebaseFirestore.instance
        .collection('passengers')
        .doc(id)
        .set(toFirestore(), SetOptions(merge: true));
  }

  // Get passenger from Firestore
  static Future<PassengerModel?> getPassenger(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('passengers')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        return PassengerModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting passenger: $e');
      return null;
    }
  }

  // Check if passenger exists
  static Future<bool> passengerExists(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('passengers')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking passenger existence: $e');
      return false;
    }
  }

  // Wallet Management Methods
  
  // Get formatted balance for display
  String get formattedBalance {
    return balance.toStringAsFixed(2);
  }

  String get balanceWithCurrency {
    return '${formattedBalance} EGP';
  }

  // Add money to wallet (Top up)
  Future<bool> addBalance(double amount, String paymentMethod) async {
    if (amount <= 0 || id == null) return false;

    try {
      double newBalance = balance + amount;
      
      // Update passenger balance
      await FirebaseFirestore.instance
          .collection('passengers')
          .doc(id)
          .update({'balance': newBalance});

      // Create transaction record
      final transaction = TransactionModel.createTopUp(
        passengerId: id!,
        amount: amount,
        balanceAfter: newBalance,
        paymentMethod: paymentMethod,
      );
      await transaction.saveToFirestore();

      // Update local balance
      balance = newBalance;
      
      print('✔ Balance added successfully: +${amount.toStringAsFixed(2)} EGP');
      return true;
    } catch (e) {
      print('❌ Error adding balance: $e');
      return false;
    }
  }

  // Deduct money from wallet (Pay for bus)
  Future<bool> deductBalance(double amount, String routeId, String busId) async {
    if (amount <= 0 || id == null || balance < amount) return false;

    try {
      double newBalance = balance - amount;
      
      // Update passenger balance
      await FirebaseFirestore.instance
          .collection('passengers')
          .doc(id)
          .update({'balance': newBalance});

      // Create transaction record
      final transaction = TransactionModel.createBusPayment(
        passengerId: id!,
        amount: amount,
        balanceAfter: newBalance,
        routeId: routeId,
        busId: busId,
      );
      await transaction.saveToFirestore();

      // Update local balance
      balance = newBalance;
      
      print('✔ Balance deducted successfully: -${amount.toStringAsFixed(2)} EGP');
      return true;
    } catch (e) {
      print('❌ Error deducting balance: $e');
      return false;
    }
  }

  // Check if passenger has sufficient balance
  bool hasSufficientBalance(double amount) {
    return balance >= amount;
  }

  // Get passenger's transaction history
  Future<List<TransactionModel>> getTransactionHistory({int limit = 50}) async {
    if (id == null) return [];
    return await TransactionModel.getPassengerTransactions(id!, limit: limit);
  }

  // Refresh balance from Firestore
  Future<void> refreshBalance() async {
    if (id == null) return;
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('passengers')
          .doc(id)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        balance = (data['balance'] ?? 0.0).toDouble();
      }
    } catch (e) {
      print('Error refreshing balance: $e');
    }
  }
}