import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/admin_web_auth.dart';
import 'screens/admin_dashboard_web.dart';
import 'services/auth_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("Initializing Firebase for Admin Portal...");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("Firebase Admin Initialized successfully.");
    runApp(const AdminWebPortal());
  } catch (e) {
    debugPrint("Admin initialization error: $e");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("Critical initialization error: $e"),
        ),
      ),
    ));
  }
}

class AdminWebPortal extends StatelessWidget {
  const AdminWebPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'BookHealth Admin',
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
        home: const AdminHomeRouter(),
      ),
    );
  }
}

class AdminHomeRouter extends StatelessWidget {
  const AdminHomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final user = authService.currentUser;
        if (user == null || user['role'] != 'admin') {
          return const AdminWebAuth();
        } else {
          return const AdminDashboardWeb();
        }
      },
    );
  }
}
