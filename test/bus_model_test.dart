// test/bus_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:egypttest/global/bus_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('Bus Model Tests', () {
    
    test('should check seat availability correctly', () {
      // Arrange
      final bus = Bus(
        id: 'bus123',
        busNo: '13',
        capacity: 20,
        currentPassengers: 5,
        driverId: 'driver1',
        routeId: 'route_55',
        bookedSeats: [1, 5, 10, 15], // 4 seats booked
      );

      // Act & Assert
      expect(bus.isSeatAvailable(1), false);  // Seat 1 is booked
      expect(bus.isSeatAvailable(5), false);  // Seat 5 is booked
      expect(bus.isSeatAvailable(2), true);   // Seat 2 is available
      expect(bus.isSeatAvailable(20), true);  // Seat 20 is available
      expect(bus.isSeatAvailable(21), false); // Seat 21 doesn't exist (over capacity)
      expect(bus.isSeatAvailable(0), false);  // Seat 0 is invalid
    });

    test('should get available seats correctly', () {
      // Arrange
      final bus = Bus(
        id: 'bus123',
        busNo: '13',
        capacity: 5,
        currentPassengers: 2,
        driverId: 'driver1',
        routeId: 'route_55',
        bookedSeats: [1, 3], // Seats 1 and 3 are booked
      );

      // Act
      final availableSeats = bus.getAvailableSeats();

      // Assert
      expect(availableSeats, [2, 4, 5]); // Only seats 2, 4, 5 should be available
      expect(availableSeats.length, 3);
      expect(availableSeats.contains(1), false); // Seat 1 is booked
      expect(availableSeats.contains(3), false); // Seat 3 is booked
    });

    test('should calculate remaining seats correctly', () {
      // Test bus with some booked seats
      final bus1 = Bus(
        id: 'bus123',
        busNo: '13',
        capacity: 10,
        currentPassengers: 5,
        driverId: 'driver1',
        routeId: 'route_55',
        bookedSeats: [1, 2, 3], // 3 seats booked
      );
      expect(bus1.remainingSeats, 7); // 10 - 3 = 7

      // Test empty bus
      final bus2 = Bus(
        id: 'bus456',
        busNo: '14',
        capacity: 20,
        currentPassengers: 0,
        driverId: 'driver2',
        routeId: 'route_56',
        bookedSeats: [], // No seats booked
      );
      expect(bus2.remainingSeats, 20); // 20 - 0 = 20

      // Test full bus
      final bus3 = Bus(
        id: 'bus789',
        busNo: '15',
        capacity: 5,
        currentPassengers: 5,
        driverId: 'driver3',
        routeId: 'route_57',
        bookedSeats: [1, 2, 3, 4, 5], // All seats booked
      );
      expect(bus3.remainingSeats, 0); // 5 - 5 = 0
    });

    test('should check if bus is full correctly', () {
      // Test bus that is not full
      final bus1 = Bus(
        id: 'bus123',
        busNo: '13',
        capacity: 10,
        currentPassengers: 7,
        driverId: 'driver1',
        routeId: 'route_55',
        bookedSeats: [1, 2, 3, 4, 5, 6, 7], // 7 seats booked
      );
      expect(bus1.isFull, false);

      // Test bus that is full
      final bus2 = Bus(
        id: 'bus456',
        busNo: '14',
        capacity: 5,
        currentPassengers: 5,
        driverId: 'driver2',
        routeId: 'route_56',
        bookedSeats: [1, 2, 3, 4, 5], // All seats booked
      );
      expect(bus2.isFull, true);

      // Test empty bus
      final bus3 = Bus(
        id: 'bus789',
        busNo: '15',
        capacity: 20,
        currentPassengers: 0,
        driverId: 'driver3',
        routeId: 'route_57',
        bookedSeats: [], // No seats booked
      );
      expect(bus3.isFull, false);
    });
  });

  group('Route Model Tests', () {
    
    test('should format price correctly', () {
      // Arrange
      final route = Route(
        busIds: ['bus1', 'bus2'],
        EndLoaction: 'Maadi',
        routeId: 'route_55',
        startLoaction: 'Tahrir',
        stops: ['Zamalek', 'Garden City'],
        price: 25.567, // Price with many decimals
      );

      // Act & Assert
      expect(route.formattedPrice, '25.57');
      expect(route.getPriceWithCurrency(), '25.57 EGP');
      expect(route.getPriceWithCurrency(currency: 'USD'), '25.57 USD');
    });

    test('should handle different price formats', () {
      // Test integer price
      final route1 = Route(
        busIds: ['bus1'],
        EndLoaction: 'Maadi',
        routeId: 'route_55',
        startLoaction: 'Tahrir',
        stops: [],
        price: 30.0,
      );
      expect(route1.formattedPrice, '30.00');

      // Test price with one decimal
      final route2 = Route(
        busIds: ['bus2'],
        EndLoaction: 'Nasr City',
        routeId: 'route_56',
        startLoaction: 'Downtown',
        stops: [],
        price: 15.5,
      );
      expect(route2.formattedPrice, '15.50');

      // Test zero price
      final route3 = Route(
        busIds: ['bus3'],
        EndLoaction: 'Free Route',
        routeId: 'route_free',
        startLoaction: 'Start',
        stops: [],
        price: 0.0,
      );
      expect(route3.formattedPrice, '0.00');
    });
  });
}