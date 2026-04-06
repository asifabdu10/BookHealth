import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  // User Operations
  Future<String> createUser(Map<String, dynamic> user) async {
    String uid = user['uid'] ?? _db.collection('users').doc().id;
    user['uid'] = uid;
    await _db.collection('users').doc(uid).set(user);
    return uid;
  }

  Future<Map<String, dynamic>?> getUser(String email, String password, {String? role}) async {
    var query = _db
        .collection('users')
        .where('email', isEqualTo: email)
        .where('password', isEqualTo: password);
    
    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }
    
    var snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  Future<bool> checkEmailExists(String email, {String? role}) async {
    var query = _db
        .collection('users')
        .where('email', isEqualTo: email);
    
    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }
    
    var snapshot = await query.get();
    return snapshot.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getCenterById(String id) async {
    var doc = await _db.collection('centers').doc(id).get();
    if (doc.exists) {
      var data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  Future<int> getUserCount() async {
    var snapshot = await _db.collection('users').get();
    return snapshot.docs.where((doc) {
      final status = doc.data()['status'];
      return status != 'pending' && status != 'rejected';
    }).length;
  }

  Future<int> getPatientCount() async {
    var snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<int> getPatientCountStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    var snapshot = await _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((e) => e.data()).where((user) {
      final status = user['status'];
      return status != 'pending' && status != 'rejected';
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getAllUsersStream() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((e) => e.data()).where((user) {
          final status = user['status'];
          return status != 'pending' && status != 'rejected';
        }).toList());
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  // Appointment Operations
  Future<String> createAppointment(Map<String, dynamic> appointment) async {
    var doc = _db.collection('appointments').doc();
    appointment['id'] = doc.id;
    await doc.set(appointment);
    return doc.id;
  }

  Future<List<Map<String, dynamic>>> getAppointmentsForLab(
    String centerId,
  ) async {
    var snapshot = await _db
        .collection('appointments')
        .where('centerId', isEqualTo: centerId)
        .get();
    return snapshot.docs.map((e) {
      var data = e.data();
      data['id'] = e.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getAppointmentsStreamForLab(
    String centerId,
  ) {
    return _db
        .collection('appointments')
        .where('centerId', isEqualTo: centerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((e) {
            var data = e.data();
            data['id'] = e.id;
            return data;
          }).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getAllAppointments() async {
    var snapshot = await _db
        .collection('appointments')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((e) {
      var data = e.data();
      data['id'] = e.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getAllAppointmentsStream() {
    return _db
        .collection('appointments')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((e) {
            var data = e.data();
            data['id'] = e.id;
            return data;
          }).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getAppointmentsForPatient(
    String patientId,
  ) async {
    var snapshot = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .get();
    var list = snapshot.docs.map((e) {
      var data = e.data();
      data['id'] = e.id;
      return data;
    }).toList();
    list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return list;
  }

  Stream<List<Map<String, dynamic>>> getAppointmentsStreamForPatient(
    String patientId,
  ) {
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          var list = snapshot.docs.map((e) {
            var data = e.data();
            data['id'] = e.id;
            return data;
          }).toList();
          list.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
          return list;
        });
  }

  Future<Map<String, dynamic>?> getLatestAppointmentForPatient(
    String patientId,
  ) async {
    var snapshot = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      var list = snapshot.docs.map((e) {
        var data = e.data();
        data['id'] = e.id;
        return data;
      }).toList();
      list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return list.first;
    }
    return null;
  }

  Stream<Map<String, dynamic>?> getLatestAppointmentStreamForPatient(
    String patientId,
  ) {
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            var list = snapshot.docs.map((e) {
              var data = e.data();
              data['id'] = e.id;
              return data;
            }).toList();
            list.sort(
              (a, b) => (b['date'] as String).compareTo(a['date'] as String),
            );
            return list.first;
          }
          return null;
        });
  }

  Future<void> updateAppointment(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.collection('appointments').doc(id).update(updates);
  }

  Future<void> deleteAppointment(String id) async {
    await _db.collection('appointments').doc(id).delete();
  }

  Future<int> getAppointmentCount() async {
    var snapshot = await _db.collection('appointments').count().get();
    return snapshot.count ?? 0;
  }

  Stream<int> getAppointmentCountStream() {
    return _db
        .collection('appointments')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<String?> getNextAvailableSlot(
    String centerId,
    String dateString,
  ) async {
    String datePart = dateString.split('T')[0];

    // Fetch and count locally
    var snapshot = await _db
        .collection('appointments')
        .where('centerId', isEqualTo: centerId)
        .get();

    int count = snapshot.docs.where((doc) {
      String? appointmentDate = doc.data()['date'] as String?;
      return appointmentDate != null && appointmentDate.startsWith(datePart);
    }).length;

    int maxSlots =
        48; // 8 hours * 6 slots/hour (10 mins each from 9 AM to 5 PM)
    if (count >= maxSlots) {
      return null; // No slots available
    }

    int startHour = 9;
    int totalMinutesToAdd = count * 10;
    int additionalHours = totalMinutesToAdd ~/ 60;
    int remainingMinutes = totalMinutesToAdd % 60;

    int currentHour = startHour + additionalHours;

    String period = currentHour >= 12 ? 'PM' : 'AM';
    int displayHour = currentHour > 12 ? currentHour - 12 : currentHour;
    if (displayHour == 0) {
      displayHour = 12;
    }

    String formattedTime =
        "$displayHour:${remainingMinutes.toString().padLeft(2, '0')} $period";

    return formattedTime;
  }

  // Center Operations
  Future<String> createCenter(Map<String, dynamic> center) async {
    String id = center['id'] ?? _db.collection('centers').doc().id;
    center['id'] = id;
    if (center['status'] == null) {
      center['status'] =
          'pending'; // All new labs start as pending for verification
    }
    await _db.collection('centers').doc(id).set(center);
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCenters() async {
    var snapshot = await _db.collection('centers').get();
    return snapshot.docs.map((e) {
      var data = e.data();
      data['id'] = e.id;
      return data;
    }).toList();
  }

  Stream<Map<String, dynamic>?> getCenterStream(String id) {
    return _db.collection('centers').doc(id).snapshots().map((doc) {
      if (doc.exists) {
        var data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    });
  }

  Stream<List<Map<String, dynamic>>> getAllCentersStream() {
    return _db
        .collection('centers')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((e) {
            var data = e.data();
            data['id'] = e.id;
            return data;
          }).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getVerifiedCenters() async {
    var snapshot = await _db
        .collection('centers')
        .where('status', isEqualTo: 'verified')
        .get();
    return snapshot.docs.map((e) {
      var data = e.data();
      data['id'] = e.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getVerifiedCentersStream() {
    return _db
        .collection('centers')
        .where('status', isEqualTo: 'verified')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((e) {
            var data = e.data();
            data['id'] = e.id;
            return data;
          }).toList(),
        );
  }

  Future<void> deleteCenter(String id) async {
    // Cascading delete: Remove all appointments associated with this center
    var appointments = await _db
        .collection('appointments')
        .where('centerId', isEqualTo: id)
        .get();

    for (var doc in appointments.docs) {
      await doc.reference.delete();
    }

    // Cascading delete: Remove all users associated with this center
    var users = await _db
        .collection('users')
        .where('centerId', isEqualTo: id)
        .get();

    for (var doc in users.docs) {
      await doc.reference.delete();
    }

    // Finally delete the center
    await _db.collection('centers').doc(id).delete();
  }

  Future<int> getCenterCount() async {
    var snapshot = await _db
        .collection('centers')
        .where('status', isEqualTo: 'verified')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<int> getCenterCountStream() {
    return _db
        .collection('centers')
        .where('status', isEqualTo: 'verified')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<List<Map<String, dynamic>>> getPendingCenters() async {
    var snapshot = await _db
        .collection('centers')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((e) {
      var data = e.data();
      data['id'] = e.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getPendingCentersStream() {
    return _db
        .collection('centers')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((e) {
            var data = e.data();
            data['id'] = e.id;
            return data;
          }).toList(),
        );
  }

  Stream<int> getPendingCentersCountStream() {
    return _db
        .collection('centers')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> updateCenterStatus(String id, String status) async {
    await _db.collection('centers').doc(id).update({'status': status});
    var users = await _db
        .collection('users')
        .where('centerId', isEqualTo: id)
        .get();
    for (var doc in users.docs) {
      await doc.reference.update({'status': status});
    }
  }

  Future<void> updateCenterCoordinates(String id, double lat, double lng) async {
    await _db.collection('centers').doc(id).update({'lat': lat, 'lng': lng});
  }

  Future<void> updateCenterAddress(String id, String address) async {
    await _db.collection('centers').doc(id).update({'address': address});
  }

  Future<void> updateCenterLocation(
    String id,
    String address,
    double lat,
    double lng,
  ) async {
    await _db.collection('centers').doc(id).update({
      'address': address,
      'lat': lat,
      'lng': lng,
    });
  }

  // BMI History Operations
  Future<void> saveBMI(String userId, double bmi, String status) async {
    await _db.collection('users').doc(userId).collection('bmi_history').add({
      'bmi': bmi,
      'status': status,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> getBMIHistoryStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('bmi_history')
        .orderBy('date', descending: true)
        .limit(3)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<bool> checkCenterEmailExists(String email) async {
    var snapshot = await _db
        .collection('centers')
        .where('email', isEqualTo: email)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // --- MIGRATION REPAIR HELPERS ---

  Future<Map<String, dynamic>?> getUserForMigration(String email, String password) async {
    try {
      var snapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    } catch (e) {
      debugPrint("Migration lookup failed (rules issue): $e");
    }
    return null;
  }

  Future<void> updateUserUID(String oldUID, String newUID) async {
    if (oldUID == newUID) return;
    try {
      var oldDoc = await _db.collection('users').doc(oldUID).get();
      if (oldDoc.exists) {
        var data = oldDoc.data()!;
        data['uid'] = newUID;
        await _db.collection('users').doc(newUID).set(data);
        await _db.collection('users').doc(oldUID).delete();
      }
    } catch (e) {
      debugPrint("UID migration failed: $e");
    }
  }
}
