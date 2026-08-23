// Import Flutter UI package
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:TrakOn/screens/main_navigation_screen.dart';
//import 'package:TrakOn/screens/main_navigation_screen.dart';

//import 'screens/mfa_screen.dart';
//import 'screens/tutorial_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'screens/notification_service.dart';

import 'screens/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
//import 'package:firebase_core/firebase_core.dart';
//import 'package:firebase_auth/firebase_auth.dart';
//import 'firebase_options.dart';

// import 'screens/email_verification_screen.dart';
import 'screens/phone_verification_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'screens/email_otp_screen.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

// Entry point of the app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check is currently configured for the Apple/iOS build.
  // Skip it on Chrome until TrakOn's web App Check provider is configured.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerApple: const AppleDebugProvider(),
    );
  }

  await NotificationService.init();
  await NotificationService.requestPermissions();

  // Show a notification

  final prefs = await SharedPreferences.getInstance();

  // await prefs.setBool('hasSeenOnboarding', false);

  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  debugPrint('isLoggedIn: $isLoggedIn');
  debugPrint('hasSeenOnboarding: $hasSeenOnboarding');

  runApp(MyApp(hasSeenOnboarding: hasSeenOnboarding, isLoggedIn: isLoggedIn));
}

// Root widget of the app
class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  final bool isLoggedIn;
  const MyApp({
    super.key,
    required this.hasSeenOnboarding,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        brightness: Brightness.dark, // ** IMPORTANT

        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        dialogTheme: const DialogThemeData(backgroundColor: Colors.black),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),

        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white),
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}

// ---------------------------
// Welcome Screen (Logo + Animation + Button)
// ---------------------------
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  String displayedText = '';

  bool showTrack = false;
  bool showFocus = false;
  bool showAchieve = false;
  bool showButton = false;

  final String welcomeText = 'Welcome To TrakOn';

  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    // Controls the TrakOn logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo smoothly fades in
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    );

    // Logo gently grows into place
    _logoScale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    startIntroAnimation();
  }

  Future<void> startIntroAnimation() async {
    // Show the logo first
    await _logoController.forward();

    // Small pause after logo finishes
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // Then begin Welcome To TrakOn
    startTypewriterAnimation();
  }

  void startTypewriterAnimation() {
    int currentIndex = 0;

    // Same typing speed you already had
    Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (currentIndex < welcomeText.length) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          displayedText += welcomeText[currentIndex];
        });

        currentIndex++;
      } else {
        timer.cancel();

        // Track appears after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;

          setState(() {
            showTrack = true;
          });
        });

        // Focus appears after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;

          setState(() {
            showFocus = true;
          });
        });

        // Achieve appears after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (!mounted) return;

          setState(() {
            showAchieve = true;
          });
        });

        // Button appears after 7 seconds
        Future.delayed(const Duration(seconds: 7), () {
          if (!mounted) return;

          setState(() {
            showButton = true;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TrakOn Logo
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    'assets/TrakOn_logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Welcome text
              Text(
                displayedText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Animated Motto
              AnimatedOpacity(
                opacity: showTrack || showFocus || showAchieve ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showTrack)
                      const Text(
                        'Track.',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),

                    if (showFocus)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          'Focus.',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ),

                    if (showAchieve)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          'Achieve.',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Fade in button when ready
              AnimatedOpacity(
                opacity: showButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),

                child: showButton
                    ? SizedBox(
                        width: double.infinity,
                        height: 55,

                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),

                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();

                            bool isLoggedIn =
                                prefs.getBool('isLoggedIn') ?? false;

                            if (!context.mounted) return;

                            if (isLoggedIn) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MainNavigationScreen(),
                                ),
                              );
                            } else {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AuthChoiceScreen(),
                                ),
                              );
                            }
                          },

                          child: const Text(
                            "Let's get you Started!",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------
// Screen: Choose Login or Create Account
// ---------------------------
class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text('Get Started'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Lets get you started',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 30),

            // CREATE ACCOUNT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  // Go to Create Account screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CreateAccountScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // LOGIN BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  // Go to Login screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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

// ---------------------------
// Create Account Screen
// ---------------------------
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  // Used for validating form
  final _formKey = GlobalKey<FormState>();

  // Controllers store user input
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final usernameController = TextEditingController();
  final dobController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    dobController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (useEmail) {
      await createEmailAccount();
    } else {
      await startPhoneAccount();
    }
  }

  Future<void> startPhoneAccount() async {
    String phoneNumber = phoneController.text.trim();

    // A new signup must start with a clean Firebase Auth session.
    // This prevents a previously authenticated account from carrying
    // into the new phone-account creation flow.
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }

    // Also clear TrakOn's local login flag for the new signup.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    // Make sure this screen still exists after the async operations above.
    if (!mounted) return;

    // Remove common formatting characters
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Automatically format a 10-digit US number
    if (RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
      phoneNumber = '+1$phoneNumber';
    }

    // If user typed 1 + 10 digits, add the +
    if (RegExp(r'^1\d{10}$').hasMatch(phoneNumber)) {
      phoneNumber = '+$phoneNumber';
    }

    if (!phoneNumber.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhoneVerificationScreen(
          phoneNumber: phoneNumber,
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
          username: usernameController.text.trim(),
          dateOfBirth: dobController.text.trim(),
          password: passwordController.text,
        ),
      ),
    );
  }

  Future<void> createEmailAccount() async {
    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;

      if (user == null) {
        throw Exception('Account could not be created.');
      }

      final fullName =
          '${firstNameController.text.trim()} ${lastNameController.text.trim()}';

      await user.updateDisplayName(fullName);

      final callable = FirebaseFunctions.instance.httpsCallable('sendEmailOtp');

      await callable.call({'email': email});

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => EmailOtpScreen(
            email: email,
            firstName: firstNameController.text.trim(),
            lastName: lastNameController.text.trim(),
            username: usernameController.text.trim(),
            dateOfBirth: dobController.text.trim(),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Unable to create account.';

      if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Please choose a stronger password.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      debugPrint('FUNCTION ERROR CODE: ${e.code}');
      debugPrint('FUNCTION ERROR MESSAGE: ${e.message}');
      debugPrint('FUNCTION ERROR DETAILS: ${e.details}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Function error: ${e.message ?? e.code}')),
      );
    } catch (e) {
      debugPrint('GENERAL ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  bool useEmail = true;
  bool obscurePassword = true;

  // Check if password has special character
  bool hasSpecialCharacter(String value) {
    final regex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
    return regex.hasMatch(value);
  }

  // Opens a date picker when the user taps the DOB field
  Future<void> selectDateOfBirth() async {
    DateTime selectedDate = DateTime(2000, 1, 1);

    // If the text field already has a date, try to use it first
    if (dobController.text.isNotEmpty) {
      final parts = dobController.text.split('/');
      if (parts.length == 3) {
        final month = int.tryParse(parts[0]);
        final day = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (month != null && day != null && year != null) {
          selectedDate = DateTime(year, month, day);
        }
      }
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        DateTime tempPickedDate = selectedDate;

        return SizedBox(
          height: 300,
          child: Column(
            children: [
              // Top action bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final month = tempPickedDate.month.toString().padLeft(
                          2,
                          '0',
                        );
                        final day = tempPickedDate.day.toString().padLeft(
                          2,
                          '0',
                        );
                        final year = tempPickedDate.year.toString();

                        setState(() {
                          dobController.text = '$month/$day/$year';
                        });

                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white24, height: 1),

              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: selectedDate,
                    minimumDate: DateTime(1900),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (DateTime newDate) {
                      tempPickedDate = newDate;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // First Name
                TextFormField(
                  controller: firstNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Last Name
                TextFormField(
                  controller: lastNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Example: jbok24',
                    labelStyle: TextStyle(color: Colors.white),
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a username';
                    }
                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // DOB FIELD
                // User taps this field to open the date picker
                TextFormField(
                  controller: dobController,
                  style: const TextStyle(color: Colors.white),
                  readOnly: true,
                  onTap: selectDateOfBirth,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'MM/DD/YYYY',
                    hintStyle: TextStyle(color: Colors.white54),
                    labelStyle: TextStyle(color: Colors.white),
                    suffixIcon: Icon(Icons.calendar_today, color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your date of birth';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign up with',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      height: 42,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                useEmail = true;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 90,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: useEmail
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'Email',
                                style: TextStyle(
                                  color: useEmail
                                      ? Colors.black
                                      : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          GestureDetector(
                            onTap: () {
                              setState(() {
                                useEmail = false;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 90,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: !useEmail
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'Phone',
                                style: TextStyle(
                                  color: !useEmail
                                      ? Colors.black
                                      : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // EMAIL or Phone FIELD
                if (useEmail)
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'example@email.com',
                      labelStyle: TextStyle(color: Colors.white),
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (useEmail && (value == null || value.trim().isEmpty)) {
                        return 'Enter your email';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+1 555 555 5555',
                      labelStyle: TextStyle(color: Colors.white),
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (!useEmail &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Enter your phone number';
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.white),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 7) {
                      return 'Minimum 7 characters';
                    }

                    if (!hasSpecialCharacter(value)) {
                      return 'Add a special character';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // SUBMIT BUTTON
                ElevatedButton(
                  onPressed: submitForm,
                  child: const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------
// Login Screen
// ---------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final loginController = TextEditingController();
  final passwordController = TextEditingController();

  bool rememberMe = true;
  bool obscurePassword = true;

  Future<void> loginUser() async {
    final loginInput = loginController.text.trim();
    final passwordInput = passwordController.text;

    if (loginInput.isEmpty || passwordInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your username/email/phone and password.'),
        ),
      );
      return;
    }

    try {
      String resolvedType;
      String? resolvedEmail;
      String? resolvedPhone;

      if (loginInput.contains('@')) {
        resolvedType = 'email';
        resolvedEmail = loginInput;
      } else if (RegExp(r'^[\d\+\-\(\)\s]+$').hasMatch(loginInput)) {
        resolvedType = 'phone';
        resolvedPhone = loginInput;
      } else {
        final resolver = FirebaseFunctions.instance.httpsCallable(
          'resolveUsername',
        );

        final result = await resolver.call({'username': loginInput});

        resolvedType = result.data['authMethod'];
        resolvedEmail = result.data['email'];
        resolvedPhone = result.data['phoneNumber'];
      }

      if (resolvedType == 'email') {
        if (resolvedEmail == null) {
          throw Exception('Email account could not be resolved.');
        }

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: resolvedEmail,
          password: passwordInput,
        );
      } else if (resolvedType == 'phone') {
        if (resolvedPhone == null) {
          throw Exception('Phone account could not be resolved.');
        }

        String phoneNumber = resolvedPhone;

        phoneNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

        if (RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
          phoneNumber = '+1$phoneNumber';
        } else if (RegExp(r'^1\d{10}$').hasMatch(phoneNumber)) {
          phoneNumber = '+$phoneNumber';
        }

        final callable = FirebaseFunctions.instance.httpsCallable(
          'loginWithPhonePassword',
        );

        final result = await callable.call({
          'phoneNumber': phoneNumber,
          'password': passwordInput,
        });

        final customToken = result.data['customToken'];

        if (customToken == null) {
          throw Exception('Login token was not returned.');
        }

        await FirebaseAuth.instance.signInWithCustomToken(customToken);
      } else {
        throw Exception('Unsupported authentication method.');
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('rememberMe', rememberMe);

      await prefs.setBool('isLoggedIn', rememberMe);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Incorrect username/email/phone or password.';

      if (e.code == 'invalid-email') {
        message = 'Enter a valid email address.';
      } else if (e.code == 'user-not-found') {
        message = 'No account was found.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect login information.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message = e.message ?? 'Unable to log in.';

      if (e.code == 'not-found') {
        message = 'No account was found.';
      } else if (e.code == 'unauthenticated') {
        message = 'Incorrect login information.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: loginController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Username, Email, or Phone',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ForgotUsernameScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Username?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  activeColor: Colors.greenAccent,
                  checkColor: Colors.black,
                  onChanged: (value) {
                    setState(() {
                      rememberMe = value ?? true;
                    });
                  },
                ),
                const Text(
                  'Remember Me',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loginUser,
                child: const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------
// Forget Password Screen
// ---------------------------

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();

  bool sending = false;

  Future<void> sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    setState(() {
      sending = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = e.message ?? 'Unable to send reset email.';

      if (e.code == 'user-not-found') {
        message = 'No account was found with that email.';
      } else if (e.code == 'invalid-email') {
        message = 'Enter a valid email address.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Reset your password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter the email address linked to your TrakOn account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: sending ? null : sendResetEmail,
                  child: Text(sending ? 'Sending...' : 'Send Reset Email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------
// Forgot Username Screen
// ---------------------------
class ForgotUsernameScreen extends StatefulWidget {
  const ForgotUsernameScreen({super.key});

  @override
  State<ForgotUsernameScreen> createState() => _ForgotUsernameScreenState();
}

class _ForgotUsernameScreenState extends State<ForgotUsernameScreen> {
  final emailController = TextEditingController();

  bool sending = false;

  Future<void> sendUsernameReminder() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    setState(() {
      sending = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendUsernameReminder',
      );

      await callable.call({'email': email});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists with that email, '
            'a username reminder has been sent.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unable to send username reminder.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Forgot Username'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_search, color: Colors.white, size: 64),

                const SizedBox(height: 24),

                const Text(
                  'Find your username',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Enter the email address linked to your '
                  'TrakOn account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: sending ? null : sendUsernameReminder,
                  child: Text(
                    sending ? 'Sending...' : 'Send Username Reminder',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
