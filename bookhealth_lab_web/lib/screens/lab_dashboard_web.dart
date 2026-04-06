import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';

class LabDashboardWeb extends StatefulWidget {
  const LabDashboardWeb({super.key});

  @override
  State<LabDashboardWeb> createState() => _LabDashboardWebState();
}

class _LabDashboardWebState extends State<LabDashboardWeb> {
  int _selectedIndex = 0;
  final DatabaseHelper _db = DatabaseHelper();
  DateTimeRange? _filterRange;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  int _historySubIndex = 0; // 0: Completed, 1: Rejected

  void _applyFilter() {
    DateTime? start = DateTime.tryParse(_startController.text);
    DateTime? end = DateTime.tryParse(_endController.text);
    if (start != null && end != null) {
      setState(() {
        _filterRange = DateTimeRange(start: start, end: end);
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _filterRange,
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF2C3E50),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _filterRange = picked;
        _startController.text = picked.start.toIso8601String().split('T')[0];
        _endController.text = picked.end.toIso8601String().split('T')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmall = constraints.maxWidth < 900;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: isSmall
              ? AppBar(
                  backgroundColor: const Color(0xFF2C3E50),
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text(
                    'Laboratory Hub',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                )
              : null,
          drawer: isSmall ? Drawer(child: _sideNav(authService, user)) : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hide navigation Sidebar on small screens (moved to drawer)
              if (!isSmall) _sideNav(authService, user),

              // Main Body Content
              Expanded(
                child: Column(
                  children: [
                    if (!isSmall) _topBar(user),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isSmall ? 20 : 40),
                        child: _mainScreen(user),
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

  Widget _sideNav(AuthService authService, Map<String, dynamic>? user) {
    return Container(
      width: 250,
      color: const Color(0xFF2C3E50),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Center(
            child: HeartbeatLogo(size: 80, color: Colors.white),
          ),
          const SizedBox(height: 15),
          const Text(
            'Laboratoy Hub',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 50),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.getAppointmentsStreamForLab(user?['centerId'] ?? ''),
            builder: (context, snapshot) {
              int pendingCount = 0;
              if (snapshot.hasData) {
                pendingCount = snapshot.data!.where((a) => a['status'] == 'pending').length;
              }
              return _navItem(0, Icons.schedule, 'Daily Requests', badgeCount: pendingCount);
            },
          ),
          _navItem(1, Icons.history, 'Processed Results'),
          if (_selectedIndex == 1) ...[
            _subNavItemSidebar(0, 'Completed Results'),
            _subNavItemSidebar(1, 'Rejected Results'),
          ],
          _navItem(2, Icons.domain, 'My Center'),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () => authService.signOut(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Close drawer on mobile
        }
      },
      child: Container(
        color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.greenAccent : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            if (badgeCount > 0) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topBar(Map<String, dynamic>? user) {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          const HeartbeatLogo(size: 30, color: Color(0xFF024950)),
          const SizedBox(width: 15),
          const Text(
            'Lab Technician Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                user?['name'] ?? 'John Doe',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Center ID: #8872',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(width: 20),
          const CircleAvatar(
            backgroundColor: Colors.green,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _mainScreen(Map<String, dynamic>? user) {
    String? centerId = user?['centerId'];
    if (centerId == null) {
      return const Center(
        child: Text("Error: No Center ID associated with this account."),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _appointmentsView(centerId);
      case 1:
        return _historyView(centerId);
      case 2:
        return _centerView(centerId);
      default:
        return Center(child: Text('Coming soon for Center ID: $centerId'));
    }
  }

  Widget _appointmentsView(String centerId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getAppointmentsStreamForLab(centerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var pendingApps = snapshot.data!
            .where(
              (a) => a['status'] != 'completed' && a['status'] != 'rejected',
            )
            .toList();

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          pendingApps = pendingApps.where((a) {
            final name = (a['patientName']?.toString() ?? '').toLowerCase();
            final email = (a['patientEmail']?.toString() ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
        }

        if (_filterRange != null) {
          pendingApps = pendingApps.where((a) {
            final appDate = DateTime.tryParse(a['date']?.toString() ?? '');
            if (appDate == null) return false;
            // Compare dates only (ignoring time)
            final start = DateTime(
              _filterRange!.start.year,
              _filterRange!.start.month,
              _filterRange!.start.day,
            );
            final end = DateTime(
              _filterRange!.end.year,
              _filterRange!.end.month,
              _filterRange!.end.day,
            );
            final current = DateTime(appDate.year, appDate.month, appDate.day);
            return current.isAtSameMomentAs(start) ||
                current.isAtSameMomentAs(end) ||
                (current.isAfter(start) && current.isBefore(end));
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Header
            Wrap(
              spacing: 20,
              runSpacing: 15,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Daily Patient Requests',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _searchField(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dateInputField('Start (YYYY-MM-DD)', _startController),
                    const SizedBox(width: 10),
                    _dateInputField('End (YYYY-MM-DD)', _endController),
                    IconButton(
                      onPressed: () => _selectDateRange(context),
                      icon: const Icon(
                        Icons.calendar_month,
                        color: Color(0xFF2C3E50),
                      ),
                      tooltip: 'Pick Date Range',
                    ),
                    ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                if (_filterRange != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Filter'),
                    onPressed: () {
                      setState(() => _filterRange = null);
                      _startController.clear();
                      _endController.clear();
                    },
                  ),
                Text(
                  'Total Pending: ${pendingApps.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: pendingApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 60,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _filterRange == null
                                  ? 'No new requests currently.'
                                  : 'No requests found for this range.',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Patient Name')),
                            DataColumn(label: Text('Test Type')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Time Slot')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: pendingApps
                              .map(
                                (app) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(app['patientName'] ?? 'Unknown'),
                                    ),
                                    DataCell(
                                      Text(app['testType'] ?? 'General'),
                                    ),
                                    DataCell(
                                      Text(
                                        app['date']?.toString().split('T')[0] ??
                                            '',
                                      ),
                                    ),
                                    DataCell(Text(app['time'] ?? '')),
                                    DataCell(
                                      _statusChip(app['status'] ?? 'pending'),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.info_outline,
                                              color: Colors.blueAccent,
                                            ),
                                            onPressed: () =>
                                                _showAppointmentDetailsDialog(
                                                  app,
                                                ),
                                            tooltip: 'View Details',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_calendar,
                                              color: Colors.teal,
                                            ),
                                            onPressed: () =>
                                                _showRescheduleDialog(app),
                                            tooltip: 'Reschedule',
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.assignment_add,
                                              size: 16,
                                            ),
                                            label: const Text('Enter Result'),
                                            onPressed: () =>
                                                _showEnterResultsDialog(app),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.cancel,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () =>
                                                _db.updateAppointment(
                                                  app['id'],
                                                  {'status': 'rejected'},
                                                ),
                                            tooltip: 'Reject',
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status == 'pending'
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: status == 'pending' ? Colors.orange : Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _historyView(String centerId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getAppointmentsStreamForLab(centerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var history = snapshot.data!
            .where(
              (a) => _historySubIndex == 0
                  ? a['status'] == 'completed'
                  : a['status'] == 'rejected',
            )
            .toList();

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          history = history.where((a) {
            final name = (a['patientName']?.toString() ?? '').toLowerCase();
            final email = (a['patientEmail']?.toString() ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
        }

        if (_filterRange != null) {
          history = history.where((a) {
            final appDate = DateTime.tryParse(a['date']?.toString() ?? '');
            if (appDate == null) return false;
            final start = DateTime(
              _filterRange!.start.year,
              _filterRange!.start.month,
              _filterRange!.start.day,
            );
            final end = DateTime(
              _filterRange!.end.year,
              _filterRange!.end.month,
              _filterRange!.end.day,
            );
            final current = DateTime(appDate.year, appDate.month, appDate.day);
            return current.isAtSameMomentAs(start) ||
                current.isAtSameMomentAs(end) ||
                (current.isAfter(start) && current.isBefore(end));
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Header for Processed Results
            Wrap(
              spacing: 20,
              runSpacing: 15,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _historySubIndex == 0
                      ? 'Completed Results'
                      : 'Rejected Requests',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _searchField(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dateInputField('Start (YYYY-MM-DD)', _startController),
                    const SizedBox(width: 10),
                    _dateInputField('End (YYYY-MM-DD)', _endController),
                    IconButton(
                      onPressed: () => _selectDateRange(context),
                      icon: const Icon(
                        Icons.calendar_month,
                        color: Color(0xFF2C3E50),
                      ),
                      tooltip: 'Pick Date Range',
                    ),
                    ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                if (_filterRange != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Filter'),
                    onPressed: () {
                      setState(() => _filterRange = null);
                      _startController.clear();
                      _endController.clear();
                    },
                  ),
                Text(
                  _historySubIndex == 0
                      ? 'Total Completed: ${history.length}'
                      : 'Total Rejected: ${history.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _historySubIndex == 0
                        ? Colors.green
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.history,
                              size: 60,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _filterRange == null
                                  ? (_historySubIndex == 0
                                        ? 'No completed results yet.'
                                        : 'No rejected requests.')
                                  : 'No matches found in this date range.',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Patient')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Notes')),
                          ],
                          rows: history
                              .map(
                                (app) => DataRow(
                                  cells: [
                                    DataCell(Text(app['patientName'] ?? '')),
                                    DataCell(
                                      Text(
                                        app['date']?.toString().split('T')[0] ??
                                            '',
                                      ),
                                    ),
                                    DataCell(_statusChip(app['status'] ?? '')),
                                    DataCell(
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              app['results'] ?? 'No notes',
                                              style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black54,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (app['status'] == 'completed')
                                            TextButton(
                                              onPressed: () =>
                                                  _showResultsViewDialog(app),
                                              child: const Text(
                                                'View Full Result',
                                                style: TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAppointmentDetailsDialog(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Patient Appointment Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Patient Name', app['patientName'] ?? 'Unknown'),
            _detailRow('Phone Number', app['patientPhone'] ?? 'N/A'),
            _detailRow('Email', app['patientEmail'] ?? 'N/A'),
            const Divider(height: 30),
            _detailRow('Test Requested', app['testType'] ?? 'General Lab Test'),
            _detailRow(
              'Scheduled Date',
              app['date']?.toString().split('T')[0] ?? '',
            ),
            _detailRow('Current Slot', app['time'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(Map<String, dynamic> app) {
    final timeController = TextEditingController(text: app['time'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reschedule Booking Time',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the new time for this patient to arrive.'),
            const SizedBox(height: 20),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'New Time (e.g. 10:30 AM)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _db.updateAppointment(app['id'], {
                'time': timeController.text,
                'isRescheduled': true,
                'hasPatientSeenUpdate': false,
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Schedule'),
          ),
        ],
      ),
    );
  }

  void _showEnterResultsDialog(Map<String, dynamic> app) {
    final sugarController = TextEditingController(
      text: app['sugar']?.toString() ?? '',
    );
    final cholesterolController = TextEditingController(
      text: app['cholesterol']?.toString() ?? '',
    );
    final pressureController = TextEditingController(
      text: app['pressure']?.toString() ?? '',
    );
    final resultsController = TextEditingController(text: app['results'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Enter Test Results & Complete',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please provide health metrics and final observations.',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sugarController,
                        decoration: const InputDecoration(
                          labelText: 'Sugar (mg/dL)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: cholesterolController,
                        decoration: const InputDecoration(
                          labelText: 'Cholesterol',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: pressureController,
                  decoration: const InputDecoration(
                    labelText: 'Blood Pressure (mmHg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: resultsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'General Technician Notes',
                    hintText: 'Any other observations...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (sugarController.text.isEmpty &&
                  cholesterolController.text.isEmpty &&
                  pressureController.text.isEmpty &&
                  resultsController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Error: You must provide at least one result or note before completing.",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              _db.updateAppointment(app['id'], {
                'status': 'completed',
                'sugar': sugarController.text,
                'cholesterol': cholesterolController.text,
                'pressure': pressureController.text,
                'results': resultsController.text,
                'completedAt': DateTime.now().toIso8601String(),
                'hasPatientSeenUpdate': false,
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete & Send to Patient'),
          ),
        ],
      ),
    );
  }

  Widget _centerView(String centerId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _db.getCenterById(centerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final center = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            bool isWide = constraints.maxWidth > 800;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Laboratory Center',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 40),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _centerDetails(center)),
                          const SizedBox(width: 30),
                          Expanded(flex: 3, child: _centerMap(center)),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _centerDetails(center),
                          const SizedBox(height: 30),
                          _centerMap(center),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditLocationDialog(Map<String, dynamic> center) {
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
          title: const Text('Update Laboratory Location'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    labelText: 'Full Street Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Google Maps Coordinates:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: coordinatesController,
                  decoration: const InputDecoration(
                    labelText: 'Paste Lat, Lng',
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
                      label: const Text('Search Address on Maps'),
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
                      label: const Text('View by coordinates'),
                    ),
                  ],
                ),
                const Text(
                  'Note: Updating your location will reflect immediately for patients.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
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
                    const SnackBar(
                      content: Text(
                        'Laboratory location updated successfully!',
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Location'),
            ),
          ],
        );
      },
    );
  }

  Widget _centerDetails(Map<String, dynamic> center) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Center Name', center['name'] ?? 'N/A'),
          _detailRow('Email Address', center['email'] ?? 'N/A'),
          _detailRow('Phone Number', center['phone'] ?? 'N/A'),
          //detailRow('Status', center['status'] ?? 'pending'),
          const Divider(height: 40),
          const Text(
            'Address:',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            center['address'] ?? 'No address registered',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showEditLocationDialog(center),
            icon: const Icon(Icons.edit_location_alt, size: 18),
            label: const Text('Edit Address / Map Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerMap(Map<String, dynamic> center) {
    // Try 'lat'/'lng' then 'latitude'/'longitude'
    double? lat = double.tryParse(center['lat']?.toString() ?? '');
    lat ??= double.tryParse(center['latitude']?.toString() ?? '');

    double? lng = double.tryParse(center['lng']?.toString() ?? '');
    lng ??= double.tryParse(center['longitude']?.toString() ?? '');

    if (lat == null || lng == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(child: Text('Map location not available')),
      );
    }

    return Container(
      height: 450,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bookhealth',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.pinkAccent,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showFullMapDialog(center, lat!, lng!),
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('View Full Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2C5364),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullMapDialog(Map<String, dynamic> center, double lat, double lng) {
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
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.science,
                      color: Color(0xFF2C5364),
                      size: 30,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            center['name'] ?? 'Laboratory Center',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C5364),
                            ),
                          ),
                          Text(
                            center['address'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
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
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.bookhealth',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lng),
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.pinkAccent,
                              size: 60,
                            ),
                          ),
                        ],
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showResultsViewDialog(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Test Results for ${app['patientName']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(
              'Completion Date',
              app['completedAt']?.toString().split('T')[0] ?? 'N/A',
            ),
            const Divider(),
            _detailRow('Sugar Level', '${app['sugar'] ?? 'N/A'} mg/dL'),
            _detailRow('Cholesterol', app['cholesterol'] ?? 'N/A'),
            _detailRow('Blood Pressure', '${app['pressure'] ?? 'N/A'} mmHg'),
            const Divider(),
            const Text(
              'Technician Notes:',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                app['results'] ?? 'No specific notes recorded.',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      width: 300,
      height: 40,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Name or Email...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: const OutlineInputBorder(),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _dateInputField(String label, TextEditingController controller) {
    return SizedBox(
      width: 180,
      height: 40,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _subNavItemSidebar(int index, String label) {
    bool isSelected = _historySubIndex == index;
    return InkWell(
      onTap: () => setState(() => _historySubIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 50),
        color: isSelected
            ? Colors.greenAccent.withValues(alpha: 0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              index == 0 ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 16,
              color: isSelected ? Colors.greenAccent : Colors.white54,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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
