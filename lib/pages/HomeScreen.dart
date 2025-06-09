import 'dart:async';
import 'package:egypttest/pages/chat_ui.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:egypttest/pages/bus_routes_page.dart';
import 'package:egypttest/pages/wallet.dart';
import 'package:egypttest/service/search.dart';
import 'package:egypttest/service/location.dart'; // UNCOMMENT THIS IMPORT

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> googleMapCompleteController = Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  
  // Location tracking - USE GLOBAL SERVICE
  final GlobalLocationService _locationService = GlobalLocationService();
  StreamSubscription<Position>? _locationSubscription;
  Position? currentPosition;
  
  // Map elements
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  
  // UI state
  int selectedIndex = 2;
  final Color selectedColor = const Color(0xFF38B6FF);
  final Color unselectedColor = Colors.grey;
  
  // Search functionality
  String? selectedDestination;
  bool isSearchActive = false;

  @override
  void initState() {
    super.initState();
    debugPrint("🏠 HomeScreen: initState");
    _initializeLocation();
  }

  /// Initialize location service and start listening
  Future<void> _initializeLocation() async {
    debugPrint("🏠 HomeScreen: Initializing location...");
    
    // Initialize global location service
    final success = await _locationService.initialize();
    if (!success) {
      debugPrint("🏠 HomeScreen: Failed to initialize location service");
      // Fallback to simple location
      await _getLocationSimple();
      return;
    }

    // Listen to location updates from global service
    _locationSubscription = _locationService.locationStream.listen(
      (Position position) {
        debugPrint("🏠 HomeScreen: Received location update");
        _updateLocationOnMap(position);
      },
      onError: (error) {
        debugPrint("🏠 HomeScreen: Location stream error: $error");
      },
    );

    // Get current location and display immediately
    final currentPos = await _locationService.getCurrentLocationNow();
    if (currentPos != null) {
      _updateLocationOnMap(currentPos);
    }
  }

  /// Simple location getting (fallback method)
  Future<void> _getLocationSimple() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // Get location
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
        
        debugPrint("🏠 Got location: ${position.latitude}, ${position.longitude}");
        setState(() {
          currentPosition = position;
        });
        
        _updateLocationOnMap(position);
      }
    } catch (e) {
      debugPrint("🏠 Error getting location: $e");
    }
  }

  /// Update location markers and camera on map
  Future<void> _updateLocationOnMap(Position position) async {
    setState(() {
      currentPosition = position;
    });

    final LatLng latLng = LatLng(position.latitude, position.longitude);
    
    // Move camera to location
    if (controllerGoogleMap != null) {
      await controllerGoogleMap!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 15),
        ),
      );
    }

    // Use GlobalLocationService to create markers
    final locationData = await _locationService.createLocationMarkers();
    
    setState(() {
      // Clear old location markers
      _markers.removeWhere((marker) => marker.markerId.value == "userLocation");
      _circles.removeWhere((circle) => circle.circleId.value == "userLocationAccuracy");

      // Add new markers from global service
      _markers.addAll(locationData['markers']);
      _circles.addAll(locationData['circles']);
    });

    debugPrint("🏠 HomeScreen: Location markers updated");
  }

  // Search methods
  void _onLocationSelected(String location) {
    setState(() {
      selectedDestination = location;
      isSearchActive = true;
    });
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BusRoutesPage(),
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching buses to $location...'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      selectedDestination = null;
      isSearchActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: const CameraPosition(
              target: LatLng(30.0444, 31.2357), // Cairo coordinates
              zoom: 14,
            ),
            markers: _markers,
            circles: _circles,
            onMapCreated: (GoogleMapController mapController) {
              controllerGoogleMap = mapController;
              googleMapCompleteController.complete(mapController);
              debugPrint("🏠 HomeScreen: Map created");
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search functionality
                  Row(
                    children: [
                      Expanded(
                        child: SearchAutocomplete(
                          onLocationSelected: _onLocationSelected,
                          hintText: selectedDestination != null 
                              ? "Destination: $selectedDestination"
                              : "Search for your destination",
                          maxDropdownHeight: 250,
                        ),
                      ),
                      if (isSearchActive) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildIconButton(Icons.departure_board, 0),
                      _buildIconButton(Icons.groups, 1),
                      _buildIconButton(Icons.home, 2),
                      _buildIconButton(Icons.credit_card, 3),
                      _buildIconButton(Icons.more_horiz, 4),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, int index) {
    return IconButton(
      icon: Icon(icon, color: selectedIndex == index ? selectedColor : unselectedColor),
      onPressed: () {
        setState(() {
          selectedIndex = index;
        });

        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BusRoutesPage()),
          );
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatUI()),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Wallet()),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    debugPrint("🏠 HomeScreen: dispose - NOT disposing location service");
    _locationSubscription?.cancel();
    controllerGoogleMap?.dispose();
    // DON'T dispose the global location service - let it continue running
    super.dispose();
  }
}