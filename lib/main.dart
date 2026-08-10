// Import Flutter UI package
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:TrakOn/screens/main_navigation_screen.dart';
//import 'package:TrakOn/screens/main_navigation_screen.dart';

import 'screens/mfa_screen.dart';
//import 'screens/tutorial_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'screens/notification_service.dart';

import 'screens/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'screens/email_verification_screen.dart';
import 'screens/phone_verification_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'screens/email_otp_screen.dart';

// Entry point of the app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

  await NotificationService.init();
  await NotificationService.requestPermissions();

  // Show a notification
  

  final prefs = await SharedPreferences.getInstance();

  // await prefs.setBool('hasSeenOnboarding', false);


  final bool hasSeenOnboarding =
      prefs.getBool('hasSeenOnboarding') ?? false;

  final bool isLoggedIn = 
       prefs.getBool('isLoggedIn') ?? false;
  
  debugPrint('isLoggedIn: $isLoggedIn');
  debugPrint('hasSeenOnboarding: $hasSeenOnboarding');

  runApp(
    MyApp(
      hasSeenOnboarding: hasSeenOnboarding,
      isLoggedIn: isLoggedIn,
    ),
  );
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
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.black,
        ),

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
// Welcome Screen (Animation + Button)
// ---------------------------
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String displayedText = '';

  bool showTrack = false;
  bool showFocus = false;
  bool showAchieve = false;
  bool showButton = false;

  final String welcomeText = 'Welcome to TrakOn';

  @override
  void initState() {
    super.initState();

    // Start animation when screen loads
    startTypewriterAnimation();
  }

  void startTypewriterAnimation() {
    int currentIndex = 0;

    Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (currentIndex < welcomeText.length) {
        if(!mounted) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Padding( 
          padding: const EdgeInsets.symmetric(horizontal: 24),

          // Column = vertical layout
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              const Icon(
                Icons.track_changes,
                size: 90,
                color: Colors.white,
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
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),

                    if (showFocus)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          'Focus.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ),

                    if (showAchieve)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          'Achieve.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
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
                            bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

                            if(!context.mounted) return;
                            
                            if (isLoggedIn) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const MainNavigationScreen(),
                                ),
                              );
                            } else {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const AuthChoiceScreen(),
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
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color:Colors.white, letterSpacing: 0.5),
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

  // Remove common formatting characters
  phoneNumber = phoneNumber.replaceAll(
    RegExp(r'[\s\-\(\)]'),
    '',
  );

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
      const SnackBar(
        content: Text(
          'Please enter a valid phone number.',
        ),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => PhoneVerificationScreen(
        phoneNumber: phoneNumber,
      ),
    ),
  );
}

Future<void> createEmailAccount() async {
  try {
    final email = emailController.text.trim();
    final password = passwordController.text;

    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('Account could not be created.');
    }

    final fullName =
        '${firstNameController.text.trim()} ${lastNameController.text.trim()}';

    await user.updateDisplayName(fullName);

    final callable =
    FirebaseFunctions.instance.httpsCallable('sendEmailOtp');

    await callable.call({
      'email': email,
    });

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => EmailOtpScreen(
          email: email,
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      debugPrint('FUNCTION ERROR CODE: ${e.code}');
      debugPrint('FUNCTION ERROR MESSAGE: ${e.message}');
      debugPrint('FUNCTION ERROR DETAILS: ${e.details}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Function error: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('GENERAL ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          final month =
                              tempPickedDate.month.toString().padLeft(2, '0');
                          final day =
                              tempPickedDate.day.toString().padLeft(2, '0');
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
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                    ),
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

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Form(
          key: _formKey,

          child: Column(
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
                  if(value.trim().length < 3) {
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
                      border: Border.all(
                        color: Colors.white24,
                      ),
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
                    if (!useEmail && (value == null || value.trim().isEmpty)) {
                      return 'Enter your phone number';
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 16),

              // PASSWORD FIELD
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
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
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
    final prefs = await SharedPreferences.getInstance();

    final savedUsername = prefs.getString('username');
    final savedContactInfo = prefs.getString('contactInfo');
    final savedPassword = prefs.getString('password');

    final loginInput = loginController.text.trim();
    final passwordInput = passwordController.text;

    final loginMatches =
        loginInput == savedUsername || loginInput == savedContactInfo;

    if (loginMatches && passwordInput == savedPassword) {
      await prefs.setBool('rememberMe', rememberMe);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MfaScreen(
            contactInfo: savedContactInfo ?? loginInput,
            isNewUser: false,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect username/contact or password.'),
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
                    obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
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

            const SizedBox(height: 12),

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