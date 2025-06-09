import 'package:cloud_firestore/cloud_firestore.dart';

class LocationsVar {
  // Singleton instance
  static final LocationsVar _instance = LocationsVar._internal();
  factory LocationsVar() => _instance;
  LocationsVar._internal();

  // Cache for stop locations
  Map<String, GeoPoint> _stopLocations = {};

  // Initialize by fetching all stops
  Future<void> initialize() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stops').get();
      _stopLocations = {
        for (var doc in snapshot.docs)
          doc['name'] as String: doc['location'] as GeoPoint,
      };
      print('Loaded ${_stopLocations.length} stop locations');
    } catch (e) {
      print('Error loading stops: $e');
    }
  }

  // Get GeoPoint for a stop name
  GeoPoint? getStopLocation(String stopName) {
    return _stopLocations[stopName];
  }

  // Get all stop names and locations
  Map<String, GeoPoint> getAllStopLocations() {
    return Map.from(_stopLocations);
  }

  // Add or update a stop location (optional, for future use)
  Future<void> addStopLocation(String name, GeoPoint location) async {
    try {
      await FirebaseFirestore.instance.collection('stops').doc(name).set({
        'name': name,
        'location': location,
      });
      _stopLocations[name] = location;
      print('Added stop: $name');
    } catch (e) {
      print('Error adding stop: $e');
    }
  }
}