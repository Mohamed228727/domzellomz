import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:egypttest/global/locations_var.dart';

class Bus {
  final String id;
  final String busNo;
  final int capacity;
  final int currentPassengers;
  final String driverId;
  final String routeId;
  final LatLng? location;
  int? distanceMeters;
  int? durationSeconds;
  final List<int> bookedSeats; // Added bookedSeats field
  
  Bus({
    required this.id,
    required this.busNo,
    required this.capacity,
    required this.currentPassengers,
    required this.driverId,
    required this.routeId,
    this.location,
    this.distanceMeters,
    this.durationSeconds,
    this.bookedSeats = const [], // Default to empty list
  });
  
  factory Bus.fromMap(Map<String, dynamic> data, String documentId) {
    GeoPoint? geoPoint = data['location'] is GeoPoint ? data['location'] as GeoPoint : null;
    LatLng? location;
    if (geoPoint != null) {
      location = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else if (data['location'] != null) {
      print('Invalid location format for bus $documentId: ${data['location']}');
    }
    
    // Parse bookedSeats from Firestore
    List<int> bookedSeats = [];
    if (data['booked_seats'] != null) {
      if (data['booked_seats'] is List) {
        bookedSeats = (data['booked_seats'] as List)
            .map((seat) => _safeToInt(seat))
            .where((seat) => seat > 0) // Only include valid seat numbers
            .toList();
      }
    }
    
    return Bus(
      id: documentId,
      busNo: _safeToString(data['bus_no']),
      capacity: _safeToInt(data['capacity']),
      currentPassengers: _safeToInt(data['current_passengers']),
      driverId: data['driver_id']?.toString() ?? '',
      routeId: data['route_id']?.toString() ?? '',
      location: location,
      bookedSeats: bookedSeats,
    );
  }
  
  // Helper method to check if a seat is available
  bool isSeatAvailable(int seatNumber) {
    return seatNumber > 0 && 
           seatNumber <= capacity && 
           !bookedSeats.contains(seatNumber);
  }
  
  // Helper method to get all available seats
  List<int> getAvailableSeats() {
    return List.generate(capacity, (index) => index + 1)
        .where((seat) => isSeatAvailable(seat))
        .toList();
  }
  
  // Helper method to get remaining seats count
  int get remainingSeats {
    return capacity - bookedSeats.length;
  }
  
  // Helper method to check if bus is full
  bool get isFull {
    return bookedSeats.length >= capacity;
  }
  
  static String _safeToString(dynamic value) {
    return value?.toString() ?? '';
  }
  
  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is String) return int.tryParse(value) ?? 0;
    return value is int ? value : 0;
  }
}

class Route {
  final List<String> busIds;
  final String routeId;
  final String startLoaction;
  final LatLng? startLocation;
  final LatLng? EndLocation;
  final String EndLoaction;
  final List<String> stops;
  final double price; // Price field
  
  Route({
    required this.busIds,
    required this.EndLoaction,
    required this.routeId,
    required this.startLoaction,
    this.startLocation,
    this.EndLocation,
    required this.stops,
    required this.price, // Price is required
  });
  
  factory Route.fromMap(Map<String, dynamic> data, String documentId, LocationsVar locations) {
    print('Route data for $documentId: $data');
    
    LatLng? startLocationLatLng;
    if (data['start_location'] is GeoPoint) {
      final geoPoint = data['start_location'] as GeoPoint;
      startLocationLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else {
      final locationCoords = locations.getStopLocation(data['start_loaction']?.toString() ?? '');
      startLocationLatLng = locationCoords as LatLng?;
    }
    
    LatLng? endLocationLatLng;
    if (data['end_location'] is GeoPoint) {
      final geoPoint = data['end_location'] as GeoPoint;
      endLocationLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else {
      final locationCoords = locations.getStopLocation(data['end_loaction']?.toString() ?? '');
      endLocationLatLng = locationCoords as LatLng?;
    }
    
    return Route(
      busIds: List<String>.from(data['bus_id'] ?? []),
      EndLoaction: data['end_loaction']?.toString() ?? '',
      routeId: data['route_id']?.toString() ?? documentId,
      startLoaction: data['start_loaction']?.toString() ?? '',
      startLocation: startLocationLatLng,
      EndLocation: endLocationLatLng,
      stops: List<String>.from(data['stops'] ?? []),
      price: _safeToDouble(data['price']), // Get price from Firestore
    );
  }
  
  // Helper method for price parsing
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is int) return value.toDouble();
    return value is double ? value : 0.0;
  }
  
  // Helper method to format price for display
  String get formattedPrice {
    return price.toStringAsFixed(2);
  }
  
  // Helper method to get price as string with currency
  String getPriceWithCurrency({String currency = 'EGP'}) {
    return '${formattedPrice} $currency';
  }
}