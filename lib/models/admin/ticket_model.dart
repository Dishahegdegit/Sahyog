import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String createdBy;
  final String creatorName;
  final String creatorRole;
  final String? donationId;
  final String subject;
  final String description;
  final String status; // open | in_progress | resolved
  final String? adminReply;
  final DateTime? createdAt;

  TicketModel({
    required this.id,
    required this.createdBy,
    this.creatorName = '',
    this.creatorRole = 'donor',
    this.donationId,
    required this.subject,
    required this.description,
    this.status = 'open',
    this.adminReply,
    this.createdAt,
  });

  factory TicketModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();
    if (raw is String) created = DateTime.tryParse(raw);
    return TicketModel(
      id: id,
      createdBy: map['createdBy'] as String? ?? '',
      creatorName: map['creatorName'] as String? ?? '',
      creatorRole: map['creatorRole'] as String? ?? 'donor',
      donationId: map['donationId'] as String?,
      subject: map['subject'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      adminReply: map['adminReply'] as String?,
      createdAt: created,
    );
  }
}
