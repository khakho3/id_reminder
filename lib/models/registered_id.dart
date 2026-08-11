class RegisteredId {
  const RegisteredId({
    required this.id,
    required this.schoolName,
    required this.studentId,
    required this.studentName,
    required this.registeredAt,
    this.nfcTagId,
  });

  final String id;
  final String schoolName;
  final String studentId;
  final String studentName;
  final DateTime registeredAt;
  final String? nfcTagId;

  String get displayName => studentName.isNotEmpty ? studentName : studentId;

  bool get hasNfc => nfcTagId != null && nfcTagId!.isNotEmpty;

  RegisteredId copyWith({
    String? id,
    String? schoolName,
    String? studentId,
    String? studentName,
    DateTime? registeredAt,
    String? nfcTagId,
    bool clearNfcTagId = false,
  }) {
    return RegisteredId(
      id: id ?? this.id,
      schoolName: schoolName ?? this.schoolName,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      registeredAt: registeredAt ?? this.registeredAt,
      nfcTagId: clearNfcTagId ? null : nfcTagId ?? this.nfcTagId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'schoolName': schoolName,
    'studentId': studentId,
    'studentName': studentName,
    'registeredAt': registeredAt.toIso8601String(),
    'nfcTagId': nfcTagId,
  };

  factory RegisteredId.fromJson(Map<String, Object?> json) {
    final schoolName = json['schoolName'] as String? ?? '';
    final studentId = json['studentId'] as String? ?? '';
    final registeredAt =
        DateTime.tryParse(json['registeredAt'] as String? ?? '') ??
        DateTime.now();
    return RegisteredId(
      id:
          json['id'] as String? ??
          _legacyId(schoolName, studentId, registeredAt),
      schoolName: schoolName,
      studentId: studentId,
      studentName: json['studentName'] as String? ?? '',
      registeredAt: registeredAt,
      nfcTagId: json['nfcTagId'] as String?,
    );
  }

  static String newId() => 'card_${DateTime.now().microsecondsSinceEpoch}';

  static String _legacyId(
    String schoolName,
    String studentId,
    DateTime registeredAt,
  ) {
    final raw = '${schoolName.trim()}_${studentId.trim()}';
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isNotEmpty) return 'card_$normalized';
    return 'card_${registeredAt.microsecondsSinceEpoch}';
  }
}
