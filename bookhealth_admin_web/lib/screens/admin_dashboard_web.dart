import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/email_service.dart';

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb> {
  int _selectedIndex = 0;
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _labSearchController = TextEditingController();
  String _userSearchQuery = "";
  String _labSearchQuery = "";

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmall = constraints.maxWidth < 1000;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: isSmall
              ? AppBar(
                  backgroundColor: const Color(0xFF1E282C),
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text(
                    'Admin Console',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                )
              : null,
          drawer: isSmall ? Drawer(child: _sideBar(authService)) : null,
          body: Row(
            children: [
              // Standard Side Navigation
              if (!isSmall) _sideBar(authService),

              // Main Dynamic Content Area
              Expanded(
                child: Column(
                  children: [
                    // Top Header Overlay
                    if (!isSmall) _header(authService),
                    // Scrollable Content Pane
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isSmall ? 20 : 40),
                        child: _mainContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sideBar(AuthService authService) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF1E282C),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          const Center(
            child: HeartbeatLogo(size: 80, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'BookHealth Admin',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 50),
          _navItem(0, Icons.dashboard, 'Overview'),
          _navItem(1, Icons.people, 'Patient Management'),
          _navItem(
            2,
            Icons.domain_verification,
            'Pending Verifications',
            badgeStream: _db.getPendingCentersCountStream(),
          ),
          _navItem(3, Icons.science, 'Partner Labs'),
          _navItem(4, Icons.calendar_month, 'All Appointments'),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: () => authService.signOut(),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _userSearchField() {
    return SizedBox(
      width: 350,
      height: 45,
      child: TextField(
        controller: _userSearchController,
        decoration: InputDecoration(
          hintText: 'Search user by name or email...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _userSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _userSearchController.clear();
                    setState(() => _userSearchQuery = "");
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onChanged: (val) => setState(() => _userSearchQuery = val),
      ),
    );
  }

  Widget _labSearchField() {
    return SizedBox(
      width: 350,
      height: 45,
      child: TextField(
        controller: _labSearchController,
        decoration: InputDecoration(
          hintText: 'Search lab by name or email...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _labSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _labSearchController.clear();
                    setState(() => _labSearchQuery = "");
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onChanged: (val) => setState(() => _labSearchQuery = val),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    String label, {
    Stream<int>? badgeStream,
  }) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Close drawer on mobile
        }
      },
      child: Container(
        color: isSelected
            ? Colors.blueAccent.withValues(alpha: 0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white70),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (badgeStream != null)
              StreamBuilder<int>(
                stream: badgeStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data! > 0) {
                    return Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        snapshot.data.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(AuthService authService) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const HeartbeatLogo(size: 30, color: Color(0xFF024950)),
          const SizedBox(width: 15),
          Text(
            _getHeading(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          StreamBuilder<int>(
            stream: _db.getPendingCentersCountStream(),
            builder: (context, snapshot) {
              int count = snapshot.data ?? 0;
              return Stack(
                children: [
                  const Icon(Icons.notifications_none, color: Colors.black54),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 30),
          const CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 15),
          const Text(
            'Administrator',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getHeading() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'Patient Management';
      case 2:
        return 'Pending Verifications';
      case 3:
        return 'Partner Labs Directory';
      case 4:
        return 'Appointment Overseer';
      default:
        return 'Admin Console';
    }
  }

  Widget _mainContent() {
    switch (_selectedIndex) {
      case 0:
        return _overviewGrid();
      case 1:
        return _usersTable();
      case 2:
        return _pendingVerificationsTable();
      case 3:
        return _partneredLabsTable();
      case 4:
        return _appointmentsTable();
      default:
        return _overviewGrid();
    }
  }

  Widget _overviewGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            bool isSmall = constraints.maxWidth < 1000;
            return Wrap(
              spacing: 25,
              runSpacing: 25,
              children: [
                _statCard(
                  'Total Patients',
                  _db.getPatientCountStream(),
                  Icons.people,
                  Colors.blue,
                  isSmall,
                ),
                _statCard(
                  'Partner Labs',
                  _db.getCenterCountStream(),
                  Icons.science,
                  Colors.green,
                  isSmall,
                ),
                _statCard(
                  'Total Bookings',
                  _db.getAppointmentCountStream(),
                  Icons.calendar_today,
                  Colors.orange,
                  isSmall,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 40),
        const Text(
          "Recent System Activity",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _appointmentsTable(limit: 5), // Show top 5 on overview
      ],
    );
  }

  Widget _statCard(
    String title,
    Stream<int> stream,
    IconData icon,
    Color color,
    bool isSmall,
  ) {
    return Container(
      width: isSmall ? double.infinity : 320,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 25),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 5),
                  Text(
                    snapshot.hasData ? snapshot.data.toString() : '...',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _usersTable() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getAllUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        var patients = snapshot.data!
            .where((u) => u['role'] == 'patient')
            .toList();

        if (_userSearchQuery.isNotEmpty) {
          final query = _userSearchQuery.toLowerCase();
          patients = patients.where((u) {
            final name = (u['name']?.toString() ?? '').toLowerCase();
            final email = (u['email']?.toString() ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Registered Patients: ${patients.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _userSearchField(),
                ],
              ),
              const Divider(height: 30),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Joined on')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: patients
                      .map(
                        (user) => DataRow(
                          cells: [
                            DataCell(Text(user['name'] ?? '')),
                            DataCell(Text(user['email'] ?? '')),
                            DataCell(Text(user['phone'] ?? '')),
                            DataCell(
                              Text(
                                user['createdAt']?.toString().split('T')[0] ??
                                    '',
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _db.deleteUser(user['uid']),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchGoogleMaps(Map<String, dynamic> center) async {
    double lat = (center['lat'] as num?)?.toDouble() ?? 0.0;
    double lng = (center['lng'] as num?)?.toDouble() ?? 0.0;
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _pendingVerificationsTable() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getAllCentersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        var centers = snapshot.data!
            .where((c) => c['status'] == 'pending')
            .toList();

        if (_labSearchQuery.isNotEmpty) {
          final query = _labSearchQuery.toLowerCase();
          centers = centers.where((c) {
            final name = (c['name']?.toString() ?? '').toLowerCase();
            final email = (c['email']?.toString() ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pending Lab Verifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _labSearchField(),
                ],
              ),
              const Divider(height: 30),
              if (centers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No pending verifications at the moment.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Lab Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Address')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: centers.map((center) {
                      return DataRow(
                        cells: [
                          DataCell(Text(center['name'] ?? '')),
                          DataCell(Text(center['email'] ?? '')),
                          DataCell(
                            SizedBox(
                              width: 300,
                              child: InkWell(
                                onTap: () => _launchGoogleMaps(center),
                                child: Text(
                                  center['address'] ?? '',
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueAccent,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () =>
                                      _showVerificationDialog(center),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Check & Verify'),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _db.deleteCenter(center['id']),
                                  tooltip: 'Reject/Delete Lab',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _partneredLabsTable() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getAllCentersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        var centers = snapshot.data!
            .where((c) => c['status'] == 'verified')
            .toList();

        if (_labSearchQuery.isNotEmpty) {
          final query = _labSearchQuery.toLowerCase();
          centers = centers.where((c) {
            final name = (c['name']?.toString() ?? '').toLowerCase();
            final email = (c['email']?.toString() ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Partnered Labs Directory',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('View Labs on Map'),
                        onPressed: () => _showGlobalMapDialog(centers),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _labSearchField(),
                ],
              ),
              const Divider(height: 30),
              if (centers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No partnered labs verified yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Lab Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Address')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: centers.map((center) {
                      return DataRow(
                        cells: [
                          DataCell(Text(center['name'] ?? '')),
                          DataCell(Text(center['email'] ?? '')),
                          DataCell(
                            SizedBox(
                              width: 300,
                              child: InkWell(
                                onTap: () => _launchGoogleMaps(center),
                                child: Text(
                                  center['address'] ?? '',
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueAccent,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_note,
                                    color: Colors.blueAccent,
                                    size: 22,
                                  ),
                                  onPressed: () => _showEditLabDialog(center),
                                  tooltip: 'Edit Lab Location',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _db.deleteCenter(center['id']),
                                  tooltip: 'Delete Lab',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditLabDialog(Map<String, dynamic> center) {
    TextEditingController coordinatesController = TextEditingController(
      text: "${center['lat'] ?? ''}, ${center['lng'] ?? ''}",
    );
    TextEditingController addressController = TextEditingController(
      text: center['address'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Registered Lab: ${center['name']}'),
          content: SizedBox(
            width: 500,
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Physical Address:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Full Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Google Maps Pointer:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: coordinatesController,
                  decoration: const InputDecoration(
                    labelText: 'Paste Coordinates (Lat, Lng)',
                    hintText: 'e.g., 10.123, 76.456',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final String query = addressController.text.trim();
                        final String googleMapsUrl =
                            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
                        if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                          await launchUrl(Uri.parse(googleMapsUrl));
                        }
                      },
                      icon: const Icon(Icons.location_city, size: 16),
                      label: const Text('Search by Address'),
                    ),
                    const SizedBox(width: 5),
                    TextButton.icon(
                      onPressed: () async {
                        final String query = coordinatesController.text.trim();
                        final String googleMapsUrl =
                            'https://www.google.com/maps/search/?api=1&query=$query';
                        if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                          await launchUrl(Uri.parse(googleMapsUrl));
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('View by Coordinates'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                double parsedLat = (center['lat'] as num?)?.toDouble() ?? 0.0;
                double parsedLng = (center['lng'] as num?)?.toDouble() ?? 0.0;

                final String coordString = coordinatesController.text.trim();
                if (coordString.contains(',')) {
                  final parts = coordString.split(',');
                  if (parts.length >= 2) {
                    parsedLat = double.tryParse(parts[0].trim()) ?? parsedLat;
                    parsedLng = double.tryParse(parts[1].trim()) ?? parsedLng;
                  }
                }

                await _db.updateCenterLocation(
                  center['id'],
                  addressController.text.trim(),
                  parsedLat,
                  parsedLng,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${center['name']} location updated!'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  void _showVerificationDialog(Map<String, dynamic> center) {
    TextEditingController coordinatesController = TextEditingController(
      text: "${center['lat'] ?? ''}, ${center['lng'] ?? ''}",
    );
    TextEditingController addressController = TextEditingController(
      text: center['address'] ?? '',
    );

    double lat = (center['lat'] as num?)?.toDouble() ?? 25.2048;
    double lng = (center['lng'] as num?)?.toDouble() ?? 55.2708;
    LatLng point = LatLng(lat, lng);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Verify Location: ${center['name']}'),
          content: SizedBox(
            width: 500,
            height: 500, // Taller dialog
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Info:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Email: ${center['email']} | Phone: ${center['phone']}'),
                const SizedBox(height: 15),
                const Text(
                  'Physical Address:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Full Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Google Maps Pointer:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: coordinatesController,
                  decoration: const InputDecoration(
                    labelText: 'Paste Coordinates (Lat, Lng)',
                    hintText: 'e.g., 10.123, 76.456',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lab Map Location:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final String query = addressController.text.trim();
                            final String googleMapsUrl =
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
                            if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                              await launchUrl(Uri.parse(googleMapsUrl));
                            }
                          },
                          icon: const Icon(Icons.location_city, size: 16),
                          label: const Text('Search by Address'),
                        ),
                        const SizedBox(width: 5),
                        TextButton.icon(
                          onPressed: () async {
                            final String query = coordinatesController.text
                                .trim();
                            final String googleMapsUrl =
                                'https://www.google.com/maps/search/?api=1&query=$query';
                            if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                              await launchUrl(Uri.parse(googleMapsUrl));
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('View by Coordinates'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: point,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel / Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );

                // Parse manual coordinates from single input
                double parsedLat = lat;
                double parsedLng = lng;

                final String coordString = coordinatesController.text.trim();
                if (coordString.contains(',')) {
                  final parts = coordString.split(',');
                  if (parts.length >= 2) {
                    parsedLat = double.tryParse(parts[0].trim()) ?? lat;
                    parsedLng = double.tryParse(parts[1].trim()) ?? lng;
                  }
                }

                // Create the actual user account ONLY after admin verifies it
                await authService.registerUser(
                  email: center['email'] ?? '',
                  password: center['pendingPassword'] ?? 'default123',
                  role: 'lab_tech',
                  name: center['name'] ?? '',
                  phone: center['phone'] ?? '',
                  centerId: center['id'],
                  status: 'verified', // Set strictly to verified upon creation
                );

                await _db.updateCenterStatus(center['id'], 'verified');
                await _db.updateCenterLocation(
                  center['id'],
                  addressController.text.trim(),
                  parsedLat,
                  parsedLng,
                );

                // Send Verification Email to Lab
                EmailService().sendVerificationSuccessEmail(
                  email: center['email'] ?? '',
                  labName: center['name'] ?? 'Laboratory',
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${center['name']} successfully verified!'),
                    ),
                  );
                  setState(
                    () => _selectedIndex = 3,
                  ); // Auto-redirect to Partnered Labs
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve & Verify'),
            ),
          ],
        );
      },
    );
  }

  Widget _appointmentsTable({int? limit}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getAllAppointmentsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        var appointments = snapshot.data!;
        if (limit != null && appointments.length > limit) {
          appointments = appointments.take(limit).toList();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (limit == null)
                const Text(
                  'System-Wide Appointments',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              if (limit == null) const Divider(height: 30),
              if (appointments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No appointments present.',
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Patient')),
                      DataColumn(label: Text('Lab Center')),
                      DataColumn(label: Text('Date & Time')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: appointments
                        .map(
                          (app) => DataRow(
                            cells: [
                              DataCell(Text(app['patientName'] ?? 'No Name')),
                              DataCell(
                                Text(app['centerName'] ?? 'Unknown Lab'),
                              ),
                              DataCell(
                                Text(
                                  "${app['date']?.toString().split('T')[0]} - ${app['time']}",
                                ),
                              ),
                              DataCell(Text(app['status'] ?? 'Pending')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _db.deleteAppointment(app['id']),
                                  tooltip: 'Delete Appointment',
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showGlobalMapDialog(List<Map<String, dynamic>> centers) {
    if (centers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No verified labs found to display on map.'),
        ),
      );
      return;
    }

    // Default to first lab's location or reasonable center
    double initialLat = 10.0; // Default center
    double initialLng = 76.0;

    if (centers.isNotEmpty) {
      initialLat =
          double.tryParse(centers[0]['lat']?.toString() ?? '10.0') ?? 10.0;
      initialLng =
          double.tryParse(centers[0]['lng']?.toString() ?? '76.0') ?? 76.0;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.public,
                      color: Colors.blueAccent,
                      size: 30,
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Text(
                        'Global Laboratories Map',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(initialLat, initialLng),
                      initialZoom: 7,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.bookhealth_admin',
                      ),
                      MarkerLayer(
                        markers: centers.map((c) {
                          double? lat = double.tryParse(
                            c['lat']?.toString() ?? '',
                          );
                          double? lng = double.tryParse(
                            c['lng']?.toString() ?? '',
                          );
                          if (lat == null || lng == null)
                            return Marker(
                              point: const LatLng(0, 0),
                              child: const SizedBox(),
                            );

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 50,
                            height: 50,
                            child: Tooltip(
                              message: c['name'] ?? 'Lab',
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 35,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
