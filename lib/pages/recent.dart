import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Static class for reservation operations
class ReservationService {
  static Future<bool> createReservation({
    required String busNo,
    required String routeId,
    required int seatNumber,
    required String destination,
    DateTime? departureTime,
  }) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Start a batch write to ensure both operations succeed together
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create the reservation
      final reservationRef = FirebaseFirestore.instance.collection('reservations').doc();
      
      batch.set(reservationRef, {
        'bus_id': busNo,
        'departure_time': Timestamp.fromDate(departureTime ?? DateTime.now().add(const Duration(hours: 1))),
        'destination': destination,
        'passenger_id': user.uid,
        'reservation_date': Timestamp.fromDate(DateTime.now()),
        'reservation_id': reservationRef.id,
        'route_id': routeId,
        'seat_number': seatNumber,
        'status': 'confirmed',
      });

      // 2. Find and update the bus document's booked_seats
      final busQuery = await FirebaseFirestore.instance
          .collection('buses')
          .where('bus_no', isEqualTo: busNo)
          .limit(1)
          .get();

      if (busQuery.docs.isNotEmpty) {
        final busDoc = busQuery.docs.first;
        final busRef = FirebaseFirestore.instance.collection('buses').doc(busDoc.id);
        
        // Add the seat to the booked_seats array
        batch.update(busRef, {
          'booked_seats': FieldValue.arrayUnion([seatNumber])
        });
      } else {
        material.debugPrint('Warning: Bus with bus_no $busNo not found');
        // Continue anyway - the reservation will still be created
      }

      // Commit both operations together
      await batch.commit();
      
      return true;
    } catch (e) {
      material.debugPrint('Error creating reservation: $e');
      return false;
    }
  }
}

class RecentPage extends material.StatefulWidget {
  final material.VoidCallback onBackToInitial;
  final material.VoidCallback onGoToNearby;

  const RecentPage({
    super.key, 
    required this.onBackToInitial,
    required this.onGoToNearby,
  });

  @override
  material.State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends material.State<RecentPage> {
  List<Map<String, dynamic>> recentBookings = [];
  bool isLoadingRecent = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchRecentBookings();
  }

  Future<void> fetchRecentBookings() async {
    setState(() {
      isLoadingRecent = true;
      errorMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Simplified query - only filter by passenger_id
        final snapshot = await FirebaseFirestore.instance
            .collection('reservations')
            .where('passenger_id', isEqualTo: user.uid)
            .get();

        final List<Map<String, dynamic>> loadedBookings = [];
        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          loadedBookings.add(data);
        }

        // Sort by reservation_date in memory (newest first)
        loadedBookings.sort((a, b) {
          final aDate = a['reservation_date'] as Timestamp?;
          final bDate = b['reservation_date'] as Timestamp?;
          
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          
          return bDate.compareTo(aDate); // Descending order (newest first)
        });

        // Take only the first 10 results
        final limitedBookings = loadedBookings.take(10).toList();

        setState(() {
          recentBookings = limitedBookings;
          isLoadingRecent = false;
        });
      } else {
        setState(() {
          isLoadingRecent = false;
          errorMessage = 'Please log in to view bookings';
        });
      }
    } catch (e) {
      setState(() {
        isLoadingRecent = false;
        errorMessage = 'Error loading bookings: $e';
      });
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Column(
      children: [
        // 3 buttons with Recent highlighted
        material.Row(
          mainAxisAlignment: material.MainAxisAlignment.spaceEvenly,
          children: [
            material.Expanded(
              child: material.Container(
                margin: const material.EdgeInsets.symmetric(horizontal: 4),
                child: material.ElevatedButton(
                  onPressed: widget.onBackToInitial,
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
                  onPressed: fetchRecentBookings,
                  style: material.ElevatedButton.styleFrom(
                    backgroundColor: material.Colors.blue,
                    shape: material.RoundedRectangleBorder(
                      borderRadius: material.BorderRadius.circular(50),
                    ),
                  ),
                  child: const material.Text("Recent", style: material.TextStyle(color: material.Colors.white)),
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
        
        // Content based on loading state
        if (isLoadingRecent)
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
                  onPressed: fetchRecentBookings,
                  child: const material.Text('Retry'),
                ),
              ],
            ),
          )
        else if (recentBookings.isEmpty)
          const material.Padding(
            padding: material.EdgeInsets.all(16.0),
            child: material.Column(
              children: [
                material.Icon(
                  material.Icons.history,
                  size: 64,
                  color: material.Colors.grey,
                ),
                material.SizedBox(height: 16),
                material.Text(
                  'No recent bookings found',
                  style: material.TextStyle(
                    fontSize: 18,
                    color: material.Colors.grey,
                    fontWeight: material.FontWeight.bold,
                  ),
                ),
                material.SizedBox(height: 8),
                material.Text(
                  'Your booking history will appear here',
                  style: material.TextStyle(
                    fontSize: 14,
                    color: material.Colors.grey,
                  ),
                ),
              ],
            ),
          )
        else
          material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              material.Padding(
                padding: const material.EdgeInsets.symmetric(horizontal: 8.0),
                child: material.Text(
                  'Recent Bookings (${recentBookings.length})',
                  style: const material.TextStyle(
                    fontSize: 18,
                    fontWeight: material.FontWeight.bold,
                  ),
                ),
              ),
              const material.SizedBox(height: 16),
              ...recentBookings.map((booking) => _buildBookingCard(booking)).toList(),
            ],
          ),
      ],
    );
  }

  material.Widget _buildBookingCard(Map<String, dynamic> booking) {
    final reservationDate = booking['reservation_date'] != null 
        ? (booking['reservation_date'] as Timestamp).toDate()
        : DateTime.now();
    final departureTime = booking['departure_time'] != null
        ? (booking['departure_time'] as Timestamp).toDate()
        : DateTime.now();
    
    final formattedDate = DateFormat('MMM dd, yyyy').format(reservationDate);
    final formattedTime = DateFormat('h:mm a').format(departureTime);
    
    return material.Card(
      shape: material.RoundedRectangleBorder(
        borderRadius: material.BorderRadius.circular(12),
      ),
      margin: const material.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 3,
      child: material.Padding(
        padding: const material.EdgeInsets.all(16.0),
        child: material.Column(
          crossAxisAlignment: material.CrossAxisAlignment.start,
          children: [
            material.Row(
              mainAxisAlignment: material.MainAxisAlignment.spaceBetween,
              children: [
                material.Text(
                  'Bus ${booking['bus_id'] ?? 'Unknown'}',
                  style: const material.TextStyle(
                    fontSize: 18,
                    fontWeight: material.FontWeight.bold,
                  ),
                ),
                material.Container(
                  padding: const material.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: material.BoxDecoration(
                    color: material.Colors.green.withOpacity(0.1),
                    borderRadius: material.BorderRadius.circular(20),
                    border: material.Border.all(color: material.Colors.green, width: 1),
                  ),
                  child: material.Text(
                    (booking['status'] ?? 'CONFIRMED').toString().toUpperCase(),
                    style: const material.TextStyle(
                      fontSize: 12,
                      fontWeight: material.FontWeight.bold,
                      color: material.Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const material.SizedBox(height: 12),
            
            material.Row(
              children: [
                const material.Icon(material.Icons.event_seat, color: material.Color(0xFF38B6FF), size: 20),
                const material.SizedBox(width: 8),
                material.Text(
                  'Seat ${booking['seat_number'] ?? 'N/A'}',
                  style: const material.TextStyle(fontSize: 16, fontWeight: material.FontWeight.w500),
                ),
              ],
            ),
            const material.SizedBox(height: 8),
            
            material.Row(
              children: [
                const material.Icon(material.Icons.location_on, color: material.Color(0xFF38B6FF), size: 20),
                const material.SizedBox(width: 8),
                material.Expanded(
                  child: material.Text(
                    'To: ${booking['destination'] ?? 'Unknown'}',
                    style: const material.TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const material.SizedBox(height: 8),
            
            material.Row(
              children: [
                const material.Icon(material.Icons.route, color: material.Colors.grey, size: 20),
                const material.SizedBox(width: 8),
                material.Text(
                  'Route: ${booking['route_id'] ?? 'Unknown'}',
                  style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                ),
              ],
            ),
            const material.SizedBox(height: 8),
            
            material.Row(
              children: [
                const material.Icon(material.Icons.access_time, color: material.Colors.grey, size: 20),
                const material.SizedBox(width: 8),
                material.Text(
                  'Departure: $formattedTime',
                  style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                ),
              ],
            ),
            const material.SizedBox(height: 4),
            
            material.Row(
              children: [
                const material.Icon(material.Icons.calendar_today, color: material.Colors.grey, size: 20),
                const material.SizedBox(width: 8),
                material.Text(
                  'Booked: $formattedDate',
                  style: const material.TextStyle(fontSize: 14, color: material.Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}