import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn(String email, String password, String expectedRole) async {
    try {
      print('🔐 Attempting login for: $email');
      
      // Sign in to Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Auth successful, UID: ${userCredential.user!.uid}');

      // Get user data from Firestore
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      print('📄 Firestore document exists: ${doc.exists}');

      if (!doc.exists) {
        await _auth.signOut();
        print('❌ User document not found in Firestore');
        return {'success': false, 'message': 'User data not found. Please contact administrator.'};
      }

      UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      print('👤 User role: ${user.role}, Expected: $expectedRole');

      // Check if role matches
      if (user.role != expectedRole) {
        await _auth.signOut();
        print('❌ Role mismatch');
        return {
          'success': false,
          'message': 'Invalid credentials for $expectedRole login'
        };
      }

      print('✅ Login successful for ${user.name}');
      return {'success': true, 'user': user};
      
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuth error: ${e.code} - ${e.message}');
      String message = 'An error occurred';
      
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid email or password';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Check your internet connection';
      } else {
        message = e.message ?? 'Authentication failed';
      }
      
      return {'success': false, 'message': message};
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {'success': false, 'message': 'Unexpected error: ${e.toString()}'};
    }
  }

  // Get current user data
  Future<UserModel?> getCurrentUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      return true;
    } catch (e) {
      print('❌ Error updating profile: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}