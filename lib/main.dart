import 'package:device_preview/device_preview.dart';
import 'package:egypttest/pages/HomeScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:egypttest/authentication/SignUpPage.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: const FirebaseOptions(
      apiKey: "AIzaSyBe9CYdl4aTaMgfFPRpsDldARxzL6dsSX8",
      authDomain: "mwslaty-authentication.firebaseapp.com",
      projectId: "mwslaty-authentication",
      storageBucket: "mwslaty-authentication.firebasestorage.app",
      messagingSenderId: "67595950425",
      appId: "1:67595950425:web:7348814f3597e5dbc9d448",
      measurementId: "G-FY0PHL8DSX",
    ),
  );

  if (!kIsWeb) {
    await Permission.locationWhenInUse.isDenied.then((valueOfPermission) async {
      if (valueOfPermission) {
        await Permission.locationWhenInUse.request();
      }
    });
  }

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SignUpPage(),
    );
  }
}

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121429), // Dark navy background
  primaryColor: const Color(0xFF141A57), // Updated color
  cardColor: const Color(0xFF1E1F3B), // Card background
  textTheme: TextTheme(
    bodyLarge: const TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.grey.shade400),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1E1F3B), // Input fields color
    border: OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.circular(10),
    ),
    hintStyle: TextStyle(color: Colors.grey.shade500),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF141A57), // Updated color for buttons
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1F3B), // Match the card background
    elevation: 0,
  ),
);
