import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:egypttest/pages/HomeScreen.dart';
import 'package:egypttest/global/passengers_model.dart';

class FinalAuth extends StatefulWidget {
  const FinalAuth({super.key});

  @override
  State<FinalAuth> createState() => _FinalAuthState();
}

class _FinalAuthState extends State<FinalAuth> {
  final TextEditingController fnameController = TextEditingController();
  final TextEditingController lnameController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;
  
  String selectedGender = '';
  bool isLoading = false;

  void completeProfile() async {
    setState(() {
      isLoading = true;
    });

    String firstName = fnameController.text.trim();
    String lastName = lnameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      User? user = auth.currentUser;
      if (user != null) {
        // Get existing passenger document
        PassengerModel? existingPassenger = await PassengerModel.getPassenger(user.uid);
        
        if (existingPassenger == null) {
          print("❌ No existing passenger found");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session error. Please try logging in again.')),
          );
          setState(() {
            isLoading = false;
          });
          return;
        }

        print("📱 Existing passenger data: ${existingPassenger.toFirestore()}");
        print("📱 Phone number from existing: '${existingPassenger.phoneNumber}'");

        // Complete the profile with personal details
        PassengerModel completedPassenger = existingPassenger.completeProfile(
          firstName: firstName,
          lastName: lastName,
          gender: selectedGender,
        );

        print("📱 Completed passenger data: ${completedPassenger.toFirestore()}");

        // Save the completed profile
        await completedPassenger.saveToFirestore();
        
        // Verify the document was updated
        PassengerModel? verifyPassenger = await PassengerModel.getPassenger(user.uid);
        print("✔ Updated passenger document: ${verifyPassenger?.toFirestore()}");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile completed successfully!')),
        );

        // Navigate to HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      print("❌ Error completing passenger profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
            // Complete Your Profile
            const Text(
              "Complete Your Profile",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            const Text(
              "Please provide your information to continue",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // First Name Field
            TextField(
              controller: fnameController,
              decoration: const InputDecoration(
                labelText: "First Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),

            // Last Name Field
            TextField(
              controller: lnameController,
              decoration: const InputDecoration(
                labelText: "Last Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),

            // Gender Selection
            const Text(
              "Gender",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedGender = 'Male';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedGender == 'Male' 
                              ? const Color(0xFF141A57) 
                              : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedGender == 'Male' 
                            ? const Color(0xFF141A57).withOpacity(0.1) 
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.male,
                            color: selectedGender == 'Male' 
                                ? const Color(0xFF141A57) 
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Male",
                            style: TextStyle(
                              color: selectedGender == 'Male' 
                                  ? const Color(0xFF141A57) 
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedGender = 'Female';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedGender == 'Female' 
                              ? const Color(0xFF141A57) 
                              : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedGender == 'Female' 
                            ? const Color(0xFF141A57).withOpacity(0.1) 
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.female,
                            color: selectedGender == 'Female' 
                                ? const Color(0xFF141A57) 
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Female",
                            style: TextStyle(
                              color: selectedGender == 'Female' 
                                  ? const Color(0xFF141A57) 
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(), // Pushes the button to the bottom

            // Complete Profile Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141A57),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading ? null : completeProfile,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Complete Profile",
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