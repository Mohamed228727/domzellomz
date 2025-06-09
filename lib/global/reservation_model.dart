import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  final String busId;
  final DateTime departureTime;
  final String destination;
  final String passengerId;
  final DateTime reservationDate;
  final String reservationId;
  final String routeId;
  final int seatNumber;
  final String status;

  Reservation({
    required this.busId,
    required this.departureTime,
    required this.destination,
    required this.passengerId,
    required this.reservationDate,
    required this.reservationId,
    required this.routeId,
    required this.seatNumber,
    required this.status,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestoreDoc() {
    return {
      'bus_id': busId,
      'departure_time': Timestamp.fromDate(departureTime),
      'destination': destination,
      'passenger_id': passengerId,
      'reservation_date': Timestamp.fromDate(reservationDate),
      'reservation_id': reservationId,
      'route_id': routeId,
      'seat_number': seatNumber,
      'status': status,
    };
  }

  // Create from Firestore document
  factory Reservation.fromFirestore(Map<String, dynamic> data, String id) {
    return Reservation(
      busId: data['bus_id'] as String,
      departureTime: (data['departure_time'] as Timestamp).toDate(),
      destination: data['destination'] as String,
      passengerId: data['passenger_id'] as String,
      reservationDate: (data['reservation_date'] as Timestamp).toDate(),
      reservationId: id,
      routeId: data['route_id'] as String,
      seatNumber: data['seat_number'] as int,
      status: data['status'],
    );
  }
}