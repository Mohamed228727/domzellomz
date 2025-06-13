// test/transaction_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:egypttest/global/payment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('TransactionModel Tests', () {
    
    test('should create top-up transaction correctly', () {
      // Act
      final transaction = TransactionModel.createTopUp(
        passengerId: 'user123',
        amount: 50.0,
        balanceAfter: 150.0,
        paymentMethod: 'card',
        description: 'Test top-up',
      );

      // Assert
      expect(transaction.passengerId, 'user123');
      expect(transaction.amount, 50.0);
      expect(transaction.balanceAfter, 150.0);
      expect(transaction.type, TransactionType.topUp);
      expect(transaction.paymentMethod, 'card');
      expect(transaction.description, 'Test top-up');
    });

    test('should create bus payment transaction correctly', () {
      // Act
      final transaction = TransactionModel.createBusPayment(
        passengerId: 'user123',
        amount: 30.0,
        balanceAfter: 70.0,
        routeId: 'route_55',
        busId: 'bus_13',
      );

      // Assert
      expect(transaction.passengerId, 'user123');
      expect(transaction.amount, 30.0);
      expect(transaction.balanceAfter, 70.0);
      expect(transaction.type, TransactionType.payment);
      expect(transaction.routeId, 'route_55');
      expect(transaction.busId, 'bus_13');
      expect(transaction.paymentMethod, 'wallet');
    });

    test('should create transfer transaction correctly', () {
      // Act
      final transaction = TransactionModel.createTransfer(
        passengerId: 'user123',
        amount: -25.0,  // Negative for sent money
        balanceAfter: 75.0,
        transferType: 'sent',
        otherUserId: 'user456',
        description: 'Transfer to Ahmed',
      );

      // Assert
      expect(transaction.passengerId, 'user123');
      expect(transaction.amount, -25.0);
      expect(transaction.balanceAfter, 75.0);
      expect(transaction.type, TransactionType.transfer);
      expect(transaction.paymentMethod, 'sent');
      expect(transaction.metadata?['otherUserId'], 'user456');
      expect(transaction.metadata?['transferType'], 'sent');
    });

    test('should format amount correctly', () {
      // Arrange
      final transaction = TransactionModel(
        passengerId: 'user123',
        type: TransactionType.topUp,
        amount: 123.456,
        balanceAfter: 200.0,
        description: 'Test',
        createdAt: Timestamp.now(),
      );

      // Act & Assert
      expect(transaction.formattedAmount, '123.46');
      expect(transaction.amountWithCurrency, '123.46 EGP');
    });

    test('should identify debit and credit transactions correctly', () {
      // Test debit transaction (payment)
      final paymentTransaction = TransactionModel.createBusPayment(
        passengerId: 'user123',
        amount: 30.0,
        balanceAfter: 70.0,
        routeId: 'route_55',
        busId: 'bus_13',
      );
      expect(paymentTransaction.isDebit, true);
      expect(paymentTransaction.isCredit, false);

      // Test credit transaction (top-up)
      final topUpTransaction = TransactionModel.createTopUp(
        passengerId: 'user123',
        amount: 50.0,
        balanceAfter: 150.0,
        paymentMethod: 'card',
      );
      expect(topUpTransaction.isDebit, false);
      expect(topUpTransaction.isCredit, true);

      // Test transfer sent (debit)
      final transferSent = TransactionModel.createTransfer(
        passengerId: 'user123',
        amount: -25.0,
        balanceAfter: 75.0,
        transferType: 'sent',
        otherUserId: 'user456',
        description: 'Transfer to Ahmed',
      );
      expect(transferSent.isDebit, true);
      expect(transferSent.isCredit, false);

      // Test transfer received (credit)
      final transferReceived = TransactionModel.createTransfer(
        passengerId: 'user456',
        amount: 25.0,
        balanceAfter: 125.0,
        transferType: 'received',
        otherUserId: 'user123',
        description: 'Transfer from Adam',
      );
      expect(transferReceived.isDebit, false);
      expect(transferReceived.isCredit, true);
    });

    test('should display transaction type names correctly', () {
      final topUp = TransactionModel.createTopUp(
        passengerId: 'user123',
        amount: 50.0,
        balanceAfter: 150.0,
        paymentMethod: 'card',
      );
      expect(topUp.typeDisplayName, 'Top Up');

      final payment = TransactionModel.createBusPayment(
        passengerId: 'user123',
        amount: 30.0,
        balanceAfter: 70.0,
        routeId: 'route_55',
        busId: 'bus_13',
      );
      expect(payment.typeDisplayName, 'Bus Payment');

      final transferSent = TransactionModel.createTransfer(
        passengerId: 'user123',
        amount: -25.0,
        balanceAfter: 75.0,
        transferType: 'sent',
        otherUserId: 'user456',
        description: 'Transfer to Ahmed',
      );
      expect(transferSent.typeDisplayName, 'Money Sent');

      final transferReceived = TransactionModel.createTransfer(
        passengerId: 'user456',
        amount: 25.0,
        balanceAfter: 125.0,
        transferType: 'received',
        otherUserId: 'user123',
        description: 'Transfer from Adam',
      );
      expect(transferReceived.typeDisplayName, 'Money Received');
    });
  });
}