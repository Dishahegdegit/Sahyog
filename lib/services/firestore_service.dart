import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ngo/donation_model.dart';
import '../models/ngo/ngo_model.dart';
import '../models/ngo/volunteer_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── DONATION STREAMS & ACTIONS ──────────────────────────────────────────

  /// Stream all available food donations for NGOs to discover
  Stream<List<DonationModel>> streamAvailableDonations() {
    return _db
        .collection('donations')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => DonationModel.fromMap(doc.data(), doc.id))
          .where((item) => item.status == 'Available')
          .toList();

      // Sort by urgency/created
      list.sort((a, b) {
        if (a.urgency == 'High' && b.urgency != 'High') return -1;
        if (a.urgency != 'High' && b.urgency == 'High') return 1;
        return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
      });

      return list;
    });
  }

  /// Stream donations accepted by a specific NGO
  Stream<List<DonationModel>> streamAcceptedDonations(String ngoId) {
    return _db
        .collection('donations')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DonationModel.fromMap(doc.data(), doc.id))
          .where((item) =>
              (item.acceptedByNgoId == ngoId || item.acceptedByNgoId == null) &&
              (item.status == 'Accepted'))
          .toList();
    });
  }

  /// Accept a donation request
  Future<void> acceptDonation({
    required String donationId,
    required String ngoId,
    required String ngoName,
  }) async {
    final docRef = _db.collection('donations').doc(donationId);
    final doc = await docRef.get();

    final donorId = doc.data()?['donorId'] ?? '';

    await docRef.update({
      'status': 'Accepted',
      'acceptedByNgoId': ngoId,
      'acceptedByNgoName': ngoName,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Notify Donor in notifications collection
    if (donorId.toString().isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': donorId,
        'donationId': donationId,
        'title': 'Donation Request Accepted',
        'body': '$ngoName has accepted your food donation request.',
        'status': 'Accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── VOLUNTEER MANAGEMENT STREAMS & ACTIONS ──────────────────────────────

  /// Stream registered volunteers for an NGO
  Stream<List<VolunteerModel>> streamVolunteers(String ngoId) {
    return _db
        .collection('volunteers')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VolunteerModel.fromMap(doc.data(), doc.id))
          .where((v) => v.ngoId == ngoId || v.ngoId.isEmpty)
          .toList();
    });
  }

  /// Register a new volunteer
  Future<void> addVolunteer(VolunteerModel volunteer) async {
    final docRef = _db.collection('volunteers').doc();
    final data = volunteer.toMap();
    data['ngoId'] = volunteer.ngoId;
    await docRef.set(data);
  }

  /// Assign a volunteer to an accepted donation
  Future<void> assignVolunteerToDonation({
    required String donationId,
    required String volunteerId,
    required String volunteerName,
    required String volunteerPhone,
    required String donorId,
  }) async {
    // 1. Update Donation
    await _db.collection('donations').doc(donationId).update({
      'status': 'Volunteer Assigned',
      'assignedVolunteerId': volunteerId,
      'assignedVolunteerName': volunteerName,
      'assignedVolunteerPhone': volunteerPhone,
    });

    // 2. Update Volunteer Status
    await _db.collection('volunteers').doc(volunteerId).update({
      'status': 'On Delivery',
      'assignedDonationId': donationId,
    });

    // 3. Notify Donor
    if (donorId.isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': donorId,
        'donationId': donationId,
        'title': 'Volunteer Assigned',
        'body': '$volunteerName ($volunteerPhone) has been assigned to pick up your donation.',
        'status': 'Volunteer Assigned',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── NGO PROFILE STREAMS & ACTIONS ───────────────────────────────────────

  /// Stream NGO Profile details
  Stream<NgoModel?> streamNgoProfile(String ngoId) {
    return _db.collection('ngos').doc(ngoId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return NgoModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Save or update NGO Profile
  Future<void> saveNgoProfile(NgoModel ngo) async {
    await _db.collection('ngos').doc(ngo.id).set(ngo.toMap(), SetOptions(merge: true));
    // Sync name + contact to users doc so welcome banner stays in sync
    await _db.collection('users').doc(ngo.id).set({
      'name': ngo.name,
      'phone': ngo.phone,
      'email': ngo.email,
      'address': ngo.address,
    }, SetOptions(merge: true));
  }

  // ─── REMOVE DUMMY FOOD DATA & SEED REALISTIC DEFAULTS ─────────────────────

  /// Purges dummy food donation records from Firestore
  Future<void> purgeDummyFoodDonations() async {
    try {
      final dummyIds = ['donor_101', 'donor_102', 'donor_103'];
      for (final id in dummyIds) {
        final snap = await _db
            .collection('donations')
            .where('donorId', isEqualTo: id)
            .get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }

      final names = [
        'Royal Grand Banquet Hall',
        'City Bakers & Cafe',
        'Spice Route Bistro'
      ];
      for (final name in names) {
        final snap = await _db
            .collection('donations')
            .where('donorName', isEqualTo: name)
            .get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}
  }

  /// Seeds sample volunteers if Firestore database is empty (no dummy food donations seeded)
  Future<void> seedInitialDataIfEmpty(String ngoId) async {
    try {
      // Purge any residual dummy food donations
      await purgeDummyFoodDonations();
    } catch (_) {}
  }
}
