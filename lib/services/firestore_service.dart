import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ngo/donation_model.dart';
import '../models/ngo/ngo_model.dart';
import '../models/ngo/volunteer_model.dart';
import 'app_notifications.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── DONATION STREAMS & ACTIONS ──────────────────────────────────────────

  /// Stream all available food donations for NGOs to discover
  Stream<List<DonationModel>> streamAvailableDonations({String? ngoId, int limit = 20}) {
    return _db
        .collection('donations')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => DonationModel.fromMap(doc.data(), doc.id))
          .where((item) {
            final status = item.status.toLowerCase();
            final isAvailableStatus = status == 'available' ||
                status == 'pending' ||
                status == 'submitted' ||
                status == 'request submitted' ||
                status == 'created';
            final isUnaccepted = item.acceptedByNgoId == null || item.acceptedByNgoId!.isEmpty;

            // If a specific target NGO is set for this donation, ensure only that NGO can see it.
            // General unassigned donations (requestedNgoId is null/empty) remain visible to all NGOs.
            bool isForThisNgo = true;
            if (ngoId != null && ngoId.trim().isNotEmpty) {
              final target = item.requestedNgoId;
              if (target != null && target.trim().isNotEmpty) {
                isForThisNgo = target.trim() == ngoId.trim();
              }
            }

            return isAvailableStatus && isUnaccepted && isForThisNgo;
          })
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
              item.acceptedByNgoId == ngoId &&
              item.status == 'Accepted' &&
              (item.assignedVolunteerId == null ||
                  item.assignedVolunteerId!.isEmpty))
          .toList();
    });
  }

  /// Accept a donation request
  Future<void> acceptDonation({
    required String donationId,
    required String ngoId,
    required String ngoName,
  }) async {
    // Check NGO verification status
    final userDoc = await _db.collection('users').doc(ngoId).get();
    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final status = (userData['status'] ?? userData['approvalStatus'] ?? '').toString().toLowerCase().trim();
      final isVerified = userData['verified'] == true || userData['isApproved'] == true;
      if (status == 'pending' || (status != 'approved' && status != 'verified' && !isVerified)) {
        throw 'Your account is pending admin verification. Please wait till your account is verified by admin before accepting donations.';
      }
      if (status == 'rejected') {
        throw 'Your NGO account request was rejected by admin. Please contact support.';
      }
    }

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
      await AppNotifications.send(
        userId: donorId.toString(),
        donationId: donationId,
        title: 'Donation Request Accepted',
        body: '$ngoName has accepted your food donation request.',
        status: 'Accepted',
      );
    }
  }

  // ─── VOLUNTEER MANAGEMENT STREAMS & ACTIONS ──────────────────────────────

  /// Stream registered volunteers for an NGO
  Stream<List<VolunteerModel>> streamVolunteers(String ngoId, {int limit = 20}) {
    return _db
        .collection('volunteers')
        .where('ngoId', isEqualTo: ngoId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VolunteerModel.fromMap(doc.data(), doc.id))
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
      await AppNotifications.send(
        userId: donorId,
        donationId: donationId,
        title: 'Volunteer Assigned',
        body: '$volunteerName ($volunteerPhone) has been assigned to pick up your donation.',
        status: 'Volunteer Assigned',
      );
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
