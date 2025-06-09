import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:egypttest/global/bus_model.dart' as BusModel;
import 'package:egypttest/global/locations_var.dart';
import 'package:egypttest/pages/bookpage.dart';
import 'package:intl/intl.dart';

class SavedPage extends material.StatefulWidget {
  final material.VoidCallback onBackToInitial;
  final material.VoidCallback onGoToNearby;

  const SavedPage({
    super.key,
    required this.onBackToInitial,
    required this.onGoToNearby,
  });

  @override
  material.State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends material.State<SavedPage> {
  List<BusModel.Bus> savedBuses = [];
  Map<String, BusModel.Route> routeCache = {};
  bool isLoading = true;
  String? errorMessage;
  final LocationsVar locations = LocationsVar();

  @override
  void initState() {
    super.initState();
    _initializeAndLoadSavedBuses();
  }

  Future<void> _initializeAndLoadSavedBuses() async {
    await locations.initialize();
    await _loadSavedBuses();
  }

  Future<void> _loadSavedBuses() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Please log in to view saved buses';
        });
        return;
      }

      // Get user's saved bus IDs
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      List<String> savedBusIds = [];
      if (userDoc.exists && userDoc.data()!.containsKey('saved_buses')) {
        savedBusIds = List<String>.from(userDoc.data()!['saved_buses'] ?? []);
      }

      if (savedBusIds.isEmpty) {
        setState(() {
          savedBuses = [];
          isLoading = false;
        });
        return;
      }

      // Fetch the actual bus documents
      final List<BusModel.Bus> loadedBuses = [];
      
      for (String busId in savedBusIds) {
        try {
          final busDoc = await FirebaseFirestore.instance
              .collection('buses')
              .doc(busId)
              .get();
          
          if (busDoc.exists) {
            final bus = BusModel.Bus.fromMap(busDoc.data()!, busDoc.id);
            loadedBuses.add(bus);
            
            // Cache the route for this bus
            await _getRouteWithPrice(bus.routeId);
          }
        } catch (e) {
          material.debugPrint('Failed to load saved bus $busId: $e');
        }
      }

      setState(() {
        savedBuses = loadedBuses;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load saved buses: $e';
      });
    }
  }

  Future<BusModel.Route?> _getRouteWithPrice(String routeId) async {
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
      material.debugPrint('Error getting route price: $e');
    }
    return null;
  }

  Future<void> _removeBusFromSaved(String busId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'saved_buses': FieldValue.arrayRemove([busId])
      });

      // Remove from local list
      setState(() {
        savedBuses.removeWhere((bus) => bus.id == busId);
      });

      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Bus removed from saved'),
          backgroundColor: material.Colors.orange,
        ),
      );
    } catch (e) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        material.SnackBar(
          content: material.Text('Failed to remove bus: $e'),
          backgroundColor: material.Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToBusDetails(BusModel.Bus bus) async {
    final route = routeCache[bus.routeId];
    if (route != null) {
      material.Navigator.push(
        context,
        material.MaterialPageRoute(
          builder: (context) => BookPage(
            bus: bus,
            route: route,
          ),
        ),
      );
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Column(
      children: [
        // Navigation buttons
        material.Row(
          mainAxisAlignment: material.MainAxisAlignment.spaceEvenly,
          children: [
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: widget.onBackToInitial,
                  style: material.ElevatedButton.styleFrom(
                    backgroundColor: material.Colors.blue,
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text(
                    "Saved",
                    style: material.TextStyle(color: material.Colors.white),
                  ),
                ),
              ),
            ),
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: () {
                    // Navigate to recent page logic would go here
                    widget.onBackToInitial();
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
                  onPressed: widget.onGoToNearby,
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
        const material.SizedBox(height: 24),

        // Content
        if (isLoading)
          const material.Padding(
            padding: material.EdgeInsets.all(16.0),
            child: material.CircularProgressIndicator(),
          )
        else if (errorMessage != null)
          material.Padding(
            padding: const material.EdgeInsets.all(16.0),
            child: material.Column(
              children: [
                material.Text(
                  errorMessage!,
                  style: const material.TextStyle(fontSize: 16, color: material.Colors.red),
                  textAlign: material.TextAlign.center,
                ),
                const material.SizedBox(height: 16),
                material.ElevatedButton(
                  onPressed: _loadSavedBuses,
                  child: const material.Text('Retry'),
                ),
              ],
            ),
          )
        else if (savedBuses.isEmpty)
          const material.Padding(
            padding: material.EdgeInsets.all(16.0),
            child: material.Column(
              children: [
                material.Icon(
                  material.Icons.bookmark_border,
                  size: 64,
                  color: material.Colors.grey,
                ),
                material.SizedBox(height: 16),
                material.Text(
                  'No saved buses yet',
                  style: material.TextStyle(fontSize: 18, color: material.Colors.grey),
                ),
                material.SizedBox(height: 8),
                material.Text(
                  'Tap the bookmark icon on any bus to save it here',
                  style: material.TextStyle(fontSize: 14, color: material.Colors.grey),
                  textAlign: material.TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          material.Padding(
            padding: const material.EdgeInsets.all(8.0),
            child: material.Text(
              'Saved Buses (${savedBuses.length})',
              style: const material.TextStyle(fontSize: 16, fontWeight: material.FontWeight.bold),
            ),
          ),
          ...savedBuses.map((bus) => _buildSavedBusCard(bus)).toList(),
        ],
      ],
    );
  }

  material.Widget _buildSavedBusCard(BusModel.Bus bus) {
    final route = routeCache[bus.routeId];
    final price = route?.price ?? 0.0;
    
    return material.GestureDetector(
      onTap: () => _navigateToBusDetails(bus),
      child: material.Card(
        shape: material.RoundedRectangleBorder(borderRadius: material.BorderRadius.circular(12)),
        margin: const material.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                    if (route != null) ...[
                      material.Text(
                        '${route.startLoaction} → ${route.EndLoaction}',
                        style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                      ),
                    ],
                    material.Text(
                      'Seats: ${bus.remainingSeats}/${bus.capacity}',
                      style: material.TextStyle(
                        fontSize: 14,
                        color: bus.remainingSeats > 0 ? material.Colors.green : material.Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const material.SizedBox(width: 8),
              material.IconButton(
                icon: const material.Icon(material.Icons.bookmark, color: material.Colors.blue),
                onPressed: () => _removeBusFromSaved(bus.id),
                tooltip: 'Remove from saved',
              ),
            ],
          ),
        ),
      ),
    );
  }
}