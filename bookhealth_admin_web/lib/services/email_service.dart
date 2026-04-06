import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class EmailService {
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwb_zFcez098P4_xRhdpUH0TaOU-wSlOmof19DdpEHOD_i6L-a90_fe4XXCY3IIyQHM/exec';

  Future<bool> sendVerificationSuccessEmail({
    required String email,
    required String labName,
  }) async {
    try {
      // Note: Reusing the OTP proxy for verification notification
      // The script will send: "Your OTP is: SUCCESSFUL! Your laboratory is now verified."
      final response = await http.post(
        Uri.parse(_scriptUrl),
        body: json.encode({
          "email": email,
          "otp": "SUCCESSFUL! Your laboratory ($labName) is now verified and live on BookHealth."
        }),
      );

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      if (kDebugMode) print("Email sending error: $e");
      return false;
    }
  }
}
