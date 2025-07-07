// import 'package:flutter/material.dart';
// import 'package:flutter_tts/flutter_tts.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
  
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
//       ),
//       home: const MyHomePage(title: 'Nuance'),
//     );
//   }
// }


// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   FlutterTts flutterTts = FlutterTts();
//   TextEditingController textEditingController = TextEditingController();
//   String newText = " ";
  

//   Future _speak() async {
//     await flutterTts.setSharedInstance(true);
//     await flutterTts.setLanguage("en-US");
//     await flutterTts.setPitch(1.0);
//     await flutterTts.setSpeechRate(0.5);
//     await flutterTts.speak(newText);
//     await flutterTts.setVolume(1.0);
  
//     print(newText);
//   }

//   void _incrementCounter() {
//     setState(() {
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.secondary,
//         title: Text(
//           widget.title,
//           style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//             // color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),

        



//         ),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: TextField(
//                 controller: textEditingController,
//                 onChanged: (value) {
//                   setState(() {
//                     newText = value;
//                   });
//                 },
//                 decoration: InputDecoration(
//                   labelText: "Enter text to speak",
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.0),
//                   ),
//                 ),
//                 maxLines: 5,
//               ),
//             ),

//             const SizedBox(height: 20.0),
//             TextButton(
//               onPressed: () async {
//                 // flutterTts.setLanguage("en-US");
//                 // flutterTts.setPitch(1.2);
//                 // flutterTts.setSpeechRate(0.5);
//                 // flutterTts.speak("Victor sent 20,000 naira to your account.");
//                 // newText = textEditingController.text;
//                 _speak();
//               },
//               style: TextButton.styleFrom(
//                 backgroundColor: Theme.of(context).colorScheme.secondary,
//                 padding: const EdgeInsets.all(8.0),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//               ),
//               child: Text(
//                 'Click Me',
//                 style: Theme.of(
//                   context,
//                 ).textTheme.headlineSmall?.copyWith(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// This must be a top-level function (not a class method) for background message handling.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // It's recommended to initialize Firebase here if you need to use other Firebase services.
  await Firebase.initializeApp();
  print("BACKGROUND_HANDLER: Received message: ${message.messageId}");
  print("BACKGROUND_HANDLER: Message data: ${message.data}");

  // If a message contains a "sentence" data payload, speak it.
  final sentence = message.data['sentence'];
  if (sentence != null) {
    print("BACKGROUND_HANDLER: Found sentence: '$sentence'");
    final FlutterTts flutterTts = FlutterTts();

    // --- Add logging to the TTS instance ---
    flutterTts.setStartHandler(() {
      print("BACKGROUND_TTS: Speaking started.");
    });
    flutterTts.setCompletionHandler(() {
      print("BACKGROUND_TTS: Speaking complete.");
    });
    flutterTts.setErrorHandler((msg) {
      print("BACKGROUND_TTS: ERROR - $msg");
    });
    // -----------------------------------------

    // On iOS, this is crucial for background audio.
    await flutterTts.setSharedInstance(true);
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(sentence);
  } else {
    print("BACKGROUND_HANDLER: No 'sentence' key found in data payload.");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 28, 115, 95)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const TalkerHomePage(),
    );
  }
}

class TalkerHomePage extends StatefulWidget {
  const TalkerHomePage({super.key});

  @override
  State<TalkerHomePage> createState() => _TalkerHomePageState();
}

class _TalkerHomePageState extends State<TalkerHomePage> {
  final FlutterTts flutterTts = FlutterTts();
  String _spokenSentence = "Waiting for a sentence from the server...";
  String? _fcmToken;
  String _registrationStatus = "Not Registered";

  // --- CONFIGURATION FOR YOUR BACKEND ---
  // IMPORTANT: For the Android emulator talking to a server on the same machine, use '10.0.2.2'.
  // For a real device, this must be your computer's network IP or a public domain.
  final String _backendUrl = 'http://10.0.2.2:8085';
  // For this demo, we'll hardcode a user ID. In a real app, this would come from a login system.
  final String _userId = 'user123';
  // -----------------------------------------
  @override
  void initState() {
    super.initState();
    _initTts();
    _setupFirebaseMessaging();
  }

  Future<void> _initTts() async {
    // --- Add logging to the main TTS instance to see what it's doing ---
    flutterTts.setStartHandler(() {
      print("FOREGROUND_TTS: Speaking started.");
    });
    flutterTts.setCompletionHandler(() {
      print("FOREGROUND_TTS: Speaking complete.");
    });
    flutterTts.setErrorHandler((msg) {
      print("FOREGROUND_TTS: ERROR - $msg");
      if (mounted) {
        setState(() => _spokenSentence = "TTS Error: $msg");
      }
    });
    // --------------------------------------------------------------------

    // Recommended for iOS to manage audio sessions correctly.
    await flutterTts.setSharedInstance(true);
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      print("FOREGROUND_SPEAK: Attempting to speak: '$text'");
      setState(() => _spokenSentence = text);
      await flutterTts.speak(text);
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request notification permissions
    await messaging.requestPermission();

    // Get the unique FCM token for this device
    final token = await messaging.getToken();
    setState(() => _fcmToken = token);
    print("FCM Token: $token");

    // *** THIS IS THE NEW, CRUCIAL STEP ***
    if (token != null) {
      await _registerDeviceWithBackend(token);
    }
    // *************************************

    // Listen for incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message received: ${message.data}");
      if (message.data['sentence'] != null) {
        _speak(message.data['sentence']);
      }
    });

    // Handle when a user taps a notification, opening the app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Message opened app: ${message.data}");
      if (message.data['sentence'] != null) {
        _speak(message.data['sentence']);
      }
    });
  }

  /// Sends the device token to your Spring Boot backend.
  Future<void> _registerDeviceWithBackend(String token) async {
    setState(() => _registrationStatus = "Registering...");
    try {
      final url = Uri.parse('$_backendUrl/api/v1/devices/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _userId,
          'token': token,
        }),
      );

      if (response.statusCode == 200) {
        setState(() => _registrationStatus = "Registered Successfully!");
        print("Backend registration successful.");
      } else {
        setState(() => _registrationStatus = "❌ Registration Failed (Code: ${response.statusCode})");
        print("Backend registration failed: ${response.body}");
      }
    } catch (e) {
      setState(() => _registrationStatus = "❌ Error: ${e.toString()}");
      print("Error registering with backend: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,  // Center the title
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Small registration status card at the top
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _registrationStatus.contains('✅') ? Icons.check_circle : Icons.info_outline,
                    color: _registrationStatus.contains('✅') ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _registrationStatus,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sentence card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    //mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Received Sentence',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      //const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: Text(
                            _spokenSentence,
                            style: TextStyle(
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.secondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
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
