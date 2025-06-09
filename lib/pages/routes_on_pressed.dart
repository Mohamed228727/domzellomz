import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' as mat;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:egypttest/global/bus_model.dart';
import 'package:egypttest/global/locations_var.dart';
import 'package:egypttest/global/global_var.dart';

class RoutesOnPressed {
  static Future<Map<String, dynamic>> displayRouteOnMap({
    required Bus bus,
    required Route route,
    required LocationsVar locations,
    required GoogleMapController mapController,
  }) async {
    try {
      final Set<Marker> routeMarkers = {};
      final List<LatLng> allRouteCoordinates = [];
      
      // Add bus marker
      routeMarkers.add(
        Marker(
          markerId: MarkerId('bus_${bus.busNo}'),
          position: LatLng(bus.location!.latitude, bus.location!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Bus ${bus.busNo}',
            snippet: 'Route: ${bus.routeId}',
          ),
        ),
      );
      
      // Add start location from route
      if (route.startLocation != null) {
        final startLatLng = LatLng(route.startLocation!.latitude, route.startLocation!.longitude);
        allRouteCoordinates.add(startLatLng);
        routeMarkers.add(
          Marker(
            markerId: const MarkerId('start_location'),
            position: startLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: route.startLoaction,
              snippet: 'Start Location',
            ),
          ),
        );
      }
      
      // Add stops from LocationsVar
      for (int i = 0; i < route.stops.length; i++) {
        final stopName = route.stops[i];
        final stopLocation = locations.getStopLocation(stopName);
        if (stopLocation != null) {
          LatLng stopLatLng;
          // Handle different return types from getStopLocation
          if (stopLocation.runtimeType.toString().contains('GeoPoint')) {
            final geoPoint = stopLocation as dynamic;
            stopLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
          } else {
            final geoPoint = stopLocation as GeoPoint;
            stopLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
          }
          
          allRouteCoordinates.add(stopLatLng);
          routeMarkers.add(
            Marker(
              markerId: MarkerId('stop_$i'),
              position: stopLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                title: stopName,
                snippet: 'Stop ${i + 1}',
              ),
            ),
          );
        }
      }
      
      // Add end location from route
      if (route.EndLocation != null) {
        final endLatLng = LatLng(route.EndLocation!.latitude, route.EndLocation!.longitude);
        allRouteCoordinates.add(endLatLng);
        routeMarkers.add(
          Marker(
            markerId: const MarkerId('end_location'),
            position: endLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: route.EndLoaction,
              snippet: 'End Location',
            ),
          ),
        );
      }
      
      // Get route polyline
      final Set<Polyline> routePolylines = {};
      if (allRouteCoordinates.isNotEmpty) {
        final polylinePoints = await _getRoutePolyline(
          origin: LatLng(bus.location!.latitude, bus.location!.longitude),
          destinations: allRouteCoordinates,
        );
        
        if (polylinePoints.isNotEmpty) {
          routePolylines.add(
            Polyline(
              polylineId: const PolylineId('bus_route'),
              points: polylinePoints,
              color: mat.Colors.blue,
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        }
      }
      
      // Calculate camera bounds
      final allPoints = [
        LatLng(bus.location!.latitude, bus.location!.longitude),
        ...allRouteCoordinates,
      ];
      final bounds = _calculateBounds(allPoints);
      
      // Animate camera to show entire route
      await mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
      
      return {
        'markers': routeMarkers,
        'polylines': routePolylines,
        'success': true,
      };
      
    } catch (e) {
      mat.debugPrint('Error displaying route on map: $e');
      return {
        'markers': <Marker>{},
        'polylines': <Polyline>{},
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  static Future<List<LatLng>> _getRoutePolyline({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    try {
      if (destinations.isEmpty) return [];
      
      final waypoints = destinations
          .map((dest) => '${dest.latitude},${dest.longitude}')
          .join('|');
      
      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destinations.last.latitude},${destinations.last.longitude}'
          '${destinations.length > 1 ? '&waypoints=$waypoints' : ''}'
          '&mode=driving'
          '&key=$googleMapKey';
      
      mat.debugPrint('Directions API URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      mat.debugPrint('Directions API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        mat.debugPrint('Directions API status: ${data['status']}');
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          mat.debugPrint('Got polyline data, decoding...');
          return _decodePolyline(overviewPolyline);
        } else {
          mat.debugPrint('API error: ${data['error_message'] ?? 'Unknown error'}');
        }
      }
      
      // Fallback to straight lines
      mat.debugPrint('Using straight line fallback');
      return _createStraightLineRoute(origin, destinations);
      
    } catch (e) {
      mat.debugPrint('Error getting route polyline: $e');
      return _createStraightLineRoute(origin, destinations);
    }
  }
  
  static List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;
    
    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    
    return points;
  }
  
  static List<LatLng> _createStraightLineRoute(LatLng origin, List<LatLng> destinations) {
    List<LatLng> points = [origin];
    points.addAll(destinations);
    return points;
  }
  
  static LatLngBounds _calculateBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(30.0444, 31.2357),
        northeast: const LatLng(30.0444, 31.2357),
      );
    }
    
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;
    
    for (final coord in coordinates) {
      minLat = math.min(minLat, coord.latitude);
      maxLat = math.max(maxLat, coord.latitude);
      minLng = math.min(minLng, coord.longitude);
      maxLng = math.max(maxLng, coord.longitude);
    }
    
    const padding = 0.01;
    
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }
}