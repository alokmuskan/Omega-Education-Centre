/// Book Issue Model
///
/// Represents a book issue/return record in the library.
class BookIssueModel {
  final int? id;
  final int bookId;
  final int studentId;
  final String issueDate;
  final String dueDate;
  final String? returnDate;
  final double fineAmount;
  final double finePerDay;
  final String status; // 'Issued', 'Returned', 'Overdue'
  final String? remarks;
  final String createdAt;
  final String? updatedAt;

  // Joined fields (from book and student tables)
  final String? bookTitle;
  final String? bookAuthor;
  final String? studentName;
  final int? studentRollNo;
  final String? studentClass;

  BookIssueModel({
    this.id,
    required this.bookId,
    required this.studentId,
    required this.issueDate,
    required this.dueDate,
    this.returnDate,
    this.fineAmount = 0,
    this.finePerDay = 1,
    this.status = 'Issued',
    this.remarks,
    required this.createdAt,
    this.updatedAt,
    this.bookTitle,
    this.bookAuthor,
    this.studentName,
    this.studentRollNo,
    this.studentClass,
  });

  /// Whether the book is currently overdue
  bool get isOverdue {
    if (status == 'Returned') return false;
    final now = DateTime.now();
    final due = DateTime.tryParse(dueDate);
    return due != null && now.isAfter(due);
  }

  /// Number of days overdue
  int get daysOverdue {
    if (!isOverdue) return 0;
    final now = DateTime.now();
    final due = DateTime.tryParse(dueDate);
    if (due == null) return 0;
    return now.difference(due).inDays;
  }

  /// Calculate fine based on overdue days
  double get calculatedFine {
    if (!isOverdue) return 0;
    return daysOverdue * finePerDay;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'studentId': studentId,
      'issueDate': issueDate,
      'dueDate': dueDate,
      'returnDate': returnDate,
      'fineAmount': fineAmount,
      'finePerDay': finePerDay,
      'status': status,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory BookIssueModel.fromMap(Map<String, dynamic> map) {
    return BookIssueModel(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      studentId: map['studentId'] as int,
      issueDate: map['issueDate'] as String,
      dueDate: map['dueDate'] as String,
      returnDate: map['returnDate'] as String?,
      fineAmount: (map['fineAmount'] as num?)?.toDouble() ?? 0,
      finePerDay: (map['finePerDay'] as num?)?.toDouble() ?? 1,
      status: map['status'] as String? ?? 'Issued',
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String?,
      bookTitle: map['bookTitle'] as String?,
      bookAuthor: map['bookAuthor'] as String?,
      studentName: map['studentName'] as String?,
      studentRollNo: map['studentRollNo'] as int?,
      studentClass: map['studentClass'] as String?,
    );
  }

  BookIssueModel copyWith({
    int? id,
    int? bookId,
    int? studentId,
    String? issueDate,
    String? dueDate,
    String? returnDate,
    double? fineAmount,
    double? finePerDay,
    String? status,
    String? remarks,
    String? createdAt,
    String? updatedAt,
  }) {
    return BookIssueModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      studentId: studentId ?? this.studentId,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      fineAmount: fineAmount ?? this.fineAmount,
      finePerDay: finePerDay ?? this.finePerDay,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      studentName: studentName,
      studentRollNo: studentRollNo,
      studentClass: studentClass,
    );
  }

  @override
  String toString() => 'BookIssueModel(id: $id, book: $bookId, student: $studentId, status: $status)';
}
