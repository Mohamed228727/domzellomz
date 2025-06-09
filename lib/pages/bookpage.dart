import 'package:flutter/material.dart' as material;
import 'package:egypttest/global/bus_model.dart' as BusModel;
import 'package:egypttest/global/passengers_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:egypttest/pages/recent.dart';

class BookPage extends material.StatefulWidget {
  final BusModel.Bus bus;
  final BusModel.Route route;

  const BookPage({super.key, required this.bus, required this.route});

  @override
  material.State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends material.State<BookPage> {
  final _formKey = material.GlobalKey<material.FormState>();
  int _selectedSeat = -1; // -1 means no seat selected
  bool _isLoading = false;
  late List<int> _availableSeats; // Dynamically calculated based on capacity and currentPassengers

  @override
  void initState() {
    super.initState();
    // Use the new getAvailableSeats method from Bus model
    _availableSeats = widget.bus.getAvailableSeats();
  }

  // Check if user can afford the trip
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

  // Pay for the trip
  Future<bool> payForTrip(double price, String routeId, String busId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        PassengerModel? passenger = await PassengerModel.getPassenger(user.uid);
        if (passenger != null) {
          bool success = await passenger.deductBalance(price, routeId, busId);
          return success;
        }
      }
    } catch (e) {
      print('Error paying for trip: $e');
    }
    return false;
  }

  @override
  material.Widget build(material.BuildContext context) {
    final isBusFull = widget.bus.isFull;

    return material.Scaffold(
      appBar: material.AppBar(
        backgroundColor: material.Theme.of(context).scaffoldBackgroundColor,
        title: material.Text(
          'Book Bus ${widget.bus.busNo}',
          style: const material.TextStyle(color: material.Colors.white),
        ),
        leading: material.IconButton(
          icon: const material.Icon(material.Icons.arrow_back, color: material.Colors.white),
          onPressed: () => material.Navigator.pop(context),
        ),
        elevation: 0, // Remove shadow for seamless look
      ),
      body: material.SingleChildScrollView(
        physics: const material.ClampingScrollPhysics(),
        child: material.Padding(
          padding: const material.EdgeInsets.all(16.0),
          child: material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              // Header: Booking Summary
              material.Container(
                width: double.infinity,
                padding: const material.EdgeInsets.all(16.0),
                decoration: material.BoxDecoration(
                  border: material.Border.all(color: material.Colors.grey[300]!),
                  borderRadius: material.BorderRadius.circular(12),
                ),
                child: material.Column(
                  crossAxisAlignment: material.CrossAxisAlignment.start,
                  children: [
                    material.Text(
                      'Booking Summary',
                      style: const material.TextStyle(
                        fontSize: 20,
                        fontWeight: material.FontWeight.bold,
                      ),
                    ),
                    const material.SizedBox(height: 8),
                    material.Text(
                      '${widget.route.startLoaction} to ${widget.route.EndLoaction}',
                      style: const material.TextStyle(fontSize: 16, color: material.Colors.grey),
                    ),
                    const material.SizedBox(height: 8),
                    material.Text(
                      'Price: ${widget.route.price.toStringAsFixed(2)} EGP',
                      style: const material.TextStyle(
                        fontSize: 18,
                        color: material.Colors.green,
                        fontWeight: material.FontWeight.bold,
                      ),
                    ),
                    const material.SizedBox(height: 8),
                    material.Text(
                      'Seats Available: ${widget.bus.remainingSeats} / ${widget.bus.capacity}',
                      style: material.TextStyle(
                        fontSize: 16,
                        color: widget.bus.isFull ? material.Colors.red : material.Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const material.SizedBox(height: 16),
              // Route Details Card
              material.Card(
                shape: material.RoundedRectangleBorder(
                  borderRadius: material.BorderRadius.circular(12),
                ),
                elevation: 4,
                color: material.Theme.of(context).scaffoldBackgroundColor,
                child: material.Padding(
                  padding: const material.EdgeInsets.all(16.0),
                  child: material.Column(
                    crossAxisAlignment: material.CrossAxisAlignment.start,
                    children: [
                      material.Text(
                        'Route Details',
                        style: const material.TextStyle(
                          fontSize: 18,
                          fontWeight: material.FontWeight.bold,
                        ),
                      ),
                      const material.SizedBox(height: 8),
                      material.Row(
                        children: [
                          const material.Icon(material.Icons.location_on, color: material.Color(0xFF38B6FF)),
                          const material.SizedBox(width: 8),
                          material.Expanded(
                            child: material.Text(
                              'From: ${widget.route.startLoaction}',
                              style: const material.TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      ...widget.route.stops.map((stop) => material.Row(
                            children: [
                              const material.Icon(material.Icons.stop_circle, color: material.Colors.grey),
                              const material.SizedBox(width: 8),
                              material.Expanded(
                                child: material.Text(
                                  'Stop: $stop',
                                  style: const material.TextStyle(fontSize: 16, color: material.Colors.grey),
                                ),
                              ),
                            ],
                          )).toList(),
                      material.Row(
                        children: [
                          const material.Icon(material.Icons.location_on, color: material.Color(0xFF38B6FF)),
                          const material.SizedBox(width: 8),
                          material.Expanded(
                            child: material.Text(
                              'To: ${widget.route.EndLoaction}',
                              style: const material.TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const material.SizedBox(height: 8),
                      material.Text(
                        'Bus No: ${widget.bus.busNo}',
                        style: const material.TextStyle(fontSize: 16, color: material.Colors.grey),
                      ),
                      if (widget.bus.durationSeconds != null)
                        material.Text(
                          'Est. Duration: ${(widget.bus.durationSeconds! / 60).ceil()} min',
                          style: const material.TextStyle(fontSize: 16, color: material.Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              const material.SizedBox(height: 16),
              // Booking Form (Seat Selection Only)
              if (isBusFull)
                material.Card(
                  shape: material.RoundedRectangleBorder(
                    borderRadius: material.BorderRadius.circular(12),
                  ),
                  color: material.Colors.red.withOpacity(0.1),
                  child: const material.Padding(
                    padding: material.EdgeInsets.all(16.0),
                    child: material.Text(
                      'This bus is fully booked. Please select another bus.',
                      style: material.TextStyle(
                        fontSize: 16,
                        color: material.Colors.red,
                        fontWeight: material.FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                material.Form(
                  key: _formKey,
                  child: material.Column(
                    crossAxisAlignment: material.CrossAxisAlignment.start,
                    children: [
                      material.Text(
                        'Select Seat',
                        style: const material.TextStyle(
                          fontSize: 18,
                          fontWeight: material.FontWeight.bold,
                        ),
                      ),
                      const material.SizedBox(height: 8),
                      material.Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableSeats.map((seat) {
                          return material.ChoiceChip(
                            label: material.Text('$seat'),
                            selected: _selectedSeat == seat,
                            selectedColor: const material.Color(0xFF38B6FF),
                            backgroundColor: material.Colors.grey[200],
                            labelStyle: material.TextStyle(
                              color: _selectedSeat == seat ? material.Colors.white : material.Colors.black,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedSeat = selected ? seat : -1;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (_selectedSeat == -1 && _formKey.currentState?.validate() == false)
                        const material.Padding(
                          padding: material.EdgeInsets.only(top: 8),
                          child: material.Text(
                            'Please select a seat',
                            style: material.TextStyle(color: material.Colors.red, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              const material.SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: material.Container(
        padding: const material.EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        color: material.Theme.of(context).scaffoldBackgroundColor,
        child: material.Row(
          children: [
            if (!isBusFull)
              material.Expanded(
                child: material.ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate() && _selectedSeat != -1) {
                            // Show payment confirmation dialog
                            bool? confirmPayment = await material.showDialog<bool>(
                              context: context,
                              builder: (context) => material.AlertDialog(
                                title: const material.Text('Confirm Payment'),
                                content: material.Text(
                                  'Confirm booking for:\n\nBus: ${widget.bus.busNo}\nSeat: $_selectedSeat\nRoute: ${widget.route.startLoaction} → ${widget.route.EndLoaction}\n\nTotal Amount: ${widget.route.price.toStringAsFixed(2)} EGP\n\nProceed with payment?'
                                ),
                                actions: [
                                  material.TextButton(
                                    onPressed: () => material.Navigator.pop(context, false),
                                    child: const material.Text('Cancel'),
                                  ),
                                  material.ElevatedButton(
                                    onPressed: () => material.Navigator.pop(context, true),
                                    child: const material.Text('Pay Now'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmPayment == true) {
                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                // Check if user can afford the trip
                                bool canAfford = await canAffordTrip(widget.route.price);
                                
                                if (!canAfford) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                  material.ScaffoldMessenger.of(context).showSnackBar(
                                    material.SnackBar(
                                      content: material.Text('Insufficient balance. You need ${widget.route.price.toStringAsFixed(2)} EGP'),
                                      backgroundColor: material.Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // Process payment
                                bool paymentSuccess = await payForTrip(
                                  widget.route.price,
                                  widget.bus.routeId,
                                  widget.bus.id,
                                );

                                if (!paymentSuccess) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                  material.ScaffoldMessenger.of(context).showSnackBar(
                                    const material.SnackBar(
                                      content: material.Text('Payment failed. Please try again.'),
                                      backgroundColor: material.Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // Use a batch write to update both bus passenger count and booked seats atomically
                                WriteBatch batch = FirebaseFirestore.instance.batch();
                                
                                // Update bus passenger count and booked seats
                                final busRef = FirebaseFirestore.instance.collection('buses').doc(widget.bus.id);
                                batch.update(busRef, {
                                  'current_passengers': widget.bus.currentPassengers + 1,
                                  'booked_seats': FieldValue.arrayUnion([_selectedSeat]),
                                });

                                // Commit the bus updates
                                await batch.commit();

                                // Create reservation using ReservationService
                                bool reservationCreated = await ReservationService.createReservation(
                                  busNo: widget.bus.busNo,
                                  routeId: widget.route.routeId,
                                  seatNumber: _selectedSeat,
                                  destination: widget.route.EndLoaction,
                                );
                                
                                if (!reservationCreated) {
                                  material.debugPrint('Failed to create reservation');
                                  // Note: Even if reservation creation fails, the seat is already booked
                                  // Consider adding rollback logic here if needed
                                }

                                setState(() {
                                  _isLoading = false;
                                });

                                material.ScaffoldMessenger.of(context).showSnackBar(
                                  material.SnackBar(
                                    content: material.Text(
                                      'Booking confirmed! Bus ${widget.bus.busNo}, Seat $_selectedSeat. Payment of ${widget.route.price.toStringAsFixed(2)} EGP processed.',
                                    ),
                                    backgroundColor: material.Colors.green,
                                  ),
                                );
                                material.Navigator.pop(context);
                              } catch (e) {
                                setState(() {
                                  _isLoading = false;
                                });
                                material.ScaffoldMessenger.of(context).showSnackBar(
                                  material.SnackBar(
                                    content: material.Text('Booking failed: $e'),
                                    backgroundColor: material.Colors.red,
                                  ),
                                );
                              }
                            }
                          } else if (_selectedSeat == -1) {
                            material.ScaffoldMessenger.of(context).showSnackBar(
                              const material.SnackBar(content: material.Text('Please select a seat')),
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
                  child: _isLoading
                      ? const material.CircularProgressIndicator(color: material.Colors.white)
                      : const material.Text(
                          'Confirm Booking',
                          style: material.TextStyle(
                            fontSize: 16,
                            fontWeight: material.FontWeight.bold,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}