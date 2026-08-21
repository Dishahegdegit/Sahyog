class DonorVerification {
  DonorVerification._();

  /// Legacy accounts with no `verified` field can still donate.
  /// New donor registrations set `verified: false` until an admin approves them.
  static bool isAllowedToDonate(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (!data.containsKey('verified')) return true;
    return data['verified'] == true;
  }
}
