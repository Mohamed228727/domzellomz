import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:egypttest/service/auth.dart';

class SignUpPage2 extends StatefulWidget {
  const SignUpPage2({super.key});

  @override
  State<SignUpPage2> createState() => _SignUpPage2State();
}

class _SignUpPage2State extends State<SignUpPage2> {
  TextEditingController phoneController = TextEditingController();
  String phoneNumber = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 🔙 Back Button (Navigates Back to SignUpPage)
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 24),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            // Enter phone number
            const Text(
              "Enter phone number",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            //Subtitle
            const Text(
              "Enter your number to create an account or Log In",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // Phone Input Field with Country Selector
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IntlPhoneField(
                controller: phoneController,
                initialCountryCode: 'EG', // Default to Egypt
                decoration: const InputDecoration(
                  labelText: "01 12345678",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    phoneNumber = value.completeNumber;
                  });
                  print("📱 Complete number: ${value.completeNumber}");
                  print("📱 Country code: ${value.countryCode}");
                  print("📱 Number: ${value.number}");
                },
                onCountryChanged: (country) {
                  print("📱 Country changed: ${country.code}");
                },
              ),
            ),
            const Spacer(), // Pushes the button to the bottom
            // Continue Button
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
                onPressed: () {
                  print("📱 Button pressed with phone number: '$phoneNumber'"); 
                  print("📱 Phone number length: ${phoneNumber.length}");
                  print("📱 Phone number isEmpty: ${phoneNumber.isEmpty}");
                  
                  // Alternative way to get phone number if the first method fails
                  if (phoneNumber.isEmpty && phoneController.text.isNotEmpty) {
                    // Try to construct it manually
                    phoneNumber = "+20${phoneController.text}"; // Assuming Egypt +20
                    print("📱 Manually constructed phone: $phoneNumber");
                  }
                  
                  if (phoneNumber.isNotEmpty && phoneNumber.length > 5) {
                    print("📱 Calling AuthMethods with: $phoneNumber");
                    AuthMethods().signInWithPhoneNumber(phoneNumber, context);
                  } else {
                    print("📱 Phone number validation failed");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a valid phone number")),
                    );
                  }
                },
                child: const Text(
                  "Continue",
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