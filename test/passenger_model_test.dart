// test/passenger_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:egypttest/global/passengers_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('PassengerModel Tests', () {
    
    test('should check sufficient balance correctly', () {
      // Arrange
      final passenger = PassengerModel(
        id: 'test123',
        fname: 'Adam',
        lname: 'Hany',
        balance: 100.0,
      );

      // Act & Assert
      expect(passenger.hasSufficientBalance(50.0), true);
      expect(passenger.hasSufficientBalance(100.0), true);
      expect(passenger.hasSufficientBalance(150.0), false);
      expect(passenger.hasSufficientBalance(0.0), true);
    });

    test('should format balance correctly', () {
      // Arrange
      final passenger = PassengerModel(
        id: 'test123',
        balance: 123.456,
      );

      // Act & Assert
      expect(passenger.formattedBalance, '123.46');
      expect(passenger.balanceWithCurrency, '123.46 EGP');
    });

    test('should check profile completion correctly', () {
      // Test incomplete profile
      final incompletePassenger = PassengerModel(
        id: 'test123',
        fname: 'Adam',
        // Missing lname and gender
      );
      expect(incompletePassenger.isProfileComplete, false);

      // Test complete profile
      final completePassenger = PassengerModel(
        id: 'test123',
        fname: 'Adam',
        lname: 'Hany',
        gender: 'Male',
      );
      expect(completePassenger.isProfileComplete, true);
    });

    test('should generate passenger ID correctly', () {
      // Act
      final passengerId1 = PassengerModel.generatePassengerId('Adam');
      final passengerId2 = PassengerModel.generatePassengerId('Sara');

      // Assert
      expect(passengerId1.startsWith('adam_'), true);
      expect(passengerId2.startsWith('sara_'), true);
      expect(passengerId1.length, greaterThan(5));
      expect(passengerId2.length, greaterThan(5));
      // Should be different each time
      expect(passengerId1, isNot(equals(passengerId2)));
    });
  });
}