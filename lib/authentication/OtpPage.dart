import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:egypttest/pages/HomeScreen.dart';
import 'package:egypttest/authentication/finalauth.dart';
import 'package:egypttest/global/passengers_model.dart';

class OtpPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpPage({super.key, required this.verificationId, required this.phoneNumber});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;
  bool isLoading = false;

  void verifyOtp() async {
    setState(() {
      isLoading = true;
    });

    String smsCode = otpController.text.trim();

    if (smsCode.length == 6) {
      try {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: smsCode,
        );

        // Sign in user
        UserCredential result = await auth.signInWithCredential(credential);
        User? user = result.user;

        if (user != null) {
          print("📱 OTP verified for user: ${user.uid}");
          print("📱 Phone number from widget: '${widget.phoneNumber}'");
          
          // Check if passenger already exists
          PassengerModel? existingPassenger = await PassengerModel.getPassenger(user.uid);
          
          if (existingPassenger != null) {
            // Passenger exists, check if profile is complete
            if (existingPassenger.isProfileComplete) {
              // Complete profile exists, go to homepage
              print("✔ Passenger has complete profile, navigating to HomeScreen");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome back!')),
              );
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else {
              // Passenger exists but profile incomplete, go to finalauth
              print("✔ Passenger exists but profile incomplete, navigating to FinalAuth");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please complete your profile')),
              );
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const FinalAuth()),
              );
            }
          } else {
            // New passenger - create passenger document with phone number
            print("📱 Creating new passenger document");
            print("📱 Storing phone number: '${widget.phoneNumber}'");
            
            PassengerModel newPassenger = PassengerModel.createFromPhoneAuth(
              uid: user.uid,
              phoneNumber: widget.phoneNumber,
            );

            // Save to Firestore
            await newPassenger.saveToFirestore();
            print("✔ Passenger document created successfully");
            
            // Verify the document was created correctly
            PassengerModel? verifyPassenger = await PassengerModel.getPassenger(user.uid);
            print("📱 Verification - Passenger data: ${verifyPassenger?.toFirestore()}");
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP Verified! Please complete your profile')),
            );

            // Navigate to FinalAuth for new passengers
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FinalAuth()),
            );
          }
        }
      } catch (e) {
        print("❌ OTP Verification Failed: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 🔙 Back Button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 24),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),

            // Enter OTP
            const Text(
              "Enter OTP",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            // Subtitle
            Text(
              "Enter the OTP sent to ${widget.phoneNumber}",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // OTP Input Field
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Enter OTP",
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            const Spacer(), // Pushes the button to the bottom

            // Verify OTP Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141A57), // Updated color
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading ? null : verifyOtp,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Verify OTP",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}