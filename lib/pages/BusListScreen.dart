import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BusListScreen extends StatelessWidget {
  const BusListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bus List")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('buses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No buses available."));
          }

          var buses = snapshot.data!.docs;

          return ListView.builder(
            itemCount: buses.length,
            itemBuilder: (context, index) {
              var bus = buses[index];
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text("Bus No: ${bus['bus_no']}"),
                  subtitle: Text("Seats: ${bus['capacity']}"),
                  trailing: Text("Driver: ${bus['driver_id']}"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
