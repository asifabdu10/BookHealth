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
    // Strictly enforce admin email check if the role is admin
    if (role == 'admin' && email != 'bookhealth777@gmail.com') {
      return "Unauthorized Admin Account";
    }

    try {
      // 1. Try standard sign-in with FirebaseAuth
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // We need to ensure the profile exists and is linked properly
      fb_auth.User? fbUser = _auth.currentUser;
      if (fbUser != null) {
        var userDoc = await _db.collection('users').doc(fbUser.uid).get();
        if (!userDoc.exists) {
           // Fallback email lookup for legacy data
           var emailQuery = await _db.collection('users').where('email', isEqualTo: email).get();
           if (emailQuery.docs.isNotEmpty) {
              await DatabaseHelper().updateUserUID(emailQuery.docs.first.id, fbUser.uid);
           }
        }
      }

      return null; 
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint("Admin Sign In Attempt Error: ${e.code}");

      // --- SEAMLESS MIGRATION REPAIR ---
      // If we get an error suggesting they might be an old user (user not in Auth system yet)
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
         debugPrint("Account has possible migration/password issue. Checking legacy system for ${email}...");
         final oldUser = await DatabaseHelper().getUserForMigration(email, password);
         
         if (oldUser != null) {
            debugPrint("Match found in legacy system. Attempting automatic migration to Firebase Auth...");
            try {
               fb_auth.UserCredential newCred = await _auth.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
               );
               
               // Link the existing Firestore document to the new UID
               await DatabaseHelper().updateUserUID(oldUser['uid'], newCred.user!.uid);
               
               return null; // Migration Success!
            } catch (signupError) {
               debugPrint("Auto-repair failed during creation: $signupError");
               return "Automatic migration failed. Your account exists in the old system but we couldn't upgrade it.";
            }
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
          return exists ? "Incorrect password. Please try again." : "Account does not exist.";
        default: 
          return e.message ?? "Authentication failed.";
      }
    } catch (e) {
      debugPrint("Sign In General Error: $e");
      return "Something went wrong during sign-in: $e";
    }
  }

  // Finalize login after OTP verification
  void setAuthUser(Map<String, dynamic> user) {
    _currentUser = user;
    notifyListeners();
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
      // Note: We can't use createUserWithEmailAndPassword here safely without signing out the admin.
      // For "registering" other users from an admin panel, usually we use Firebase Admin SDK or Cloud Functions.
      // As a fallback, we'll store it in Firestore and hope they verify or we can add it later.
      // Best practice is to use standard signup or admin functions.
      
      final newUser = {
        'uid': DateTime.now().millisecondsSinceEpoch.toString(), // Placeholder until real Auth account created
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
