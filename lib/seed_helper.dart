import 'package:flutter/foundation.dart';
import 'services/database_helper.dart';

Future<void> seedAdmin() async {
  try {
    final db = DatabaseHelper();
    // final count = await db.getUserCount(); // Not needed anymore

    // Check if there are any users. If no users, we should create at least one admin.
    // Or specifically check for admin email.
    final adminUser = await db.getUser('admin@bookhealth.com', 'admin123');

    if (adminUser == null) {
      debugPrint("Seeding admin user...");
      await db.createUser({
        'uid': 'admin_default_id',
        'email': 'admin@bookhealth.com',
        'password': 'admin123',
        'role': 'admin',
        'name': 'System Administrator',
        'phone': '0000000000',
        'createdAt': DateTime.now().toIso8601String(),
      });
      debugPrint("Admin user seeded successfully!");
    } else {
      debugPrint("Admin user already exists.");
    }
  } catch (e) {
    debugPrint("Error seeding admin user: $e");
  }
}
