import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_helper.dart';

class AuthService with ChangeNotifier {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _currentUser;
  bool _isAutoLoggingIn = true;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAutoLoggingIn => _isAutoLoggingIn;

  AuthService() {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      fb_auth.User? fbUser = _auth.currentUser;
      if (fbUser != null) {
        // Fetch additional user data from Firestore
        var userDoc = await _db.collection('users').doc(fbUser.uid).get();
        if (userDoc.exists) {
          _currentUser = userDoc.data();
          _currentUser!['uid'] = fbUser.uid; // Ensure UID is correct
        }
      }
    } catch (e) {
      debugPrint("Auto Login Error: $e");
    } finally {
      _isAutoLoggingIn = false;
      notifyListeners();
    }
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

      // 2. Fetch profile from Firestore to verify role
      var userDoc = await _db.collection('users').doc(fbUser.uid).get();
      if (!userDoc.exists) {
        // Fallback: If UID doc doesn't exist, try looking up by email (in case doc was seeded with custom ID)
        var emailQuery = await _db.collection('users').where('email', isEqualTo: email).get();
        if (emailQuery.docs.isNotEmpty) {
           // We found a match in Firestore! Migrate it to the new UID.
           await DatabaseHelper().updateUserUID(emailQuery.docs.first.id, fbUser.uid);
           var updatedDoc = await _db.collection('users').doc(fbUser.uid).get();
           _currentUser = updatedDoc.data();
        } else {
           return "User profile not found in database.";
        }
      } else {
        _currentUser = userDoc.data();
      }

      if (_currentUser != null) {
        _currentUser!['uid'] = fbUser.uid;
        // Role check
        if (role != null && _currentUser!['role'] != role) {
           return "Access Denied. Incorrect portal for your role.";
        }
      }

      notifyListeners();
      return null; // Success
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint("Sign In Attempt Error: ${e.code}");
      
      // --- SEAMLESS MIGRATION REPAIR ---
      // If user not found in Auth, check if they exist in Firestore (from old system)
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
         debugPrint("User not in Auth. Checking Firestore migration database...");
         final oldUser = await DatabaseHelper().getUserForMigration(email, password);
         if (oldUser != null) {
            // Found a match! Create their FirebaseAuth account and migrate.
            debugPrint("Old user found! Repairing FirebaseAuth account...");
            try {
               fb_auth.UserCredential newCred = await _auth.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
               );
               // Link the existing Firestore document to the new UID
               await DatabaseHelper().updateUserUID(oldUser['uid'], newCred.user!.uid);
               
               // Now fetch the repaired profile
               var userDoc = await _db.collection('users').doc(newCred.user!.uid).get();
               _currentUser = userDoc.data();
               notifyListeners();
               return null; // Successfully repaired and logged in!
            } catch (signupError) {
               debugPrint("Auto-repair failed: $signupError");
               return "Login error. Please use Sign Up.";
            }
         }
      }

      // Handle specific codes for better UX
      switch (e.code) {
        case 'user-not-found': 
          return "Account does not exist.";
        case 'wrong-password': 
          return "Incorrect password.";
        case 'invalid-email': 
          return "The email address is invalid.";
        case 'invalid-credential':
          // For 'invalid-credential', determine if it's a missing account or just a wrong password
          bool exists = await DatabaseHelper().checkEmailExists(email);
          return exists ? "Incorrect password." : "Account does not exist.";
        default: 
          return e.message ?? "Authentication failed.";
      }
    } catch (e) {
      debugPrint("Sign In General Error: $e");
      return e.toString();
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String role, 
    required String name,
    required String phone,
    String status = 'verified',
  }) async {
    try {
      // 1. Create user in FirebaseAuth
      fb_auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      fb_auth.User? fbUser = userCredential.user;
      if (fbUser == null) return "Unknown Error: Sign up failed.";

      // 2. Store profile in Firestore
      final newUser = {
        'uid': fbUser.uid,
        'email': email,
        'password': password, // Still saving locally for reference or backward compatibility if needed, but not for signin
        'role': 'patient', // Enforce patient role on mobile signup
        'name': name,
        'phone': phone,
        'status': status,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await DatabaseHelper().createUser(newUser);

      _currentUser = newUser;
      notifyListeners();
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint("Sign Up Error: ${e.code}");
      switch (e.code) {
        case 'email-already-in-use': return "This email is already registered.";
        case 'weak-password': return "The password is too weak.";
        default: return e.message ?? "Sign up failed.";
      }
    } catch (e) {
      debugPrint("Sign Up Error: $e");
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
