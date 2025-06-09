import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // 🔹 Add Passenger
  Future<void> addPassenger(String passengerId, Map<String, dynamic> data) async {
    await firestore.collection("passengers").doc(passengerId).set(data);
  }

  // 🔹 Add Bus
  Future<void> addBus(String busId, Map<String, dynamic> data) async {
    await firestore.collection("buses").doc(busId).set(data);
  }

  // 🔹 Add Route
  Future<void> addRoute(String routeId, Map<String, dynamic> data) async {
    await firestore.collection("routes").doc(routeId).set(data);
  }

  // 🔹 Add Reservation
  Future<void> addReservation(String reservationId, Map<String, dynamic> data) async {
    await firestore.collection("reservations").doc(reservationId).set(data);
  }

  // 🔹 Add Payment
  Future<void> addPayment(String paymentId, Map<String, dynamic> data) async {
    await firestore.collection("payments").doc(paymentId).set(data);
  }

  // 🔹 Get All Buses
  Stream<QuerySnapshot> getBuses() {
    return firestore.collection("buses").snapshots();
  }

  // 🔹 Get All Routes
  Stream<QuerySnapshot> getRoutes() {
    return firestore.collection("routes").snapshots();
  }
}
