import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donor/donor_profile.dart';

class DonorProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _donorsRef =>
      _firestore.collection('donors');

  /// Fetches the profile document for [uid].
  /// Returns null if the document does not exist.
  Future<DonorProfile?> getProfile(String uid) async {
    try {
      final doc = await _donorsRef.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return DonorProfile.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Saves or updates the donor profile with merge options.
  Future<void> saveProfile(DonorProfile profile) async {
    await _donorsRef.doc(profile.uid).set(
          profile.toMap(),
          SetOptions(merge: true),
        );
  }
}
