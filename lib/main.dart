// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'session_manager.dart'; // Ensure this file exists and is correct

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 🔒 Lock orientation to portrait for a consistent experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 🎨 Set transparent status bar for immersive feel
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Enable full screen mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cognitive Battery',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF3F51B5),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1.0, color: Colors.white),
            headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Colors.white70),
            bodyMedium: TextStyle(fontSize: 16, color: Colors.white60, height: 1.5),
          ),
          useMaterial3: true,
        ),
        child: const LandingScreen(),
      ),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine safe area padding for top/bottom
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Deep, premium gradient background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E1B4B), // Indigo 950
              Color(0xFF312E81), // Indigo 900
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements (optional: subtle circles/glows)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.shade500.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.shade500.withOpacity(0.1),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.shade500.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.shade500.withOpacity(0.1),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 1),

                    // Logo / Icon Section
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.shade900.withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.psychology_alt_rounded,
                          size: 80,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title & Subtitle
                    Text(
                      "Cognitive\nPerformance",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Comprehensive Assessment Battery",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),

                    // Info Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 16, color: Colors.indigoAccent),
                            SizedBox(width: 8),
                            Text(
                              "~6 Minutes  •  15 Micro-Games",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Skills Grid (Context)
                    Text(
                      "ASSESSING",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _SkillItem(icon: Icons.flash_on_rounded, label: "Speed"),
                        _SkillItem(icon: Icons.lightbulb_rounded, label: "Logic"),
                        _SkillItem(icon: Icons.memory_rounded, label: "Memory"),
                        _SkillItem(icon: Icons.visibility_rounded, label: "Focus"),
                      ],
                    ),

                    const Spacer(flex: 2),

                    // CTA Button
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact(); // Subtle feedback
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SessionManager()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo.shade900,
                        elevation: 8,
                        shadowColor: Colors.indigo.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "START ASSESSMENT",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widget for Skill Icons
class _SkillItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SkillItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.indigoAccent.shade100, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}