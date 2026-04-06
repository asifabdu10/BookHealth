import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/lab_web_auth.dart';
import 'screens/lab_dashboard_web.dart';
import 'services/auth_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("Initializing Firebase for Lab Portal...");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("Firebase Initialized successfully.");
    runApp(const LabWebPortal());
  } catch (e) {
    debugPrint("Critical initialization error: $e");
    // Show a basic Error App if it fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableText("Critical initialization error. Please reload or check console logs: $e"),
        ),
      ),
    ));
  }
}

class LabWebPortal extends StatelessWidget {
  const LabWebPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'BookHealth - Lab Hub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Inter',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF024950),
            primary: const Color(0xFF024950),
            secondary: const Color(0xFF964734),
            surface: const Color(0xFFAFDDE5),
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF003135),
            foregroundColor: Colors.white,
          ),
        ),
        home: const LabHomeRouter(),
      ),
    );
  }
}

class LabHomeRouter extends StatelessWidget {
  const LabHomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final user = authService.currentUser;
        if (user == null || user['role'] != 'lab_tech') {
          return const LabWebAuth();
        } else {
          return const LabDashboardWeb();
        }
      },
    );
  }
}
