import 'package:egypttest/authentication/OtpPage.dart';
import 'package:egypttest/authentication/finalauth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:egypttest/pages/HomeScreen.dart';
import 'package:egypttest/global/passengers_model.dart';

class AuthMethods {
  final FirebaseAuth auth = FirebaseAuth.instance;

  // Get current user
  Future<User?> getCurrentUser() async {
    return auth.currentUser;
  }

  // Google Sign-In
  Future<void> signInWithGoogle(BuildContext context) async {
    final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
    final GoogleSignIn googleSignIn = GoogleSignIn();
    
    try {
      final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
      final GoogleSignInAuthentication? googleSignInAuthentication =
          await googleSignInAccount?.authentication;

      if (googleSignInAuthentication == null) {
        print("Google Sign-in failed");
        return;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleSignInAuthentication.idToken,
        accessToken: googleSignInAuthentication.accessToken,
      );

      UserCredential result = await firebaseAuth.signInWithCredential(credential);
      User? userDetails = result.user;

      if (userDetails != null) {
        // Check if passenger already exists
        PassengerModel? existingPassenger = await PassengerModel.getPassenger(userDetails.uid);
        
        if (existingPassenger != null) {
          // Existing passenger - check if profile is complete
          if (existingPassenger.isProfileComplete) {
            // Complete profile exists, go to homepage
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const HomeScreen())
            );
          } else {
            // Missing profile details, go to finalauth
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const FinalAuth())
            );
          }
        } else {
          // New Google passenger - create passenger document
          PassengerModel newPassenger = PassengerModel.createFromGoogleAuth(
            uid: userDetails.uid,
            email: userDetails.email ?? '',
            name: userDetails.displayName ?? '',
            imgUrl: userDetails.photoURL ?? '',
          );

          // Save to Firestore
          await newPassenger.saveToFirestore();
          print("✔ Google passenger document created");
          
          // Navigate to finalauth for profile completion
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const FinalAuth())
          );
        }
      }
    } catch (e) {
      print("❌ Google Sign-in Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-in failed: ${e.toString()}")),
      );
    }
  }

  // Apple Sign-In (if you need it later)
  Future<void> signInWithApple(BuildContext context) async {
    // Similar logic to Google Sign-In
    // You can implement this when needed
  }

  // Phone Authentication with reCAPTCHA Support
  Future<void> signInWithPhoneNumber(String phoneNumber, BuildContext context) async {
    print("📱 Phone number being sent: $phoneNumber"); // Debug print
    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await auth.signInWithCredential(credential);
        print("✔ Auto Sign-in Success");
      },
      verificationFailed: (FirebaseAuthException e) {
        print("❌ Verification Failed: ${e.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification failed: ${e.message}")),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        print("📩 OTP Sent! Verification ID: $verificationId");
        print("📱 Phone number: $phoneNumber"); // Debug print
        // Navigate to OTP Page with verification ID and phone number
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpPage(
              verificationId: verificationId, 
              phoneNumber: phoneNumber
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print("⏳ Timeout: $verificationId");
      },
    );
  }
}