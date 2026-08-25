import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/firestore_paths.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Signs up a student using an access code tied to a specific course.
  /// Throws an Exception with a user-facing message on failure.
  Future<void> signUpWithAccessCode({
    required String name,
    required String email,
    required String password,
    required String accessCode,
  }) async {
    // 1. Find the course with this access code
    final courseQuery = await _firestore
        .collection(FirestorePaths.courses)
        .where('accessCode', isEqualTo: accessCode.trim())
        .limit(1)
        .get();

    if (courseQuery.docs.isEmpty) {
      throw Exception(
        'Invalid access code. Please check with your instructor.',
      );
    }

    final courseDoc = courseQuery.docs.first;

    // 2. Create the Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // 3. Create the user's Firestore profile
    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': 'student',
      'enrolledCourses': [courseDoc.id],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Add student to the course's studentIds
    await courseDoc.reference.update({
      'studentIds': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetches the logged-in user's role from Firestore.
  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .get();
    return doc.data()?['role'] as String?;
  }
}
