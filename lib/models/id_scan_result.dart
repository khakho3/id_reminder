class IdScanResult {
  const IdScanResult({
    required this.rawText,
    this.schoolName = '',
    this.studentId = '',
    this.studentName = '',
  });

  final String rawText;
  final String schoolName;
  final String studentId;
  final String studentName;
}
