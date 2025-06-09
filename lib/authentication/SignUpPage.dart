import 'package:egypttest/service/auth.dart';
import 'package:flutter/material.dart';
import 'package:egypttest/authentication/SignUpPage2.dart';
import 'dart:ui' as ui; // Import for Gradient

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final List<String> words = ["GO", "Ride", "Book", "Track"];
  double? _textHeight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 0.6).animate(  
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTextHeight();
    });
  }

  void _calculateTextHeight() {
    final style = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 80,
        ) ?? const TextStyle(fontSize: 80, fontWeight: FontWeight.bold);

    double maxHeight = 0;
    for (String word in words) {
      final textPainter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      maxHeight = maxHeight > textPainter.height ? maxHeight : textPainter.height;
    }
    setState(() {
      _textHeight = maxHeight;
      print("Measured max text height: $_textHeight"); // For debugging
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double animationHeight = screenHeight * 0.7; // Top 70%
    final double textHeight = _textHeight ?? 80;

    return Scaffold(
      body: Stack(
        children: [
          // Background Column
          Column(
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  color: theme.primaryColor.withOpacity(0.8),
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Sign Up to continue",
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "In order to continue you need to create an account",
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpPage2()),
                            );
                          },
                          child: Text(
                            "Continue with Phone Number",
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              AuthMethods().signInWithGoogle(context);
                            },
                            child: Container(
                              width: 45,
                              height: 55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey, width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22.5),
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: Image.asset("assets/images/google-logo-auth.png"),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: 45,
                              height: 55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey, width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22.5),
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: Image.asset("assets/images/apple-logo-auth.png"),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Animated Text
          Positioned.fill(
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Stack(
                    children: List.generate(words.length, (index) {
                      double rawPosition = (_animation.value + (index * 0.25)) % 1.0;
                      double topPosition = (animationHeight - textHeight - 55) * rawPosition;

                      // Stricter bounds with 55px buffer
                      double maxTop = animationHeight - textHeight - 55;
                      if (topPosition >= -textHeight && topPosition <= maxTop) {
                        return Positioned(
                          top: topPosition,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Stack(
                              children: [
                                // Stroke text (outline) with gradient
                                Text(
                                  words[index],
                                  style: theme.textTheme.displayLarge?.copyWith(
                                        foreground: Paint()
                                          ..style = PaintingStyle.stroke
                                          ..strokeWidth = 6
                                          ..shader = ui.Gradient.linear(
                                            const Offset(0, 20),
                                            const Offset(150, 20),
                                            [Colors.blue, Colors.blueAccent], // Fixed colors
                                          ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 80,
                                        wordSpacing: 30,
                                      ) ??
                                      TextStyle(
                                        foreground: Paint()
                                          ..style = PaintingStyle.stroke
                                          ..strokeWidth = 6
                                          ..shader = ui.Gradient.linear(
                                            const Offset(0, 20),
                                            const Offset(150, 20),
                                            [Colors.blue, Colors.blueAccent],
                                          ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 80,
                                        wordSpacing: 30,
                                      ),
                                ),
                                // Fill text (solid color)
                                Text(
                                  words[index],
                                  style: theme.textTheme.displayLarge?.copyWith(
                                        color: Colors.white, // Fill color
                                        fontWeight: FontWeight.bold,
                                        fontSize: 80,
                                      ) ??
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 80,
                                        wordSpacing: 30,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}