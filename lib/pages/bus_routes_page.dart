import 'dart:async';
import 'dart:convert';
import 'package:egypttest/pages/HomeScreen.dart';
import 'package:egypttest/pages/bookpage.dart';
import 'package:egypttest/pages/chat_ui.dart';
import 'package:egypttest/pages/wallet.dart';
import 'package:egypttest/pages/recent.dart';
import 'package:egypttest/pages/saved.dart';
import 'package:egypttest/service/search.dart';
import 'package:egypttest/service/location.dart';// ADD THIS IMPORT
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:egypttest/global/bus_model.dart' as BusModel;
import 'package:egypttest/global/locations_var.dart';
import 'package:egypttest/global/global_var.dart';
import 'package:egypttest/pages/routes_on_pressed.dart';
import 'package:egypttest/global/passengers_model.dart';
import 'package:egypttest/global/payment_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusRoutesPage extends material.StatefulWidget {
  const BusRoutesPage({super.key});
  @override
  material.State<BusRoutesPage> createState() => _BusRoutesPageState();
}

class _BusRoutesPageState extends material.State<BusRoutesPage> {
  final Completer<GoogleMapController> googleMapCompleteController = Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  
  // USE GLOBAL LOCATION SERVICE INSTEAD OF LOCAL MANAGEMENT
  final GlobalLocationService _locationService = GlobalLocationService();
  StreamSubscription<Position>? _locationSubscription;
  Position? currentPositionOfUser;
  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  int selectedIndex = 0;
  final material.Color selectedColor = const material.Color(0xFF38B6FF);
  final material.Color unselectedColor = material.Colors.grey;
  final material.DraggableScrollableController _sheetController = material.DraggableScrollableController();
  final material.ValueNotifier<double> _sheetSize = material.ValueNotifier<double>(0.5);
  bool _isDragging = false;
  List<BusModel.Bus> nearbyBuses = [];
  Map<String, BusModel.Route> routeCache = {};
  bool isLoadingBuses = false;
  BusModel.Bus? selectedBus;
  BusModel.Route? selectedRoute;
  List<Map<String, dynamic>> stopTimes = [];
  final LocationsVar locations = LocationsVar();
  String? apiErrorMessage;
  
  // Saved buses functionality
  Set<String> savedBusIds = {};
  bool isLoadingSavedBuses = false;
  
  // Search functionality
  String? selectedDestination;
  List<BusModel.Bus> filteredBuses = [];
  bool isSearchActive = false;
  
  // Simple state management
  String currentView = 'initial';

  @override
  void initState() {
    super.initState();
    debugPrint("🚌 BusRoutesPage: initState");
    _initializeApp();
    _loadUserSavedBuses();
    _sheetController.addListener(() {
      final newSize = _sheetController.size;
      _sheetSize.value = newSize;
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint("🚌 BusRoutesPage: didChangeDependencies");
    // Connect to global location service when entering this page
    _connectToLocationService();
  }

  /// Connect to the global location service
  Future<void> _connectToLocationService() async {
    debugPrint("🚌 BusRoutesPage: Connecting to global location service...");
    
    // Check if service is already initialized
    if (!_locationService.isInitialized) {
      debugPrint("🚌 Location service not initialized, initializing...");
      final success = await _locationService.initialize();
      if (!success) {
        debugPrint("🚌 Failed to initialize location service");
        return;
      }
    }

    // Get current location immediately
    final currentPos = _locationService.currentPosition;
    if (currentPos != null) {
      debugPrint("🚌 Using cached location from global service");
      setState(() {
        currentPositionOfUser = currentPos;
      });
      _showLocationOnMap(currentPos);
    } else {
      // Request fresh location
      final freshPos = await _locationService.getCurrentLocationNow();
      if (freshPos != null) {
        setState(() {
          currentPositionOfUser = freshPos;
        });
        _showLocationOnMap(freshPos);
      }
    }

    // Listen to location updates
    _locationSubscription?.cancel(); // Cancel any existing subscription
    _locationSubscription = _locationService.locationStream.listen(
      (Position position) {
        debugPrint("🚌 BusRoutesPage: Received location update");
        setState(() {
          currentPositionOfUser = position;
        });
        _updateLocationOnMap(position);
      },
      onError: (error) {
        debugPrint("🚌 BusRoutesPage: Location stream error: $error");
      },
    );
  }

  /// Show location on map when first loaded
  Future<void> _showLocationOnMap(Position position) async {
    if (controllerGoogleMap != null) {
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      
      // Move camera to location
      await controllerGoogleMap!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 15),
        ),
      );
    }
    
    // Add location markers
    await _updateLocationOnMap(position);
  }

  /// Update location markers on map
  Future<void> _updateLocationOnMap(Position position) async {
    // Get markers from global service
    final locationData = await _locationService.createLocationMarkers();
    
    setState(() {
      // Remove old location markers
      _markers.removeWhere((marker) => marker.markerId.value == "userLocation");
      _circles.removeWhere((circle) => circle.circleId.value == "userLocationAccuracy");
      
      // Add new location markers
      _markers.addAll(locationData['markers']);
      _circles.addAll(locationData['circles']);
    });

    debugPrint("🚌 BusRoutesPage: Location markers updated");
  }

  Future<void> _initializeApp() async {
    await locations.initialize();
    // Location is now handled by _connectToLocationService()
  }

  // Search methods
  void _onLocationSelected(String location) {
    setState(() {
      selectedDestination = location;
      isSearchActive = true;
    });
    
    _filterBusesForDestination(location);
    
    if (currentView == 'initial') {
      setState(() {
        currentView = 'buslist';
      });
    }
  }

  void _filterBusesForDestination(String destination) {
    if (nearbyBuses.isEmpty) {
      fetchBusesFromFirestore().then((_) {
        _performBusFiltering(destination);
      });
    } else {
      _performBusFiltering(destination);
    }
  }

  void _performBusFiltering(String destination) {
    setState(() {
      isLoadingBuses = true;
    });

    filteredBuses = nearbyBuses.where((bus) {
      final route = routeCache[bus.routeId];
      if (route != null) {
        final destinationLower = destination.toLowerCase();
        
        bool matchesStart = route.startLoaction?.toLowerCase().contains(destinationLower) ?? false;
        bool matchesEnd = route.EndLoaction?.toLowerCase().contains(destinationLower) ?? false;
        bool matchesStops = route.stops.any((stop) => 
            stop.toLowerCase().contains(destinationLower));
        
        return matchesStart || matchesEnd || matchesStops;
      }
      return false;
    }).toList();

    setState(() {
      isLoadingBuses = false;
    });

    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(
        content: material.Text(
          filteredBuses.isEmpty 
            ? 'No buses found for $destination' 
            : 'Found ${filteredBuses.length} buses to $destination'
        ),
        backgroundColor: filteredBuses.isEmpty ? material.Colors.orange : material.Colors.green,
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      selectedDestination = null;
      isSearchActive = false;
      filteredBuses.clear();
    });
  }

  Future<void> _loadUserSavedBuses() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && userDoc.data()!.containsKey('saved_buses')) {
          setState(() {
            savedBusIds = Set<String>.from(userDoc.data()!['saved_buses'] ?? []);
          });
        }
      }
    } catch (e) {
      material.debugPrint('Error loading saved buses: $e');
    }
  }

  Future<void> _toggleBusSaved(String busId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(content: material.Text('Please log in to save buses')),
        );
        return;
      }

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      if (savedBusIds.contains(busId)) {
        await userDocRef.update({
          'saved_buses': FieldValue.arrayRemove([busId])
        });
        setState(() {
          savedBusIds.remove(busId);
        });
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
            content: material.Text('Bus removed from saved'),
            backgroundColor: material.Colors.orange,
          ),
        );
      } else {
        await userDocRef.set({
          'saved_buses': FieldValue.arrayUnion([busId])
        }, SetOptions(merge: true));
        setState(() {
          savedBusIds.add(busId);
        });
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
            content: material.Text('Bus saved successfully'),
            backgroundColor: material.Colors.green,
          ),
        );
      }
    } catch (e) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        material.SnackBar(
          content: material.Text('Failed to save bus: $e'),
          backgroundColor: material.Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    debugPrint("🚌 BusRoutesPage: dispose - NOT disposing global location service");
    // Cancel local subscription but don't dispose global service
    _locationSubscription?.cancel();
    controllerGoogleMap?.dispose();
    _sheetController.dispose();
    _sheetSize.dispose();
    super.dispose();
  }

  String _buildDistanceMatrixUrl(String origins, String destinations) {
    return 'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${Uri.encodeComponent(origins)}'
        '&destinations=${Uri.encodeComponent(destinations)}'
        '&mode=driving'
        '&departure_time=now'
        '&key=$googleMapKey';
  }

  Future<BusModel.Route?> getRouteWithPrice(String routeId) async {
    if (routeCache.containsKey(routeId)) {
      return routeCache[routeId];
    }

    try {
      final routeQuery = await FirebaseFirestore.instance
          .collection('routes')
          .where('route_id', isEqualTo: routeId)
          .limit(1)
          .get();
      
      if (routeQuery.docs.isNotEmpty) {
        final routeDoc = routeQuery.docs.first;
        final route = BusModel.Route.fromMap(routeDoc.data(), routeDoc.id, locations);
        routeCache[routeId] = route;
        return route;
      }
    } catch (e) {
      print('Error getting route price: $e');
    }
    return null;
  }

  Future<void> fetchBusesFromFirestore() async {
    setState(() {
      isLoadingBuses = true;
      apiErrorMessage = null;
      currentView = 'buslist';
    });
    
    try {
      final snapshot = await FirebaseFirestore.instance.collection('buses').get();
      final List<BusModel.Bus> loadedBuses = [];
      
      for (var doc in snapshot.docs) {
        try {
          final bus = BusModel.Bus.fromMap(doc.data(), doc.id);
          if (bus.location != null) {
            loadedBuses.add(bus);
          }
        } catch (e) {
          material.debugPrint('Failed to parse bus ${doc.id}: $e');
        }
      }

      for (var bus in loadedBuses) {
        await getRouteWithPrice(bus.routeId);
      }

      if (loadedBuses.isNotEmpty && currentPositionOfUser != null) {
        try {
          await _fetchBusDistances(loadedBuses);
        } catch (e) {
          for (var bus in loadedBuses) {
            if (bus.location != null && currentPositionOfUser != null) {
              final distance = Geolocator.distanceBetween(
                currentPositionOfUser!.latitude,
                currentPositionOfUser!.longitude,
                bus.location!.latitude,
                bus.location!.longitude,
              );
              bus.distanceMeters = distance.toInt();
              bus.durationSeconds = (distance / 10).toInt();
            }
          }
        }
      }

      setState(() {
        nearbyBuses = loadedBuses;
        isLoadingBuses = false;
      });

      if (isSearchActive && selectedDestination != null) {
        _performBusFiltering(selectedDestination!);
      }
    } catch (e) {
      setState(() {
        isLoadingBuses = false;
        apiErrorMessage = 'Failed to load buses: $e';
      });
    }
  }

  Future<bool> canAffordTrip(double price) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        PassengerModel? passenger = await PassengerModel.getPassenger(user.uid);
        if (passenger != null) {
          return passenger.hasSufficientBalance(price);
        }
      }
    } catch (e) {
      print('Error checking balance: $e');
    }
    return false;
  }

  Future<void> _fetchBusDistances(List<BusModel.Bus> buses, {int retries = 3}) async {
    if (currentPositionOfUser == null) return;
    
    final origin = '${currentPositionOfUser!.latitude},${currentPositionOfUser!.longitude}';
    final destinations = buses
        .where((bus) => bus.location != null)
        .map((bus) => '${bus.location!.latitude},${bus.location!.longitude}')
        .join('|');
    
    if (destinations.isEmpty) return;
    
    final url = _buildDistanceMatrixUrl(origin, destinations);
    
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK') {
            final elements = data['rows'][0]['elements'];
            int index = 0;
            for (var bus in buses.where((b) => b.location != null)) {
              if (index < elements.length && elements[index]['status'] == 'OK') {
                bus.distanceMeters = elements[index]['distance']['value'];
                bus.durationSeconds = elements[index]['duration']['value'];
              }
              index++;
            }
            return;
          }
        }
        throw Exception('API request failed');
      } catch (e) {
        if (attempt == retries) {
          throw e;
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<void> fetchRouteAndTimes(BusModel.Bus bus) async {
    if (bus.location == null) return;
    
    setState(() {
      isLoadingBuses = true;
      stopTimes.clear();
      apiErrorMessage = null;
      currentView = 'busdetails';
      selectedBus = bus;
    });

    try {
      final routeQuery = await FirebaseFirestore.instance
          .collection('routes')
          .where('route_id', isEqualTo: bus.routeId)
          .limit(1)
          .get();
      
      if (routeQuery.docs.isEmpty) {
        throw Exception('Route ${bus.routeId} not found');
      }
      
      final routeDoc = routeQuery.docs.first;
      final route = BusModel.Route.fromMap(routeDoc.data(), routeDoc.id, locations);
      
      List<LatLng> routeCoordinates = [];
      
      if (route.startLocation != null) {
        routeCoordinates.add(LatLng(route.startLocation!.latitude, route.startLocation!.longitude));
      }
      
      for (final stopName in route.stops) {
        final stopLocation = locations.getStopLocation(stopName);
        if (stopLocation != null) {
          if (stopLocation is GeoPoint) {
            routeCoordinates.add(LatLng(stopLocation.latitude, stopLocation.longitude));
          } else {
            routeCoordinates.add(stopLocation as LatLng);
          }
        }
      }
      
      if (route.EndLocation != null) {
        routeCoordinates.add(LatLng(route.EndLocation!.latitude, route.EndLocation!.longitude));
      }
      
      final allRoutePoints = [route.startLoaction, ...route.stops, route.EndLoaction];
      for (int i = 0; i < allRoutePoints.length; i++) {
        stopTimes.add({
          'name': allRoutePoints[i],
          'arrival_time': DateTime.now().add(Duration(minutes: i * 5)),
          'minutes_left': i * 5,
          'distance_meters': i * 1000,
        });
      }

      setState(() {
        selectedRoute = route;
        isLoadingBuses = false;
      });
      
      if (controllerGoogleMap != null) {
        final routeResult = await RoutesOnPressed.displayRouteOnMap(
          bus: bus,
          route: route,
          locations: locations,
          mapController: controllerGoogleMap!,
        );
        
        if (routeResult['success']) {
          setState(() async {
            _markers.clear();
            _circles.clear();
            _markers.addAll(routeResult['markers']);
            _polylines.clear();
            _polylines.addAll(routeResult['polylines']);
            
            // Re-add user location when showing route
            if (currentPositionOfUser != null) {
              await _updateLocationOnMap(currentPositionOfUser!);
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoadingBuses = false;
        apiErrorMessage = 'Error fetching route: $e';
      });
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      body: material.Stack(
        children: [
          material.Positioned.fill(
            child: material.AbsorbPointer(
              absorbing: _sheetSize.value > 0.25,
              child: GoogleMap(
                mapType: MapType.normal,
                myLocationEnabled: false,       // Use custom markers from global service
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                initialCameraPosition: googleplex,
                markers: _markers,
                polylines: _polylines,
                circles: _circles,
                onMapCreated: (GoogleMapController mapController) {
                  controllerGoogleMap = mapController;
                  googleMapCompleteController.complete(mapController);
                  // Connect to location service when map is ready
                  _connectToLocationService();
                },
              ),
            ),
          ),
          material.DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.5,
            minChildSize: 0.25,
            maxChildSize: 0.96,
            snap: true,
            snapSizes: const [0.25, 0.5, 0.96],
            builder: (context, scrollController) {
              return material.NotificationListener<material.DraggableScrollableNotification>(
                onNotification: (notification) {
                  final size = notification.extent;
                  _sheetSize.value = size;
                  return false;
                },
                child: material.Container(
                  decoration: const material.BoxDecoration(
                    color: material.Colors.white,
                    borderRadius: material.BorderRadius.only(
                      topLeft: material.Radius.circular(20),
                      topRight: material.Radius.circular(20),
                    ),
                  ),
                  child: material.Column(
                    children: [
                      // Draggable handle
                      material.GestureDetector(
                        behavior: material.HitTestBehavior.opaque,
                        onTapDown: (details) {
                          setState(() {
                            _isDragging = true;
                          });
                        },
                        onVerticalDragStart: (details) {
                          // Start dragging
                        },
                        onVerticalDragUpdate: (details) {
                          final delta = details.delta.dy;
                          final screenHeight = material.MediaQuery.of(context).size.height;
                          final sizeChange = (delta / screenHeight) * 20;
                          final newSize = (_sheetController.size - sizeChange).clamp(0.25, 0.96);
                          _sheetController.jumpTo(newSize);
                          _sheetSize.value = newSize;
                          setState(() {});
                        },
                        onVerticalDragEnd: (details) {
                          setState(() {
                            _isDragging = false;
                          });
                        },
                        child: material.Container(
                          width: 60,
                          height: 12,
                          margin: const material.EdgeInsets.only(top: 8, bottom: 16),
                          decoration: material.BoxDecoration(
                            color: _isDragging ? material.Colors.red : material.Colors.grey[600],
                            borderRadius: material.BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      material.Expanded(
                        child: material.SingleChildScrollView(
                          controller: scrollController,
                          physics: const material.ClampingScrollPhysics(),
                          child: material.Padding(
                            padding: const material.EdgeInsets.symmetric(horizontal: 16.0),
                            child: material.Column(
                              children: [
                                // Search functionality
                                material.Row(
                                  children: [
                                    material.Expanded(
                                      child: SearchAutocomplete(
                                        onLocationSelected: _onLocationSelected,
                                        hintText: selectedDestination != null 
                                            ? "Destination: $selectedDestination"
                                            : "Search for your destination",
                                      ),
                                    ),
                                    if (isSearchActive) ...[
                                      const material.SizedBox(width: 8),
                                      material.IconButton(
                                        icon: const material.Icon(
                                          material.Icons.clear,
                                          color: material.Colors.grey,
                                        ),
                                        onPressed: _clearSearch,
                                        tooltip: 'Clear search',
                                      ),
                                    ]
                                  ],
                                ),
                                const material.SizedBox(height: 16),
                                
                                // Build content based on current view
                                _buildCurrentView(),
                                
                                const material.SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Bottom Navigation
          material.Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: material.Container(
              padding: const material.EdgeInsets.all(16),
              decoration: const material.BoxDecoration(
                color: material.Colors.white,
                borderRadius: material.BorderRadius.only(
                  topLeft: material.Radius.circular(20),
                  topRight: material.Radius.circular(20),
                ),
                boxShadow: [material.BoxShadow(color: material.Colors.black26, blurRadius: 8)],
              ),
              child: material.Row(
                mainAxisAlignment: material.MainAxisAlignment.spaceAround,
                children: [
                  _buildIconButton(material.Icons.departure_board, 0),
                  _buildIconButton(material.Icons.groups, 1),
                  _buildIconButton(material.Icons.home, 2),
                  _buildIconButton(material.Icons.credit_card, 3),
                  _buildIconButton(material.Icons.more_horiz, 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  material.Widget _buildCurrentView() {
    switch (currentView) {
      case 'initial':
        return _buildInitialView();
      case 'buslist':
        return _buildBusListView();
      case 'busdetails':
        return _buildBusDetailsView();
      case 'recent':
        return RecentPage(
          onBackToInitial: () {
            setState(() {
              currentView = 'initial';
            });
          },
          onGoToNearby: () {
            fetchBusesFromFirestore();
          },
        );
      case 'saved':
        return SavedPage(
          onBackToInitial: () {
            setState(() {
              currentView = 'initial';
            });
          },
          onGoToNearby: () {
            fetchBusesFromFirestore();
          },
        );
      default:
        return _buildInitialView();
    }
  }

  material.Widget _buildInitialView() {
    return material.Column(
      children: [
        // 3 buttons
        material.Row(
          mainAxisAlignment: material.MainAxisAlignment.spaceEvenly,
          children: [
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentView = 'saved';
                    });
                  },
                  style: material.ElevatedButton.styleFrom(
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text("Saved"),
                ),
              ),
            ),
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentView = 'recent';
                    });
                  },
                  style: material.ElevatedButton.styleFrom(
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text("Recent"),
                ),
              ),
            ),
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: fetchBusesFromFirestore,
                  style: material.ElevatedButton.styleFrom(
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text("Nearby"),
                ),
              ),
            ),
          ],
        ),
        if (isLoadingBuses)
          const material.Padding(
            padding: material.EdgeInsets.all(16.0),
            child: material.CircularProgressIndicator(),
          ),
      ],
    );
  }

  material.Widget _buildBusListView() {
    final busesToShow = isSearchActive ? filteredBuses : nearbyBuses;
    final titleText = isSearchActive 
        ? 'Buses to $selectedDestination (${filteredBuses.length})'
        : 'Buses loaded: ${nearbyBuses.length}';
    
    return material.Column(
      children: [
        // 3 buttons with Nearby highlighted
        material.Row(
          mainAxisAlignment: material.MainAxisAlignment.spaceEvenly,
          children: [
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentView = 'saved';
                    });
                  },
                  style: material.ElevatedButton.styleFrom(
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text("Saved"),
                ),
              ),
            ),
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentView = 'recent';
                    });
                  },
                  style: material.ElevatedButton.styleFrom(
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text("Recent"),
                ),
              ),
            ),
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: fetchBusesFromFirestore,
                  style: material.ElevatedButton.styleFrom(
                    backgroundColor: material.Colors.blue,
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text("Nearby", style: material.TextStyle(color: material.Colors.white)),
                ),
              ),
            ),
          ],
        ),
        const material.SizedBox(height: 24),
        
        if (isLoadingBuses)
          const material.Padding(
            padding: material.EdgeInsets.all(16.0),
            child: material.CircularProgressIndicator(),
          )
        else if (busesToShow.isEmpty)
          material.Padding(
            padding: const material.EdgeInsets.all(16.0),
            child: material.Text(
              isSearchActive 
                  ? 'No buses found for $selectedDestination'
                  : 'No buses found'
            ),
          )
        else ...[
          material.Padding(
            padding: const material.EdgeInsets.all(8.0),
            child: material.Text(
              titleText,
              style: const material.TextStyle(fontSize: 16, fontWeight: material.FontWeight.bold),
            ),
          ),
          ...busesToShow.map((bus) => _buildBusCard(bus)).toList(),
        ],
        
        if (apiErrorMessage != null)
          material.Padding(
            padding: const material.EdgeInsets.all(8.0),
            child: material.Column(
              children: [
                material.Text(
                  apiErrorMessage!,
                  style: const material.TextStyle(fontSize: 14, color: material.Colors.red),
                ),
                const material.SizedBox(height: 8),
                material.ElevatedButton(
                  onPressed: fetchBusesFromFirestore,
                  child: const material.Text('Retry'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  material.Widget _buildBusDetailsView() {
    return material.Column(
      children: [
        // Back arrow and Book button only
        material.Row(
          children: [
            material.IconButton(
              icon: const material.Icon(material.Icons.arrow_back),
              onPressed: () {
                setState(() async {
                  currentView = 'buslist';
                  selectedBus = null;
                  selectedRoute = null;
                  stopTimes.clear();
                  _polylines.clear();
                  _markers.clear();
                  _circles.clear();
                  // Re-add user location when going back
                  if (currentPositionOfUser != null) {
                    await _updateLocationOnMap(currentPositionOfUser!);
                  }
                });
              },
            ),
            material.Expanded(
              child: material.Center(
                child: material.ElevatedButton(
                  onPressed: () async {
                    if (selectedBus != null && selectedRoute != null) {
                      material.Navigator.push(
                        context,
                        material.MaterialPageRoute(
                          builder: (context) => BookPage(
                            bus: selectedBus!,
                            route: selectedRoute!,
                          ),
                        ),
                      );
                    }
                  },
                  style: material.ElevatedButton.styleFrom(
                    foregroundColor: material.Colors.white,
                    padding: const material.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(25),
                    ),
                  ),
                  child: material.Text(
                    selectedRoute != null 
                        ? 'Book Bus ${selectedBus?.busNo ?? ''} - ${selectedRoute!.price.toStringAsFixed(2)} EGP'
                        : 'Select Bus ${selectedBus?.busNo ?? ''}',
                    style: const material.TextStyle(fontSize: 16, fontWeight: material.FontWeight.bold),
                  ),
                ),
              ),
            ),
            const material.SizedBox(width: 48),
          ],
        ),
        
        if (isLoadingBuses)
          const material.Padding(
            padding: material.EdgeInsets.all(16.0),
            child: material.CircularProgressIndicator(),
          )
        else if (stopTimes.isEmpty)
          const material.Padding(
            padding: material.EdgeInsets.all(16.0),
            child: material.Text('No stops found'),
          )
        else
          ...stopTimes.map((stop) => _buildStopCard(
            stop['name'],
            stop['name'], 
            stop['arrival_time'],
            stop['minutes_left'],
            stop['distance_meters'],
          )).toList(),
      ],
    );
  }

  material.Widget _buildIconButton(material.IconData icon, int index) {
    return material.IconButton(
      icon: material.Icon(
        icon,
        color: selectedIndex == index ? selectedColor : unselectedColor,
      ),
      onPressed: () {
        setState(() {
          selectedIndex = index;
        });
        
        if (index == 0) {
          setState(() async {
            currentView = 'initial';
            selectedBus = null;
            selectedRoute = null;
            nearbyBuses.clear();
            stopTimes.clear();
            apiErrorMessage = null;
            _polylines.clear();
            _markers.clear();
            _circles.clear();
            _clearSearch();
            // Re-add user location when resetting
            if (currentPositionOfUser != null) {
              await _updateLocationOnMap(currentPositionOfUser!);
            }
          });
        } else if (index == 1) {
          // Navigate to chat - USE PUSH INSTEAD OF REPLACE
         Navigator.push(
            context,
            material.MaterialPageRoute(builder: (context) => const ChatUI()),
          );
        } else if (index == 2) {
          // Go back to HomeScreen instead of replacing
          Navigator.pop(context);
        } else if (index == 3) {
          // Navigate to wallet - USE PUSH INSTEAD OF REPLACE
          Navigator.push(
            context,
            material.MaterialPageRoute(builder: (context) => const Wallet()),
          );
        }
      },
    );
  }

  material.Widget _buildBusCard(BusModel.Bus bus) {
    final route = routeCache[bus.routeId];
    final price = route?.price ?? 0.0;
    final isSaved = savedBusIds.contains(bus.id);
    
    String distanceText;
    String distanceUnit;
    
    if (bus.distanceMeters != null && bus.distanceMeters! > 0) {
      if (bus.distanceMeters! >= 1000) {
        final distanceKm = (bus.distanceMeters! / 1000);
        distanceText = distanceKm.toStringAsFixed(1);
        distanceUnit = 'Km';
      } else {
        distanceText = bus.distanceMeters!.toString();
        distanceUnit = 'Meter';
      }
    } else {
      distanceText = currentPositionOfUser == null ? '?' : '0';
      distanceUnit = 'Meter';
    }
    
    final durationMin = bus.durationSeconds != null && bus.durationSeconds! > 0 
        ? (bus.durationSeconds! / 60).ceil() 
        : null;
    
    return material.GestureDetector(
      onTap: () => fetchRouteAndTimes(bus),
      child: material.Card(
        shape: material.RoundedRectangleBorder(borderRadius: material.BorderRadius.circular(12)),
        margin: const material.EdgeInsets.symmetric(vertical: 8),
        child: material.Padding(
          padding: const material.EdgeInsets.all(12.0),
          child: material.Row(
            children: [
              const material.Icon(material.Icons.directions_bus, size: 36, color: material.Colors.blue),
              const material.SizedBox(width: 12),
              material.Expanded(
                child: material.Column(
                  crossAxisAlignment: material.CrossAxisAlignment.start,
                  children: [
                    material.Text(
                      'Route: ${bus.routeId}',
                      style: const material.TextStyle(fontSize: 16, fontWeight: material.FontWeight.bold),
                    ),
                    material.Text(
                      'Bus No: ${bus.busNo}',
                      style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                    ),
                    material.Text(
                      'Price: ${price.toStringAsFixed(2)} EGP',
                      style: const material.TextStyle(
                        fontSize: 14, 
                        color: material.Colors.green,
                        fontWeight: material.FontWeight.bold,
                      ),
                    ),
                    if (durationMin != null)
                      material.Text(
                        'Time: $durationMin min',
                        style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                      )
                    else if (currentPositionOfUser == null)
                      const material.Text(
                        'Time: Enable location',
                        style: material.TextStyle(fontSize: 14, color: material.Colors.grey),
                      ),
                  ],
                ),
              ),
              material.Column(
                mainAxisSize: material.MainAxisSize.min,
                children: [
                  material.Text(
                    distanceText,
                    style: const material.TextStyle(
                      fontSize: 20,
                      fontWeight: material.FontWeight.bold,
                      color: material.Colors.white,
                    ),
                  ),
                  material.Text(
                    distanceUnit,
                    style: const material.TextStyle(
                      fontSize: 15,
                      fontWeight: material.FontWeight.bold,
                      color: material.Colors.grey,
                    ),
                  ),
                ],
              ),
              const material.SizedBox(width: 8),
              material.IconButton(
                icon: material.Icon(
                  isSaved ? material.Icons.bookmark : material.Icons.bookmark_border,
                  color: isSaved ? material.Colors.blue : material.Colors.grey,
                ),
                onPressed: () => _toggleBusSaved(bus.id),
                tooltip: isSaved ? 'Remove from saved' : 'Save bus',
              ),
            ],
          ),
        ),
      ),
    );
  }

  material.Widget _buildStopCard(String from, String to, DateTime arrivalTime, int minutesLeft, int distanceMeters) {
    final formattedTime = DateFormat('h:mm a').format(arrivalTime);
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);
    return material.Card(
      shape: material.RoundedRectangleBorder(borderRadius: material.BorderRadius.circular(12)),
      margin: const material.EdgeInsets.symmetric(vertical: 8),
      child: material.Padding(
        padding: const material.EdgeInsets.all(12.0),
        child: material.Row(
          children: [
            const material.Icon(material.Icons.location_on, size: 36, color: material.Colors.blue),
            const material.SizedBox(width: 12),
            material.Expanded(
              child: material.Column(
                crossAxisAlignment: material.CrossAxisAlignment.start,
                children: [
                  material.Text(
                    'From: $from',
                    style: const material.TextStyle(fontSize: 16, fontWeight: material.FontWeight.bold),
                  ),
                  material.Text(
                    'To: $to',
                    style: const material.TextStyle(fontSize: 16),
                  ),
                  material.Text(
                    'Time: $formattedTime',
                    style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                  ),
                  material.Text(
                    'Distance: $distanceKm km',
                    style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                  ),
                ],
              ),
            ),
            material.Text(
              '$minutesLeft min left',
              style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

const CameraPosition googleplex = CameraPosition(
  target: LatLng(30.0444, 31.2357), // Cairo coordinates
  zoom: 14,
);