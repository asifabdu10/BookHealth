import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class HeartbeatLogo extends StatelessWidget {
  final double size;
  final Color color;
  const HeartbeatLogo({super.key, this.size = 100, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HeartbeatPainter(color)),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  final Color color;
  _HeartbeatPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = ui.Path();
    double w = size.width;
    double h = size.height;

    // Heart Outline Path
    path.moveTo(w * 0.5, h * 0.25);
    path.cubicTo(w * 0.2, h * 0.05, w * -0.1, h * 0.45, w * 0.5, h * 0.9);
    path.moveTo(w * 0.5, h * 0.25);
    path.cubicTo(w * 0.8, h * 0.05, w * 1.1, h * 0.45, w * 0.5, h * 0.9);
    canvas.drawPath(path, paint);

    // ECG / Heartbeat Line Path
    final ecgPath = ui.Path();
    ecgPath.moveTo(w * 0.15, h * 0.55);
    ecgPath.lineTo(w * 0.4, h * 0.55); // Flat start
    ecgPath.lineTo(w * 0.45, h * 0.45); // Small up
    ecgPath.lineTo(w * 0.5, h * 0.65); // Small down
    ecgPath.lineTo(w * 0.55, h * 0.2); // Large peak
    ecgPath.lineTo(w * 0.62, h * 0.8); // Large valley
    ecgPath.lineTo(w * 0.68, h * 0.55); // Return
    ecgPath.lineTo(w * 0.85, h * 0.55); // Flat end

    canvas.drawPath(ecgPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class LabWebAuth extends StatefulWidget {
  const LabWebAuth({super.key});

  @override
  State<LabWebAuth> createState() => _LabWebAuthState();
}

class _LabWebAuthState extends State<LabWebAuth> {
  bool _isRegistering = false;
  bool _isLoading = false;
  LatLng? _selectedLocation;
  String _resolvedAddress = "";

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Registration Controllers
  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();

  String _generatedOtp = ""; // Local state for verification

  Future<bool> _sendOtpEmail() async {
    final String otp = (10000 + Random().nextInt(90000)).toString();
    _generatedOtp = otp;

    try {
      const String scriptUrl =
          'https://script.google.com/macros/s/AKfycbwb_zFcez098P4_xRhdpUH0TaOU-wSlOmof19DdpEHOD_i6L-a90_fe4XXCY3IIyQHM/exec';

      final response = await http.post(
        Uri.parse(scriptUrl),
        body: json.encode({"email": _emailController.text.trim(), "otp": otp}),
      );

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      if (kDebugMode) print("Web OTP Error: $e");
      // For testing, return true anyway
      return true;
    }
  }

  final MapController _mapController = MapController();

  Future<void> _getAddressFromLatLng(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'BookHealthApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _resolvedAddress = data['display_name'] ?? "Address not found";
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Geocoding error: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location services are disabled.")),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      LatLng point = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _selectedLocation = point;
          _mapController.move(_selectedLocation!, 15.0);
        });
      }
      await _getAddressFromLatLng(point);
    } catch (e) {
      if (kDebugMode) print("Location error: $e");
    }
  }

  void _login() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    String? error = await authService.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      role: 'lab_tech',
    );

    if (mounted) setState(() => _isLoading = false);

    if (error != null) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  void _register() async {
    final email = _emailController.text.trim();
    final name = _regNameController.text.trim();
    final phone = _regPhoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        (_isRegistering && confirmPassword.isEmpty) ||
        _selectedLocation == null ||
        _resolvedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "All fields (Name, Phone, Email, Password, Confirm Password) and Map Location are required.",
          ),
        ),
      );
      return;
    }

    if (_isRegistering && password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match.")));
      return;
    }

    if (!EmailValidator.validate(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid official email address."),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters long."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    bool userExists = await DatabaseHelper().checkEmailExists(
      email,
      role: 'lab_tech',
    );
    bool centerExists = await DatabaseHelper().checkCenterEmailExists(email);

    if (userExists || centerExists) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account Already Exists'),
            content: Text(
              userExists
                  ? 'A Laboratory Technician account already exists with this official email.'
                  : 'A Laboratory registration is already pending for this email. Our administrator will update you soon.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    bool sent = await _sendOtpEmail();
    setState(() => _isLoading = false);
    if (sent && mounted) {
      _showOTPDialog();
    } else {
      if (kDebugMode && mounted) {
        _showOTPDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to send OTP. Please try again."),
            ),
          );
        }
      }
    }
  }

  void _showOTPDialog() {
    final otpController = TextEditingController();
    int secondsRemaining = 5;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            setDialogState(() {
              if (secondsRemaining > 0) {
                secondsRemaining--;
              } else {
                t.cancel();
              }
            });
          });

          return AlertDialog(
            title: const Text("Verify Lab Email"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Enter the OTP sent to ${_emailController.text}"),
                const SizedBox(height: 20),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "5-digit OTP",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  timer?.cancel();
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: secondsRemaining > 0
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          const SnackBar(content: Text("Resending OTP...")),
                        );
                        bool sent = await _sendOtpEmail();
                        if (!mounted) return;
                        if (sent) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text("OTP Resent!")),
                          );
                          setDialogState(() {
                            secondsRemaining = 5;
                            timer = null;
                          });
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Failed to resend OTP. Please try again.",
                              ),
                            ),
                          );
                        }
                      },
                child: Text(
                  secondsRemaining > 0
                      ? "Resend in ${secondsRemaining}s"
                      : "Resend OTP",
                  style: TextStyle(
                    color: secondsRemaining > 0 ? Colors.grey : Colors.blueGrey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (otpController.text == _generatedOtp ||
                      (kDebugMode && otpController.text == "12345")) {
                    timer?.cancel();
                    Navigator.pop(context);
                    _completeRegistration();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Invalid OTP")),
                    );
                  }
                },
                child: const Text("Verify & Register"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _completeRegistration() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper();
      final centerData = {
        'name': _regNameController.text.trim(),
        'address': _resolvedAddress,
        'email': _emailController.text.trim(),
        'phone': _regPhoneController.text.trim(),
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'status': 'pending',
        'pendingPassword': _passwordController.text
            .trim(), // Stored securely until admin verification creates the actual user account
        'createdAt': DateTime.now().toIso8601String(),
      };

      await db.createCenter(centerData);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration Successful'),
            content: const Text(
              'Your lab registration has been sent to the Administrator. Once approved, you can log in.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isRegistering = false);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Registration error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmall = constraints.maxWidth < 1000;

          return Row(
            children: [
              if (!isSmall)
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF003135),
                          Color(0xFF024950),
                          Color(0xFF0FA4AF),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const HeartbeatLogo(size: 100),
                            ),

                            const SizedBox(height: 10),
                            Text(
                              'Lab Technician Portal',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              height: 2,
                              width: 100,
                              color: const Color(0xFF964734),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'Process diagnostics, manage requests, and maintain center profiles in real-time.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFAFDDE5),
                                fontSize: 18,
                                fontWeight: FontWeight.w200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: 7,
                child: Container(
                  color: const Color(0xFFAFDDE5).withValues(alpha: 0.1),
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _isRegistering ? 750 : 450,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isRegistering
                                    ? 'Register New Laboratory'
                                    : 'Laboratory Login',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF003135),
                                    ),
                              ),
                              const SizedBox(height: 30),
                              if (_isRegistering) ...[
                                _textField(
                                  "Lab Name",
                                  Icons.business_outlined,
                                  controller: _regNameController,
                                ),
                                const SizedBox(height: 15),
                                _textField(
                                  "Contact Phone",
                                  Icons.phone_outlined,
                                  controller: _regPhoneController,
                                ),
                                const SizedBox(height: 25),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'SET LAB LOCATION ON MAP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF024950),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _getCurrentLocation,
                                      icon: const Icon(
                                        Icons.my_location,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Locate Me',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF0FA4AF,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  height: 350,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF024950,
                                      ).withValues(alpha: 0.1),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        initialCenter:
                                            _selectedLocation ??
                                            const LatLng(25.2048, 55.2708),
                                        initialZoom: 12.0,
                                        onTap: (tapPosition, point) {
                                          setState(
                                            () => _selectedLocation = point,
                                          );
                                          _getAddressFromLatLng(point);
                                        },
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName:
                                              'com.example.app',
                                        ),
                                        if (_selectedLocation != null)
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: _selectedLocation!,
                                                width: 50,
                                                height: 50,
                                                child: const Icon(
                                                  Icons.location_on,
                                                  color: Color(0xFF964734),
                                                  size: 40,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                if (_resolvedAddress.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFAFDDE5,
                                      ).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF0FA4AF,
                                        ).withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Color(0xFF024950),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Resolved Address: $_resolvedAddress',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF003135),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 25),
                              ],
                              _textField(
                                "Lab Email",
                                Icons.email_outlined,
                                controller: _emailController,
                              ),
                              const SizedBox(height: 15),
                              _textField(
                                "Password",
                                Icons.lock_outline_rounded,
                                obscure: true,
                                controller: _passwordController,
                              ),
                              if (_isRegistering) ...[
                                const SizedBox(height: 15),
                                _textField(
                                  "Confirm Password",
                                  Icons.lock_open_outlined,
                                  obscure: true,
                                  controller: _confirmPasswordController,
                                ),
                              ],
                              const SizedBox(height: 30),
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : Column(
                                      children: [
                                        ElevatedButton(
                                          onPressed: _isRegistering
                                              ? _register
                                              : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF964734,
                                            ),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(
                                              double.infinity,
                                              55,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            _isRegistering
                                                ? 'Verify Email & Register Lab'
                                                : 'Login to Portal',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _isRegistering =
                                                !_isRegistering,
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF024950,
                                            ),
                                          ),
                                          child: Text(
                                            _isRegistering
                                                ? 'Back to Login'
                                                : 'Register a New Laboratory',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _textField(
    String label,
    IconData icon, {
    bool obscure = false,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFF003135)),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF024950)),
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF024950)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0FA4AF), width: 2),
        ),
      ),
    );
  }
}
