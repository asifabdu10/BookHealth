import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_helper.dart';

class AuthService with ChangeNotifier {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _currentUser;

  Map<String, dynamic>? get currentUser => _currentUser;

  AuthService() {
    _auth.authStateChanges().listen((fbUser) async {
       if (fbUser != null) {
          var userDoc = await _db.collection('users').doc(fbUser.uid).get();
          if (userDoc.exists) {
             _currentUser = userDoc.data();
             _currentUser!['uid'] = fbUser.uid;
             notifyListeners();
          }
       } else {
          _currentUser = null;
          notifyListeners();
       }
    });
  }

  Future<String?> signIn({
    required String email,
    required String password,
    String? role,
  }) async {
    try {
      // 1. Try standard sign-in with FirebaseAuth
      fb_auth.UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      fb_auth.User? fbUser = userCredential.user;
      if (fbUser == null) return "Unknown Error: Authentication failed.";

      var userDoc = await _db.collection('users').doc(fbUser.uid).get();
      if (!userDoc.exists) {
        // Fallback for legacy users
        var emailQuery = await _db.collection('users').where('email', isEqualTo: email).get();
        if (emailQuery.docs.isNotEmpty) {
           await DatabaseHelper().updateUserUID(emailQuery.docs.first.id, fbUser.uid);
           var updatedDoc = await _db.collection('users').doc(fbUser.uid).get();
           _currentUser = updatedDoc.data();
        } else {
           return "User profile not found.";
        }
      } else {
        _currentUser = userDoc.data();
      }

      if (_currentUser != null) {
        _currentUser!['uid'] = fbUser.uid;
        if (role != null && _currentUser!['role'] != role) {
           _auth.signOut();
           return "Access Denied. Incorrect portal for your role.";
        }
      }

      notifyListeners();
      return null; 
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint("Lab Sign In Attempt Error: ${e.code}");

      // --- SEAMLESS MIGRATION REPAIR ---
      // If we get an error suggesting they might be an old user (user not in Auth system yet)
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
         debugPrint("Account has possible migration issue. Checking legacy system for ${email}...");
         final oldUser = await DatabaseHelper().getUserForMigration(email, password);
         
         if (oldUser != null) {
            debugPrint("Match found in legacy system. Attempting automatic migration to Firebase Auth...");
            try {
               fb_auth.UserCredential newCred = await _auth.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
               );
               
               debugPrint("Auth account created. Linking Firestore document...");
               // Link the existing Firestore document to the new UID
               await DatabaseHelper().updateUserUID(oldUser['uid'] ?? oldUser['email'], newCred.user!.uid);
               
               // Re-fetch the newly migrated profile
               var userDoc = await _db.collection('users').doc(newCred.user!.uid).get();
               _currentUser = userDoc.data();
               if (_currentUser != null) {
                  _currentUser!['uid'] = newCred.user!.uid;
               }
               notifyListeners();
               debugPrint("Registration and migration complete!");
               return null; // Migration Success!
            } on fb_auth.FirebaseAuthException catch (signupError) {
               if (signupError.code == 'email-already-in-use') {
                  debugPrint("Email already in Auth system, but sign-in failed. Likely wrong password.");
                  return "Incorrect password for your existing account.";
               }
               debugPrint("Auto-repair failed during creation: $signupError");
               return "Migration failed: ${signupError.message}";
            } catch (signupError) {
               debugPrint("Auto-repair failed: $signupError");
               return "Automatic migration failed. Please contact support.";
            }
         } else {
            // Not in old system either, or old system password doesn't match
            debugPrint("No match in legacy system for ${email}. Returning original error.");
         }
      }

      // Handle specific codes for better UX
      switch (e.code) {
        case 'user-not-found': 
          return "Account does not exist.";
        case 'wrong-password': 
          return "Incorrect password.";
        case 'invalid-credential': 
          // For 'invalid-credential', determine if it's a missing account or just a wrong password
          bool exists = await DatabaseHelper().checkEmailExists(email, role: role);
          return exists ? "The password provided is incorrect." : "Account does not exist.";
        default: 
          return e.message ?? "Authentication failed.";
      }
    } catch (e) {
      debugPrint("Sign In General Error: $e");
      return "Something went wrong during sign-in: $e";
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String role, 
    required String name,
    required String phone,
    String? centerId,
    String status = 'verified',
  }) async {
    try {
      fb_auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      fb_auth.User? fbUser = userCredential.user;
      if (fbUser == null) return "Sign up failed.";

      final newUser = {
        'uid': fbUser.uid,
        'email': email,
        'password': password,
        'role': role,
        'name': name,
        'phone': phone,
        'centerId': centerId,
        'status': status,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await DatabaseHelper().createUser(newUser);
      _currentUser = newUser;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint("Sign Up Error: $e");
      return e.toString();
    }
  }

  // Register User (for Admin use, does not sign in)
  Future<String?> registerUser({
    required String email,
    required String password,
    required String role,
    required String name,
    required String phone,
    String? centerId,
    String status = 'verified',
  }) async {
    try {
      final newUser = {
        'uid': DateTime.now().millisecondsSinceEpoch.toString(), 
        'email': email,
        'password': password,
        'role': role,
        'name': name,
        'phone': phone,
        'centerId': centerId,
        'status': status,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await DatabaseHelper().createUser(newUser);
      return null; 
    } catch (e) {
      debugPrint("Register User Error: $e");
      return e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
