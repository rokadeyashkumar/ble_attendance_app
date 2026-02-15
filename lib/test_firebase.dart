import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> testFirebaseConnection() async {
  print('🧪 Testing Firebase connection...');
  
  try {
    // Test Auth
    print('📱 Testing Firebase Auth...');
    final auth = FirebaseAuth.instance;
    print('✅ Auth instance created');
    
    // Test Firestore
    print('💾 Testing Firestore...');
    final firestore = FirebaseFirestore.instance;
    final testDoc = await firestore.collection('users').limit(1).get();
    print('✅ Firestore connected. Found ${testDoc.docs.length} documents');
    
    // Try login
    print('🔐 Testing login...');
    UserCredential result = await auth.signInWithEmailAndPassword(
      email: 'yash@nit.edu.in',
      password: 'student123',
    );
    print('✅ Login successful! UID: ${result.user!.uid}');
    
    // Get user doc
    DocumentSnapshot doc = await firestore
        .collection('users')
        .doc(result.user!.uid)
        .get();
    print('📄 User document exists: ${doc.exists}');
    
    if (doc.exists) {
      print('📋 User data: ${doc.data()}');
    }
    
    await auth.signOut();
    print('✅ Test completed successfully!');
    
  } catch (e) {
    print('❌ Test failed: $e');
  }
}