import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Global Location Service - Singleton that persists across ALL pages
/// This service runs independently and any page can listen to location updates
class GlobalLocationService {
  // Singleton pattern
  static final GlobalLocationService _instance = GlobalLocationService._internal();
  factory GlobalLocationService() => _instance;
  GlobalLocationService._internal();

  // Current position
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Location stream for real-time updates
  StreamSubscription<Position>? _positionStream;
  
  // Broadcast stream that ALL pages can listen to
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;

  // Status tracking
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Initialize location service (call once in main app)
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint("🌍 Location service already initialized");
      return true;
    }

    debugPrint("🌍 Initializing Global Location Service...");

    try {
      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint("🌍 Current permission: $permission");

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint("🌍 Permission after request: $permission");
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("🌍 ❌ Location permission denied forever");
        return false;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // Get initial location
        await _getCurrentLocation();
        
        // Start real-time tracking
        _startLocationTracking();
        
        _isInitialized = true;
        debugPrint("🌍 ✅ Location service initialized successfully");
        return true;
      } else {
        debugPrint("🌍 ❌ Location permission not granted");
        return false;
      }
    } catch (e) {
      debugPrint("🌍 ❌ Error initializing location service: $e");
      return false;
    }
  }

  /// Get current location once
  Future<Position?> _getCurrentLocation() async {
    try {
      debugPrint("🌍 Getting current location...");
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      debugPrint("🌍 ✅ Got location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}");
      
      // Notify all listeners
      _locationController.add(_currentPosition!);
      
      return _currentPosition;
    } catch (e) {
      debugPrint("🌍 ❌ Error getting current location: $e");
      return null;
    }
  }

  /// Start real-time location tracking
  void _startLocationTracking() {
    if (_isTracking) {
      debugPrint("🌍 Location tracking already active");
      return;
    }

    debugPrint("🌍 Starting real-time location tracking...");

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        debugPrint("🌍 📍 Location updated: ${position.latitude}, ${position.longitude}");
        _currentPosition = position;
        
        // Notify ALL pages listening to this stream
        _locationController.add(position);
      },
      onError: (error) {
        debugPrint("🌍 ❌ Location stream error: $error");
      },
    );

    _isTracking = true;
    debugPrint("🌍 ✅ Real-time tracking started");
  }

  /// Get current location immediately (for pages that need it now)
  Future<Position?> getCurrentLocationNow() async {
    if (_currentPosition != null) {
      debugPrint("🌍 Returning cached location");
      return _currentPosition;
    }
    
    return await _getCurrentLocation();
  }

  /// Create markers for current location (helper method for pages)
  Future<Map<String, dynamic>> createLocationMarkers() async {
    if (_currentPosition == null) {
      debugPrint("🌍 No current position for markers");
      return {'markers': <Marker>{}, 'circles': <Circle>{}};
    }

    final LatLng position = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    // Create blue circle
    final Circle circle = Circle(
      circleId: const CircleId("userLocationAccuracy"),
      center: position,
      radius: 50,
      fillColor: Colors.blue.withOpacity(0.1),
      strokeColor: Colors.blue.withOpacity(0.3),
      strokeWidth: 1,
    );

    // Create marker (try blue, fallback to red)
    BitmapDescriptor markerIcon;
    try {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(210.0); // Light blue
    } catch (e) {
      markerIcon = BitmapDescriptor.defaultMarker; // Fallback to red
    }

    final Marker marker = Marker(
      markerId: const MarkerId("userLocation"),
      position: position,
      icon: markerIcon,
      infoWindow: const InfoWindow(title: "Your Location"),
      consumeTapEvents: false,
    );

    debugPrint("🌍 Created location markers");
    return {
      'markers': {marker},
      'circles': {circle},
    };
  }

  /// Dispose the service (call when app closes)
  void dispose() {
    debugPrint("🌍 Disposing Global Location Service...");
    _positionStream?.cancel();
    _locationController.close();
    _isInitialized = false;
    _isTracking = false;
  }
}