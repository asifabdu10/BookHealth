import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../widgets/bmi_calculator.dart';

// --- Patient Main Screen (Navigation Hub) ---
class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({super.key});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _notifSub;
  final Set<String> _notifiedAppointmentIds =
      {}; // TRACK notified IDs per session

  @override
  void initState() {
    super.initState();
    _initNotificationStream();
  }

  void _initNotificationStream() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?['uid'] ?? '';
    if (userId.isEmpty) return;

    _notifSub = DatabaseHelper().getAppointmentsStreamForPatient(userId).listen((
      appointments,
    ) {
      for (var app in appointments) {
        final String appId = app['id'] ?? '';
        if (appId.isEmpty) continue;

        if (app['hasPatientSeenUpdate'] == false) {
          String? title;
          String? msg;
          if (app['isRescheduled'] == true && app['status'] != 'completed') {
            title = "Booking Rescheduled";
            msg =
                "🕒 Your appointment for ${app['testType'] ?? 'Lab Test'} has been RESCHEDULED to ${app['time']}.";

            // Reschedule the 1-hour reminder
            if (!_notifiedAppointmentIds.contains(
              "$appId-reschedule-reminder",
            )) {
              _notifiedAppointmentIds.add("$appId-reschedule-reminder");
              try {
                final date = DateTime.parse(app['date']);
                final timeStr = app['time'] ?? '';
                final parts = timeStr.trim().split(' ');
                final timeParts = parts[0].split(':');
                int hour = int.parse(timeParts[0]);
                int minute = int.parse(timeParts[1]);
                if (parts.length > 1) {
                  if (parts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
                  if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
                }
                final newAppDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  hour,
                  minute,
                );

                NotificationService().scheduleAppointmentReminder(
                  id: appId.hashCode,
                  labName: app['labName'] ?? 'The Laboratory',
                  testType: app['testType'] ?? 'Lab Test',
                  appointmentDateTime: newAppDateTime,
                );
              } catch (e) {
                print("Error rescheduling reminder: $e");
              }
            }
          } else if (app['status'] == 'completed') {
            title = "Results Ready";
            msg =
                "📄 GOOD NEWS! Your test results for ${app['testType'] ?? 'Lab Test'} are READY to view.";

            // Scheduling 30-day reminder (moved inside condition to check if already notified)
            if (!_notifiedAppointmentIds.contains("$appId-30d")) {
              _notifiedAppointmentIds.add("$appId-30d");
              DateTime? appDate;
              if (app['date'] != null) {
                appDate = DateTime.tryParse(app['date']);
              }
              NotificationService().schedule30DayReminder(
                id: (appId + "30d").hashCode,
                labName: app['labName'] ?? 'Your Laboratory',
                appointmentDate: appDate,
              );
            }
          }

          if (msg != null && !_notifiedAppointmentIds.contains(appId)) {
            // Show System Push Notification only if not shown in this session
            _notifiedAppointmentIds.add(appId);

            NotificationService().showNotification(
              id: appId.hashCode,
              title: title ?? "Health Update",
              body: msg,
            );

            // NOTE: We REMOVED the SnackBar (blue tab) as requested.
            // Notifications are now persistent in the "Notification" icon until marked as seen.
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseHelper().getAppointmentsStreamForPatient(
        authService.currentUser?['uid'] ?? '',
      ),
      builder: (context, snapshot) {
        final appointments = snapshot.data ?? [];
        bool hasPendingUpdate = appointments.any(
          (a) => a['hasPatientSeenUpdate'] == false && a['status'] == 'pending',
        );
        bool hasHistoryUpdate = appointments.any(
          (a) =>
              a['hasPatientSeenUpdate'] == false && a['status'] == 'completed',
        );

        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              const PatientHome(),
              HistoryScreen(),
              const ProfileScreen(),
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: _buildGlassNavigationBar(
            hasPendingUpdate,
            hasHistoryUpdate,
          ),
        );
      },
    );
  }

  Widget _buildGlassNavigationBar(
    bool hasPendingUpdate,
    bool hasHistoryUpdate,
  ) {
    return Container(
      height: 90,
      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  Icons.home_outlined,
                  Icons.home,
                  "Home",
                  0,
                  hasPendingUpdate,
                ),
                _buildNavItem(
                  Icons.history_outlined,
                  Icons.history,
                  "History",
                  1,
                  hasHistoryUpdate,
                ),
                _buildNavItem(
                  Icons.person_outline,
                  Icons.person,
                  "Profile",
                  2,
                  false,
                ),
                _buildNavItem(
                  Icons.settings_outlined,
                  Icons.settings,
                  "Settings",
                  3,
                  false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData outlineIcon,
    IconData solidIcon,
    String label,
    int index,
    bool showDot,
  ) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  isSelected ? solidIcon : outlineIcon,
                  color: isSelected ? Colors.blue[400] : Colors.black54,
                  size: 28,
                ),
              ),
              if (showDot)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.blue[400] : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Patient Home ---
class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _allCenters = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  DateTime? _selectedDate;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    final centers = await DatabaseHelper().getVerifiedCenters();
    setState(() => _allCenters = centers);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monitor_heart,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BookHealth',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseHelper().getAppointmentsStreamForPatient(
              user?['uid'] ?? '',
            ),
            builder: (context, snapshot) {
              final appointments = snapshot.data ?? [];
              final unreadResults = appointments
                  .where(
                    (a) =>
                        a['hasPatientSeenUpdate'] == false &&
                        (a['status'] == 'completed' ||
                            a['isRescheduled'] == true),
                  )
                  .toList();

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.black87,
                    ),
                    onPressed: () {
                      if (unreadResults.isNotEmpty) {
                        _showNotificationsDialog(unreadResults);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("No new notifications"),
                            backgroundColor: Colors.blueGrey,
                          ),
                        );
                      }
                    },
                  ),
                  if (unreadResults.isNotEmpty)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB8C6DB), Color(0xFFF5E3E6), Color(0xFFD9E4F5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RawAutocomplete<Map<String, dynamic>>(
                    textEditingController: _searchController,
                    focusNode: _searchFocusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _allCenters.where((center) {
                        final name = center['name'].toString().toLowerCase();
                        final address = center['address']
                            .toString()
                            .toLowerCase();
                        return name.contains(query) || address.contains(query);
                      });
                    },
                    onSelected: (Map<String, dynamic> center) {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _searchFocusNode.unfocus();
                      _showLabDetailsDialog(center);
                    },
                    fieldViewBuilder:
                        (
                          BuildContext context,
                          TextEditingController textEditingController,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              onChanged: (val) {
                                setState(() => _searchQuery = val);
                              },
                              decoration: InputDecoration(
                                hintText: "Find nearby labs...",
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.black54,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () {
                                          textEditingController.clear();
                                          setState(() => _searchQuery = '');
                                          focusNode.unfocus();
                                        },
                                      )
                                    : const Icon(
                                        Icons.calendar_today,
                                        color: Colors.black54,
                                      ),
                                border: InputBorder.none,
                              ),
                            ),
                          );
                        },
                    optionsViewBuilder:
                        (
                          BuildContext context,
                          AutocompleteOnSelected<Map<String, dynamic>>
                          onSelected,
                          Iterable<Map<String, dynamic>> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.transparent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width - 40,
                                    constraints: const BoxConstraints(
                                      maxHeight: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final center = options.elementAt(index);
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.biotech,
                                            color: Colors.blueAccent,
                                          ),
                                          title: Text(center['name']),
                                          subtitle: Text(
                                            center['address'],
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          onTap: () {
                                            onSelected(center);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                  ),
                  const SizedBox(height: 30),
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: DatabaseHelper()
                        .getLatestAppointmentStreamForPatient(
                          user?['uid'] ?? '',
                        ),
                    builder: (context, snapshot) {
                      final latest = snapshot.data;
                      if (latest != null && latest['status'] == 'completed') {
                        final completedAtStr =
                            latest['completedAt'] ?? latest['date'];
                        final completedAt = DateTime.tryParse(completedAtStr);
                        if (completedAt != null) {
                          final daysSince = DateTime.now()
                              .difference(completedAt)
                              .inDays;
                          if (daysSince >= 30) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 25),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orangeAccent.withOpacity(0.9),
                                    const Color(0xFFF09819).withOpacity(0.9),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notification_important_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Time for a Re-test?",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "It's been $daysSince days since your last lab test. We recommend a monthly checkup for optimal health tracking.",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const Text(
                    "Last Checkup Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: DatabaseHelper()
                        .getLatestAppointmentStreamForPatient(
                          user?['uid'] ?? '',
                        ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final appointment = snapshot.data;

                      return GestureDetector(
                        onTap: () {
                          if (appointment?['hasPatientSeenUpdate'] == false) {
                            DatabaseHelper().updateAppointment(
                              appointment?['id'],
                              {'hasPatientSeenUpdate': true},
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.assignment,
                                      color: Colors.black54,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  if (appointment != null)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Date: ${appointment['date'].split('T')[0]} | Time: ${appointment['time'] ?? 'Not set'}",
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          FutureBuilder<
                                            List<Map<String, dynamic>>
                                          >(
                                            future: DatabaseHelper()
                                                .getAllCenters(),
                                            builder: (context, centerSnap) {
                                              String centerName = "Unknown Lab";
                                              String centerPhone = "";
                                              String centerEmail = "";
                                              if (centerSnap.hasData) {
                                                final center = centerSnap.data!
                                                    .firstWhere(
                                                      (c) =>
                                                          c['id'] ==
                                                          appointment['centerId'],
                                                      orElse: () => {
                                                        'name': 'Unknown',
                                                      },
                                                    );
                                                centerName = center['name'];
                                                centerPhone =
                                                    center['phone'] ?? "";
                                                centerEmail =
                                                    center['email'] ?? "";
                                              }
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    centerName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  if (centerPhone.isNotEmpty)
                                                    Text(
                                                      "Phone: $centerPhone",
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  if (centerEmail.isNotEmpty)
                                                    Text(
                                                      "Email: $centerEmail",
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            "Status: ${appointment['status']}",
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const Text(
                                      "No recent appointments",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                ],
                              ),
                              if (appointment?['hasPatientSeenUpdate'] == false)
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          context,
                          "Book Lab Test",
                          Icons.science,
                          const Color(0xFFD4E2F0),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NearbyLabsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionCard(
                          context,
                          "BMI Calculator",
                          Icons.calculate,
                          const Color(0xFFE8D4E6),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BMICalculator(),
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
        ),
      ),
    );
  }

  void _showLabDetailsDialog(Map<String, dynamic> center) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          center['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(center['address'])),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(center['phone'] ?? "Not available")),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.email, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(center['email'] ?? "Not available")),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBookingBottomSheet(center);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF333E53),
            ),
            child: const Text(
              "Book Now",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingBottomSheet(Map<String, dynamic> center) {
    _selectedDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "Book at ${center['name']}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 35),
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      setModalState(() => _selectedDate = picked);
                    }
                  },
                  child: Row(
                    children: [
                      const Text("Select Date", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text(
                        _selectedDate == null
                            ? ""
                            : "${_selectedDate!.toLocal()}".split(' ')[0],
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.calendar_today_outlined),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBooking
                        ? null
                        : () => _confirmBooking(center, setModalState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333E53),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isBooking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Confirm Booking",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmBooking(
    Map<String, dynamic> center,
    StateSetter setModalState,
  ) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }
    setModalState(() => _isBooking = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        final String dateIso = _selectedDate!.toIso8601String();
        final String? availableTime = await DatabaseHelper()
            .getNextAvailableSlot(center['id'], dateIso);

        if (availableTime == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No appointment can be done on that day.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final appointment = {
          'patientId': user['uid'],
          'patientName': user['name'] ?? 'Unknown',
          'patientPhone': user['phone'] ?? 'Unknown',
          'patientEmail': user['email'] ?? 'Unknown',
          'centerId': center['id'],
          'date': dateIso,
          'time': availableTime,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'sugar': '',
          'cholesterol': '',
          'pressure': '',
        };
        final appointmentId = await DatabaseHelper().createAppointment(
          appointment,
        );

        // Schedule Reminder 1 hour before the newly booked appointment
        DateTime? appDateTime;
        try {
          final date = _selectedDate!;
          final parts = availableTime.trim().split(' ');
          final timeParts = parts[0].split(':');
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          if (parts.length > 1) {
            if (parts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
            if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
          }
          appDateTime = DateTime(date.year, date.month, date.day, hour, minute);
        } catch (e) {
          print("Error parsing appointment time for reminder: $e");
        }

        if (appDateTime != null) {
          NotificationService().scheduleAppointmentReminder(
            id: appointmentId.hashCode,
            labName: center['name'] ?? 'The Laboratory',
            testType: 'Lab Test',
            appointmentDateTime: appDateTime,
          );
        }

        if (mounted) {
          setState(() {}); // Trigger refresh of FutureBuilders on this screen
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking Confirmed! Time: $availableTime')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setModalState(() => _isBooking = false);
    }
  }

  Widget _actionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.black54),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(List<Map<String, dynamic>> unreadResults) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text(
              "Notifications",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unreadResults.length,
            itemBuilder: (context, index) {
              final result = unreadResults[index];
              final isRescheduled = result['isRescheduled'] == true;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: Icon(
                    isRescheduled ? Icons.schedule : Icons.assignment_turned_in,
                    color: isRescheduled ? Colors.orange : Colors.green,
                  ),
                  title: Text(
                    isRescheduled
                        ? "Appointment Rescheduled!"
                        : "Your test results are ready!",
                  ),
                  subtitle: Text(
                    isRescheduled
                        ? "New Time: ${result['time']}\nDate: ${result['date'].split('T')[0]}"
                        : "Date: ${result['date'].split('T')[0]}",
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (isRescheduled) {
                      await DatabaseHelper().updateAppointment(result['id'], {
                        'hasPatientSeenUpdate': true,
                      });
                      if (context.mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Reschedule acknowledged."),
                          ),
                        );
                      }
                    } else {
                      _showDetailedResultDialog(result);
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showDetailedResultDialog(Map<String, dynamic> data) async {
    await DatabaseHelper().updateAppointment(data['id'], {
      'hasPatientSeenUpdate': true,
    });
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.description, color: Color(0xFF2C3E50)),
            SizedBox(width: 10),
            Text("Test Results", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 10),
            _resultRowLocal(
              Icons.opacity,
              "Blood Sugar",
              "${data['sugar'] ?? 'N/A'} mg/dL",
            ),
            const SizedBox(height: 12),
            _resultRowLocal(
              Icons.monitor_heart,
              "Cholesterol",
              "${data['cholesterol'] ?? 'N/A'} mg/dL",
            ),
            const SizedBox(height: 12),
            _resultRowLocal(
              Icons.speed,
              "Blood Pressure",
              "${data['pressure'] ?? 'N/A'} mmHg",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {}); // refresh after seeing result
            },
            child: const Text(
              "Close",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRowLocal(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

// --- History Screen ---
// --- History Screen ---
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monitor_heart,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BookHealth',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB8C6DB), Color(0xFFF5E3E6), Color(0xFFD9E4F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Records for $_selectedYear",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.calendar_month,
                        color: Colors.blueAccent,
                      ),
                      onPressed: () => _selectYear(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: DatabaseHelper().getAppointmentsStreamForPatient(
                    user?['uid'] ?? '',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      print('Error fetching appointments: ${snapshot.error}');
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var appointments = snapshot.data ?? [];

                    // Filter by selected year
                    var filteredAppointments = appointments.where((data) {
                      try {
                        DateTime date = DateTime.parse(data['date']);
                        return date.year == _selectedYear;
                      } catch (e) {
                        return false;
                      }
                    }).toList();

                    if (filteredAppointments.isEmpty) {
                      return const Center(
                        child: Text(
                          "No records found for this year",
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = filteredAppointments[index];
                        return _buildRecordCard(context, appointment);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectYear(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && picked.year != _selectedYear) {
      setState(() {
        _selectedYear = picked.year;
      });
    }
  }

  Widget _buildRecordCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: DatabaseHelper().getAllCenters(),
                builder: (context, centerSnap) {
                  String centerName = "Loading Lab...";
                  Map<String, dynamic>? center;
                  if (centerSnap.hasData) {
                    center = centerSnap.data!.firstWhere(
                      (c) => c['id'] == data['centerId'],
                      orElse: () => {'name': 'Unknown Lab'},
                    );
                    centerName = center['name'];
                  }

                  return ExpansionTile(
                    onExpansionChanged: (expanded) {
                      if (expanded && data['hasPatientSeenUpdate'] == false) {
                        DatabaseHelper().updateAppointment(data['id'], {
                          'hasPatientSeenUpdate': true,
                        });
                      }
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.science,
                        color: Colors.blueAccent,
                      ),
                    ),
                    title: Text(
                      centerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      "Date: ${data['date'].split('T')[0]} | Time: ${data['time']}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            _infoRow(
                              Icons.info_outline,
                              "Status: ${data['status'].toUpperCase()}",
                              data['status'] == 'completed'
                                  ? Colors.green
                                  : data['status'] == 'pending'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            if (center != null) ...[
                              const SizedBox(height: 12),
                              _infoRow(
                                Icons.location_on_outlined,
                                center['address'] ?? 'No Address',
                              ),
                              const SizedBox(height: 12),
                              _infoRow(
                                Icons.phone_outlined,
                                center['phone'] ?? 'No Phone',
                              ),
                              const SizedBox(height: 12),
                              _infoRow(
                                Icons.email_outlined,
                                center['email'] ?? 'No Email',
                              ),
                            ],
                            if (data['status'] == 'completed') ...[
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (data['hasPatientSeenUpdate'] == false) {
                                      await DatabaseHelper().updateAppointment(
                                        data['id'],
                                        {'hasPatientSeenUpdate': true},
                                      );
                                    }
                                    if (context.mounted) {
                                      _showResultsDialog(context, data);
                                    }
                                  },
                                  icon: const Icon(Icons.receipt_long),
                                  label: const Text("View Result"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (data['hasPatientSeenUpdate'] == false)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, [Color? color]) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontSize: 14,
              fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  void _showResultsDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Row(
          children: [
            const Icon(Icons.assignment, color: Colors.green),
            const SizedBox(width: 10),
            const Text(
              "Lab Test Results",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Patient: ${data['patientName']}",
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const Divider(height: 25),
            if (data['sugar'] != null && data['sugar'].toString().isNotEmpty ||
                data['cholesterol'] != null &&
                    data['cholesterol'].toString().isNotEmpty ||
                data['pressure'] != null &&
                    data['pressure'].toString().isNotEmpty ||
                data['results'] != null &&
                    data['results'].toString().isNotEmpty) ...[
              if (data['sugar'] != null && data['sugar'].toString().isNotEmpty)
                _resultRow(
                  Icons.opacity,
                  "Blood Sugar",
                  "${data['sugar'] ?? 'N/A'} mg/dL",
                ),
              if (data['cholesterol'] != null &&
                  data['cholesterol'].toString().isNotEmpty) ...[
                const SizedBox(height: 15),
                _resultRow(
                  Icons.monitor_heart,
                  "Cholesterol",
                  "${data['cholesterol'] ?? 'N/A'} mg/dL",
                ),
              ],
              if (data['pressure'] != null &&
                  data['pressure'].toString().isNotEmpty) ...[
                const SizedBox(height: 15),
                _resultRow(
                  Icons.speed,
                  "Blood Pressure",
                  "${data['pressure'] ?? 'N/A'} mmHg",
                ),
              ],
              if (data['results'] != null &&
                  data['results'].toString().isNotEmpty) ...[
                const Divider(height: 30),
                const Text(
                  "Technician Notes:",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data['results'],
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "Results pending upload from lab.",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Profile Screen ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monitor_heart,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BookHealth',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB8C6DB), Color(0xFFF5E3E6), Color(0xFFD9E4F5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildProfileRow(
                        Icons.person,
                        "Name",
                        user?['name'] ?? 'user1',
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 10),
                      _buildProfileRow(
                        Icons.email,
                        "Email",
                        user?['email'] ?? 'user1@gmail.com',
                      ),
                      const SizedBox(height: 10),
                      _buildProfileRow(
                        Icons.phone,
                        "Phone",
                        user?['phone'] ?? '672537838355',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => authService.signOut(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.15),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                        side: BorderSide(color: Colors.red.withOpacity(0.1)),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "Logout",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Space for bottom navigation
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 24),
        const SizedBox(width: 25),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Settings Screen ---
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monitor_heart,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BookHealth',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB8C6DB), Color(0xFFF5E3E6), Color(0xFFD9E4F5)],
          ),
        ),
      ),
    );
  }
}

// --- Nearby Labs Screen ---
class NearbyLabsScreen extends StatefulWidget {
  const NearbyLabsScreen({super.key});

  @override
  State<NearbyLabsScreen> createState() => _NearbyLabsScreenState();
}

class _NearbyLabsScreenState extends State<NearbyLabsScreen> {
  List<Map<String, dynamic>> _localCenters = [];
  String _searchQuery = '';
  bool _isLoading = true;
  LatLng? _currentLocation;
  final MapController _previewMapController = MapController();
  StreamSubscription? _centersSubscription;

  DateTime? _selectedDate;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _fetchCenters();
    _determinePosition();
  }

  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void dispose() {
    _centersSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _previewMapController.move(_currentLocation!, 13.0);
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
          }
        });
  }

  void _fetchCenters() {
    _centersSubscription = DatabaseHelper().getVerifiedCentersStream().listen((
      centers,
    ) {
      if (mounted) {
        setState(() {
          _localCenters = centers;
          _isLoading = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredCenters() {
    List<Map<String, dynamic>> filtered = _localCenters;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((center) {
        final name = (center['name'] as String).toLowerCase();
        final address = (center['address'] as String).toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }

    if (_currentLocation != null) {
      List<Map<String, dynamic>> sorted = filtered.map((center) {
        final double lat = double.tryParse(center['lat'].toString()) ?? 0.0;
        final double lng = double.tryParse(center['lng'].toString()) ?? 0.0;
        final double meters = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          lat,
          lng,
        );
        return {...center, 'distance': meters / 1000.0};
      }).toList();

      sorted.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );
      return sorted;
    }

    return filtered;
  }

  void _showBookingBottomSheet(Map<String, dynamic> center) {
    _selectedDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "Book at ${center['name']}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 35),
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      setModalState(() => _selectedDate = picked);
                    }
                  },
                  child: Row(
                    children: [
                      const Text(
                        "Select Date",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const Spacer(),
                      Text(
                        _selectedDate == null
                            ? ""
                            : "${_selectedDate!.toLocal()}".split(' ')[0],
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.grey[700],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBooking
                        ? null
                        : () => _confirmBooking(center, setModalState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333E53),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isBooking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Confirm Booking",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmBooking(
    Map<String, dynamic> center,
    StateSetter setModalState,
  ) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }

    setModalState(() => _isBooking = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        final String dateIso = _selectedDate!.toIso8601String();
        final String? availableTime = await DatabaseHelper()
            .getNextAvailableSlot(center['id'], dateIso);

        if (availableTime == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No appointment can be done on that day.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final appointment = {
          'patientId': user['uid'],
          'patientName': user['name'] ?? 'Unknown',
          'patientPhone': user['phone'] ?? 'Unknown',
          'patientEmail': user['email'] ?? 'Unknown',
          'centerId': center['id'],
          'date': dateIso,
          'time': availableTime,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'sugar': '',
          'cholesterol': '',
          'pressure': '',
        };

        final allLocal = await DatabaseHelper().getAllCenters();
        if (!allLocal.any((c) => c['id'] == center['id'])) {
          await DatabaseHelper().createCenter(center);
        }

        await DatabaseHelper().createAppointment(appointment);

        if (mounted) {
          setState(() {});
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking Confirmed! Time: $availableTime')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setModalState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monitor_heart,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BookHealth',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Nearby Labs",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
                decoration: const InputDecoration(
                  hintText: "Search labs...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MapScreen(centers: _getFilteredCenters()),
                  ),
                );
              },
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Stack(
                    children: [
                      if (_getFilteredCenters().isNotEmpty)
                        IgnorePointer(
                          child: FlutterMap(
                            mapController: _previewMapController,
                            options: MapOptions(
                              initialCenter:
                                  _currentLocation ??
                                  LatLng(
                                    double.tryParse(
                                          _getFilteredCenters()[0]['lat']
                                              .toString(),
                                        ) ??
                                        37.7749,
                                    double.tryParse(
                                          _getFilteredCenters()[0]['lng']
                                              .toString(),
                                        ) ??
                                        -122.4194,
                                  ),
                              initialZoom: 12.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.bookhealth',
                              ),
                              MarkerLayer(
                                markers: [
                                  if (_currentLocation != null)
                                    Marker(
                                      point: _currentLocation!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.my_location,
                                        color: Colors.blueAccent,
                                        size: 30,
                                      ),
                                    ),
                                  ..._getFilteredCenters().map(
                                    (center) => Marker(
                                      point: LatLng(
                                        double.tryParse(
                                              center['lat'].toString(),
                                            ) ??
                                            37.7749,
                                        double.tryParse(
                                              center['lng'].toString(),
                                            ) ??
                                            -122.4194,
                                      ),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 15,
                        left: 20,
                        right: 20,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Tap to view full map",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _getFilteredCenters().isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "No verified labs found",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            "Labs will appear here once they are verified by the administrator.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _getFilteredCenters().length,
                    itemBuilder: (context, index) {
                      final center = _getFilteredCenters()[index];
                      final distanceStr = center['distance'] != null
                          ? "${(center['distance'] as double).toStringAsFixed(1)} km"
                          : "Calculating...";

                      return GestureDetector(
                        onTap: () => _showLabDetailsDialog(center),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.biotech,
                                      color: Colors.blue,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          center['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        _buildInfoRow(
                                          Icons.location_on_outlined,
                                          center['address'],
                                        ),
                                        _buildInfoRow(
                                          Icons.phone_outlined,
                                          center['phone'] ??
                                              "555-010${index + 1}",
                                        ),
                                        _buildInfoRow(
                                          Icons.email_outlined,
                                          center['email'] ??
                                              "lab@bookhealth.com",
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        distanceStr,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showBookingBottomSheet(center),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF333E53,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 0,
                                          ),
                                          minimumSize: const Size(80, 40),
                                        ),
                                        child: const Text(
                                          "Book",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      TextButton.icon(
                                        onPressed: () {
                                          final lat =
                                              double.tryParse(
                                                center['lat'].toString(),
                                              ) ??
                                              0.0;
                                          final lng =
                                              double.tryParse(
                                                center['lng'].toString(),
                                              ) ??
                                              0.0;
                                          _launchMaps(lat, lng);
                                        },
                                        icon: const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.blue,
                                        ),
                                        label: const Text(
                                          "Get Location",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showLabDetailsDialog(Map<String, dynamic> center) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          center['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.location_on, center['address']),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.phone, center['phone'] ?? "Not available"),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.email, center['email'] ?? "Not available"),
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.map,
              "Lat: ${center['lat']}, Lng: ${center['lng']}",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBookingBottomSheet(center);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF333E53),
            ),
            child: const Text(
              "Book Now",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String? text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text ?? "Not provided",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch maps')));
      }
    }
  }
}

// --- Map Screen ---
class MapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> centers;
  const MapScreen({super.key, required this.centers});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late LatLng _initialPos;
  final List<Marker> _markers = [];
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  Map<String, dynamic>? _selectedCenter;

  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.centers.isNotEmpty) {
      _initialPos = LatLng(
        double.tryParse(widget.centers[0]['lat'].toString()) ?? 37.7749,
        double.tryParse(widget.centers[0]['lng'].toString()) ?? -122.4194,
      );
    } else {
      _initialPos = const LatLng(37.7749, -122.4194);
    }
    _loadMarkers();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation!, 13.0);
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
          }
        });
  }

  void _loadMarkers() {
    setState(() {
      _markers.clear();
      for (var center in widget.centers) {
        _markers.add(
          Marker(
            point: LatLng(
              double.tryParse(center['lat'].toString()) ?? 0.0,
              double.tryParse(center['lng'].toString()) ?? 0.0,
            ),
            width: 50,
            height: 50,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCenter = center);
                _mapController.move(
                  LatLng(
                    double.tryParse(center['lat'].toString()) ?? 0.0,
                    double.tryParse(center['lng'].toString()) ?? 0.0,
                  ),
                  14.0,
                );
              },
              child: Icon(
                Icons.location_on,
                color: _selectedCenter?['id'] == center['id']
                    ? Colors.blue
                    : Colors.red,
                size: 45,
              ),
            ),
          ),
        );
      }
    });
  }

  DateTime? _selectedDate;
  bool _isBooking = false;

  void _showBookingBottomSheet(Map<String, dynamic> center) {
    _selectedDate = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "Book at ${center['name']}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 35),
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      setModalState(() => _selectedDate = picked);
                    }
                  },
                  child: Row(
                    children: [
                      const Text("Select Date", style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text(
                        _selectedDate == null
                            ? ""
                            : "${_selectedDate!.toLocal()}".split(' ')[0],
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.calendar_today_outlined),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBooking
                        ? null
                        : () => _confirmBooking(center, setModalState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333E53),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isBooking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Confirm Booking",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmBooking(
    Map<String, dynamic> center,
    StateSetter setModalState,
  ) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }
    setModalState(() => _isBooking = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        final String dateIso = _selectedDate!.toIso8601String();
        final String? availableTime = await DatabaseHelper()
            .getNextAvailableSlot(center['id'], dateIso);

        if (availableTime == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No appointment can be done on that day.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final appointment = {
          'patientId': user['uid'],
          'patientName': user['name'] ?? 'Unknown',
          'patientPhone': user['phone'] ?? 'Unknown',
          'patientEmail': user['email'] ?? 'Unknown',
          'centerId': center['id'],
          'date': dateIso,
          'time': availableTime,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'sugar': '',
          'cholesterol': '',
          'pressure': '',
        };
        await DatabaseHelper().createAppointment(appointment);
        if (mounted) {
          Navigator.pop(context); // Close sheet
          Navigator.pop(context); // Return to home
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking Confirmed! Time: $availableTime')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setModalState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Nearby Centers Map',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPos,
              initialZoom: 12.0,
              onTap: (tapPosition, point) =>
                  setState(() => _selectedCenter = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bookhealth',
              ),
              MarkerLayer(
                markers: [
                  ..._markers,
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blueAccent,
                        size: 40,
                      ),
                    ),
                ],
              ),
              Positioned(
                bottom: 120, // Above the lab detail card
                right: 20,
                child: FloatingActionButton(
                  onPressed: () {
                    if (_currentLocation != null) {
                      _mapController.move(_currentLocation!, 15.0);
                    } else {
                      _determinePosition();
                    }
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: IgnorePointer(
              ignoring: _selectedCenter == null,
              child: AnimatedOpacity(
                opacity: _selectedCenter != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.biotech,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCenter?['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  _selectedCenter?['address'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedCenter == null
                              ? null
                              : () => _showBookingBottomSheet(_selectedCenter!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF333E53),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            "Book Now",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
