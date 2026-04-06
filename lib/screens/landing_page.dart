import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

import 'auth_screens.dart';
import 'patient_screens.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAutoLoggingIn) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          );
        }

        final user = authService.currentUser;

        if (user == null) {
          return const WelcomeScreen();
        } else {
          final role = user['role'];
          if (role == 'patient') {
            return const PatientMainScreen();
          }
          return const WelcomeScreen();
        }
      },
    );
  }
}
