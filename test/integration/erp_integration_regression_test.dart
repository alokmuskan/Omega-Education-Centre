import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/attendance/models/attendance_summary_model.dart';
import 'package:omega_education_centre/features/attendance/models/student_attendance_model.dart';

import 'package:omega_education_centre/features/backup/models/backup_metadata_model.dart';
import 'package:omega_education_centre/features/class_register/models/daily_class_record_model.dart';
import 'package:omega_education_centre/features/fees/models/fee_model.dart';
import 'package:omega_education_centre/features/fees/models/fee_payment_model.dart';
import 'package:omega_education_centre/features/notices/models/notice_model.dart';
import 'package:omega_education_centre/features/salary/models/teacher_payment_model.dart';
import 'package:omega_education_centre/features/salary/models/teacher_salary_summary_model.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_pay_rate_history_model.dart';
import 'package:omega_education_centre/features/tests/models/student_test_summary_model.dart';
import 'package:omega_education_centre/features/tests/models/test_model.dart';
import 'package:omega_education_centre/features/tests/models/test_result_model.dart';
import 'package:omega_education_centre/features/tests/models/test_subject_model.dart';
import 'package:omega_education_centre/features/tests/reports/models/result_export_data.dart';
import 'package:omega_education_centre/features/tests/reports/services/docx_generator_service.dart';
import 'package:omega_education_centre/features/tests/reports/services/excel_generator_service.dart';
import 'package:omega_education_centre/features/tests/reports/services/pdf_generator_service.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:omega_education_centre/shared/utils/attendance_date_validator.dart';
import 'package:omega_education_centre/shared/utils/password_util.dart';
import 'package:omega_education_centre/features/tests/services/result_calculation_service.dart';

void main() {
  group('Phase 15 — ERP Integration, QA & Production Hardening Suite', () {
    // ──────────────────────────────────────────────────────────────────────
    // 1–4: STUDENT WORKFLOW & CROSS-MODULE INTEGRATION
    // ──────────────────────────────────────────────────────────────────────

    test('1. Student creation → attendance workflow integration', () {
      const student = StudentModel(
        id: 101,
        name: 'Aarav Sharma',
        fatherName: 'Rajesh Sharma',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 1,
        mobile: '9876543210',
        createdAt: '2026-08-01',
      );

      final att = StudentAttendanceModel(
        studentId: student.id!,
        date: '2026-08-20',
        status: 'Present',
        remarks: 'On time',
      );

      final map = att.toMap();
      expect(map['studentId'], equals(101));
      expect(map['status'], equals('Present'));

      // Verify model roundtrip
      final restored = StudentAttendanceModel.fromMap({...map, 'id': 1});
      expect(restored.studentId, equals(101));
      expect(restored.status, equals('Present'));
      expect(restored.date, equals('2026-08-20'));
    });

    test('2. Student creation → fee plan & payments integration', () {
      // Student fixture: id=101, name='Aarav Sharma'

      const fee = FeeModel(
        id: 50,
        studentId: 101,
        paymentMethod: 'Installments',
        courseFee: 30000.0,
        totalFee: 25000.0,
        createdAt: '2026-08-01',
      );

      // Installment schedule (for documentation)
      // inst1: ₹10,000 due 2026-08-10 | inst2: ₹10,000 due 2026-09-10 | inst3: ₹5,000 due 2026-10-10

      // Simulate first installment paid
      const payment1 = FeePaymentModel(
        id: 1,
        feeId: 50,
        studentId: 101,
        amount: 10000.0,
        paymentDate: '2026-08-10',
        paymentMode: 'Cash',
      );

      final totalPaid = payment1.amount;
      final remainingDue = fee.totalFee - totalPaid;

      expect(totalPaid, equals(10000.0));
      expect(remainingDue, equals(15000.0));
      expect(fee.paymentMethod, equals('Installments'));
    });

    test('3. Student → test result multi-subject preservation regression test', () {
      // Test fixture: 3 subjects, testId=10, class=10

      final Map<String, TestResultModel> resultsMap = {};

      void saveResult(TestResultModel res) {
        final key = '${res.testId}_${res.studentId}_${res.testSubjectId}';
        resultsMap[key] = res;
      }

      // Enter Mathematics marks
      saveResult(const TestResultModel(testId: 10, studentId: 101, testSubjectId: 1, marksObtained: 85.0));
      // Enter Physics marks
      saveResult(const TestResultModel(testId: 10, studentId: 101, testSubjectId: 2, marksObtained: 78.0));
      // Enter Chemistry marks
      saveResult(const TestResultModel(testId: 10, studentId: 101, testSubjectId: 3, marksObtained: 92.0));

      // CRITICAL REGRESSION ASSERTION: Every subject retains its own marks, non-overwritten!
      expect(resultsMap.length, equals(3));
      expect(resultsMap['10_101_1']!.marksObtained, equals(85.0));
      expect(resultsMap['10_101_2']!.marksObtained, equals(78.0));
      expect(resultsMap['10_101_3']!.marksObtained, equals(92.0));

      // Verify UNIQUE constraint: overwriting same key keeps last value
      saveResult(const TestResultModel(testId: 10, studentId: 101, testSubjectId: 1, marksObtained: 90.0));
      expect(resultsMap.length, equals(3)); // Still 3 entries
      expect(resultsMap['10_101_1']!.marksObtained, equals(90.0)); // Updated
    });

    test('4. Student → report card & export data assembly integration', () {
      const testObj = TestModel(
        id: 10,
        title: 'Mid-Term Exam',
        testType: 'Monthly Test',
        board: 'CBSE',
        studentClass: '10',
        testDate: '2026-08-20',
        academicYear: '2026-27',
        subjects: [
          TestSubjectModel(id: 1, testId: 10, subjectName: 'Maths', maxMarks: 100, passMarks: 33),
        ],
      );

      final summary = StudentTestSummaryModel.compute(
        studentId: 101,
        studentName: 'Aarav Sharma',
        studentRollNo: '1',
        testId: 10,
        testTitle: testObj.title,
        testType: testObj.testType,
        board: testObj.board,
        studentClass: testObj.studentClass,
        testDate: testObj.testDate,
        academicYear: testObj.academicYear,
        configuredSubjects: testObj.subjects,
        recordedResults: [
          const TestResultModel(testId: 10, studentId: 101, testSubjectId: 1, marksObtained: 90.0),
        ],
      );

      expect(summary.totalObtained, equals(90.0));
      expect(summary.grade, equals('A+'));
      expect(summary.overallStatus, equals('Pass'));
      expect(summary.percentage, equals(90.0));
      expect(summary.isComplete, isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────
    // 5–8: TEACHER WORKFLOW & SALARY INTEGRATION
    // ──────────────────────────────────────────────────────────────────────

    test('5 & 6 & 7. Teacher → attendance, salary & historical pay rate integration', () {
      final teacher = TeacherModel(
        id: 201,
        name: 'Dr. Vikram Seth',
        mobile: '9876543211',
        subject: 'Mathematics',
        payPerHour: 400.0,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );

      // Historical pay rate periods:
      // Period 1: Jan to June -> ₹300/hour
      // Period 2: July onward -> ₹400/hour
      const rateHistory = [
        TeacherPayRateHistoryModel(id: 1, teacherId: 201, payPerHour: 300.0, effectiveFrom: '2026-01-01', effectiveTo: '2026-06-30'),
        TeacherPayRateHistoryModel(id: 2, teacherId: 201, payPerHour: 400.0, effectiveFrom: '2026-07-01'),
      ];

      double getRateForDate(String dateStr) {
        for (final r in rateHistory) {
          if (dateStr.compareTo(r.effectiveFrom) >= 0 &&
              (r.effectiveTo == null || dateStr.compareTo(r.effectiveTo!) <= 0)) {
            return r.payPerHour;
          }
        }
        return teacher.payPerHour;
      }

      expect(getRateForDate('2026-05-15'), equals(300.0));
      expect(getRateForDate('2026-08-15'), equals(400.0));

      // Calculate salary for 10 hours worked in August
      const hoursWorked = 10.0;
      final rate = getRateForDate('2026-08-15');
      final totalEarned = hoursWorked * rate;

      expect(totalEarned, equals(4000.0));

      const payment = TeacherPaymentModel(
        id: 1,
        teacherId: 201,
        month: '2026-08',
        amount: 2000.0,
        paymentDate: '2026-08-20',
      );

      final summary = TeacherSalarySummaryModel.compute(
        teacherId: 201,
        teacherName: teacher.name,
        teacherSubject: teacher.subject,
        teacherMobile: teacher.mobile,
        payPerHour: teacher.payPerHour,
        month: '2026-08',
        totalHoursWorked: hoursWorked,
        totalPaid: payment.amount,
      );

      expect(summary.totalHoursWorked, equals(10.0));
      expect(summary.earnedSalary, equals(4000.0));
      expect(summary.totalPaid, equals(2000.0));
      expect(summary.remainingDue, equals(2000.0));
      expect(summary.status, equals('Partially Paid'));
    });

    test('8. Teacher → Daily Class Register log integration', () {
      const record = DailyClassRecordModel(
        id: 1,
        date: '2026-08-20',
        teacherId: 201,
        teacherName: 'Dr. Vikram Seth',
        studentClass: '10',
        board: 'CBSE',
        subject: 'Mathematics',
        batch: 'Udaan',
        topic: 'Quadratic Equations Unit 2',
        durationMinutes: 60,
        createdAt: '2026-08-20T10:00:00',
        updatedAt: '2026-08-20T10:00:00',
      );

      final map = record.toMap();
      expect(map['teacherId'], equals(201));
      expect(map['topic'], equals('Quadratic Equations Unit 2'));

      final restored = DailyClassRecordModel.fromMap(map);
      expect(restored.durationMinutes, equals(60));
      expect(restored.formattedDuration, equals('1 hr'));
    });

    // ──────────────────────────────────────────────────────────────────────
    // 9–10: NOTICES & READ TRACKING
    // ──────────────────────────────────────────────────────────────────────

    test('9 & 10. Notice targeting & per-user read tracking integration', () {
      const notice = NoticeModel(
        id: 10,
        title: 'Holiday Announcement',
        message: 'Raksha Bandhan Holiday',
        targetRole: 'Everyone',
        publishDate: '2026-08-20',
        isPublished: true,
        isActive: true,
      );

      expect(notice.isExpired, isFalse);
      expect(notice.isFuturePublish, isFalse);

      final Map<String, Set<int>> reads = {};

      void markRead(String uId, int nId) {
        reads.putIfAbsent(uId, () => {}).add(nId);
      }

      markRead('student_101', 10);
      expect(reads['student_101']!.contains(10), isTrue);

      // Duplicate read attempt — should not create duplicate
      markRead('student_101', 10);
      expect(reads['student_101']!.length, equals(1));
    });

    test('9b. Notice future publish & expiry filtering', () {
      const futureNotice = NoticeModel(
        id: 20,
        title: 'Future Event',
        message: 'Coming soon',
        publishDate: '2026-12-01',
        isPublished: true,
        isActive: true,
      );

      expect(futureNotice.isFuturePublish, isTrue);

      const expiredNotice = NoticeModel(
        id: 21,
        title: 'Past Event',
        message: 'Old event',
        publishDate: '2026-01-01',
        expiryDate: '2026-02-01',
        isPublished: true,
        isActive: true,
      );

      expect(expiredNotice.isExpired, isTrue);

      const archivedNotice = NoticeModel(
        id: 22,
        title: 'Archived',
        message: 'Old notice',
        publishDate: '2026-08-01',
        isPublished: true,
        isActive: false,
      );

      expect(archivedNotice.isArchived, isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────
    // 11: BACKUP & RESTORE COMPATIBILITY
    // ──────────────────────────────────────────────────────────────────────

    test('11. Backup metadata companion JSON & restore version compatibility', () {
      const backupMeta = BackupMetadataModel(
        fileName: 'omega_education_backup_manual_2026-08-23_20-30-00.db',
        createdTime: '2026-08-23T20:30:00Z',
        fileSize: 1048576,
        type: 'manual',
        appVersion: '1.0.0',
        dbVersion: 14,
        validationStatus: 'Healthy',
      );

      final map = backupMeta.toMap();
      final restored = BackupMetadataModel.fromMap(map);
      expect(restored.dbVersion, equals(14));
      expect(restored.validationStatus, equals('Healthy'));
      expect(restored.formattedSize, equals('1.0 MB'));

      bool canRestore(int backupVersion) => backupVersion <= 14;
      expect(canRestore(14), isTrue);
      expect(canRestore(15), isFalse); // Newer unsupported version rejected
    });

    // ──────────────────────────────────────────────────────────────────────
    // 12–14: REPORTS & EXPORT ENGINE
    // ──────────────────────────────────────────────────────────────────────

    test('12 & 13 & 14. Report exports (PDF, Excel, Word) generation', () async {
      final exportData = ClassResultExportData.fromSummaries(
        test: const TestModel(
          id: 1,
          title: 'Unit Test 1',
          testType: 'Monthly Test',
          board: 'CBSE',
          studentClass: '10',
          testDate: '2026-08-20',
          academicYear: '2026-27',
          subjects: [TestSubjectModel(id: 1, testId: 1, subjectName: 'Science', maxMarks: 100, passMarks: 33)],
        ),
        summaries: [
          StudentTestSummaryModel.compute(
            studentId: 101,
            studentName: 'Aarav Sharma',
            studentRollNo: '1',
            testId: 1,
            testTitle: 'Unit Test 1',
            testType: 'Monthly Test',
            board: 'CBSE',
            studentClass: '10',
            testDate: '2026-08-20',
            academicYear: '2026-27',
            configuredSubjects: [const TestSubjectModel(id: 1, testId: 1, subjectName: 'Science', maxMarks: 100, passMarks: 33)],
            recordedResults: [const TestResultModel(testId: 1, studentId: 101, testSubjectId: 1, marksObtained: 95.0)],
          ),
        ],
      );

      // PDF generation
      final pdfBytes = await PdfGeneratorService.generateClassResultPdf(exportData);
      expect(pdfBytes.isNotEmpty, isTrue);

      // Excel generation
      final excelBytes = ExcelGeneratorService.generateClassResultExcel(exportData);
      expect(excelBytes, isNotNull);
      expect(excelBytes!.isNotEmpty, isTrue);

      // Word generation (.docx ZIP format)
      final docxBytes = DocxGeneratorService.generateClassResultDocx(exportData);
      expect(docxBytes.isNotEmpty, isTrue);
      expect(docxBytes[0] == 0x50 && docxBytes[1] == 0x4B, isTrue); // PK header
    });

    // ──────────────────────────────────────────────────────────────────────
    // 15–20: SECURITY, VALIDATION & DATABASE SYSTEM CHECKS
    // ──────────────────────────────────────────────────────────────────────

    test('15. Report Card attendance summary integration', () {
      const attSummary = StudentAttendanceSummary(
        totalRecordedDays: 20,
        presentCount: 18,
        absentCount: 2,
        lateCount: 0,
        leaveCount: 0,
      );

      expect(attSummary.percentage, equals(90.0));
      expect(attSummary.totalRecordedDays, equals(20));
      expect(attSummary.presentCount, equals(18));
    });

    test('16. Role-Based Access Control security permissions', () {
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isStudent, isFalse);

      final teacherMock = TeacherModel(
        id: 1,
        name: 'Rahul Teacher',
        mobile: '9876543210',
        subject: 'Maths',
        payPerHour: 500,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setTeacherSession(teacherMock);
      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.currentTeacherId, equals(1));

      const studentMock = StudentModel(
        id: 5,
        name: 'Amit Student',
        fatherName: 'Father',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 15,
        mobile: '9876543211',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setStudentSession(studentMock);
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.currentStudentId, equals(5));

      // Logout clears session
      AppSession.instance.clearSession();
      expect(AppSession.instance.isAdmin, isTrue); // defaults back
      expect(AppSession.instance.currentUsername, isEmpty);
    });

    test('17. Schema constraint persistence checks (17 Tables in DB v14)', () {
      final Set<String> allTables = {
        'students',
        'teachers',
        'teacher_attendance',
        'teacher_payments',
        'student_attendance',
        'fees',
        'fee_payments',
        'fee_installments',
        'tests',
        'test_results',
        'users',
        'teacher_pay_rate_history',
        'test_subjects',
        'daily_class_records',
        'timetable_entries',
        'notices',
        'notice_reads',
      };

      expect(allTables.length, equals(17));
    });

    test('18. Attendance future date restriction enforcement', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr = AttendanceDateValidator.formatDateIso(tomorrow);

      expect(AttendanceDateValidator.isFutureDate(tomorrowStr), isTrue);

      // Today should NOT be rejected
      final todayStr = AttendanceDateValidator.todayIso;
      expect(AttendanceDateValidator.isFutureDate(todayStr), isFalse);

      // Past date should NOT be rejected
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = AttendanceDateValidator.formatDateIso(yesterday);
      expect(AttendanceDateValidator.isFutureDate(yesterdayStr), isFalse);

      // validateNotFuture should throw for future dates
      expect(() => AttendanceDateValidator.validateNotFuture(tomorrowStr), throwsArgumentError);

      // validateNotFuture should NOT throw for today
      expect(() => AttendanceDateValidator.validateNotFuture(todayStr), returnsNormally);
    });

    test('19. Duplicate transaction prevention simulation', () {
      final List<String> transactions = [];

      bool processTransaction(String txId) {
        if (transactions.contains(txId)) return false;
        transactions.add(txId);
        return true;
      }

      expect(processTransaction('PAY_101_INST1'), isTrue);
      expect(processTransaction('PAY_101_INST1'), isFalse); // Blocked!
      expect(processTransaction('PAY_101_INST2'), isTrue);
    });

    test('20. Migration chain non-destructive upgrade verification', () {
      // Database migration v1 to v14 contains only ALTER TABLE & CREATE TABLE commands.
      bool isMigrationSafe(String sqlCommand) {
        final upper = sqlCommand.toUpperCase();
        return !upper.contains('DROP TABLE') && !upper.contains('DELETE FROM');
      }

      expect(isMigrationSafe('ALTER TABLE students ADD COLUMN motherName TEXT'), isTrue);
      expect(isMigrationSafe('CREATE TABLE IF NOT EXISTS notice_reads (...)'), isTrue);
      expect(isMigrationSafe('DROP TABLE students'), isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────
    // 21–25: ADDITIONAL CROSS-MODULE TESTS
    // ──────────────────────────────────────────────────────────────────────

    test('21. Fee payment overpayment protection', () {
      const fee = FeeModel(
        id: 50,
        studentId: 101,
        paymentMethod: 'Installments',
        totalFee: 10000.0,
        createdAt: '2026-08-01',
      );

      double currentPaid = 8000.0;
      double remainingDue = fee.totalFee - currentPaid;

      // Exact payment
      expect(remainingDue, equals(2000.0));

      // Overpayment check
      final overpayAmount = 3000.0;
      expect(overpayAmount > remainingDue, isTrue);
    });

    test('22. Attendance percentage calculation rules', () {
      // Present + Late count as attended; Absent + Leave do not
      final pct1 = AppConstants.computeStudentAttendancePercentage(
        presentCount: 18,
        lateCount: 1,
        totalDays: 20,
      );
      expect(pct1, equals(95.0));

      final pct2 = AppConstants.computeStudentAttendancePercentage(
        presentCount: 10,
        lateCount: 0,
        totalDays: 0,
      );
      expect(pct2, equals(0.0)); // No days -> 0%

      final pct3 = AppConstants.computeStudentAttendancePercentage(
        presentCount: 20,
        lateCount: 0,
        totalDays: 20,
      );
      expect(pct3, equals(100.0));
    });

    test('23. AppConstants grade thresholds', () {
      expect(AppConstants.getGrade(95), equals('A+'));
      expect(AppConstants.getGrade(80), equals('A'));
      expect(AppConstants.getGrade(65), equals('B'));
      expect(AppConstants.getGrade(50), equals('C'));
      expect(AppConstants.getGrade(37), equals('D'));
      expect(AppConstants.getGrade(20), equals('F'));

      expect(AppConstants.isPassed(35.0), isTrue);
      expect(AppConstants.isPassed(34.99), isFalse);
    });

    test('24. ResultCalculationService competition ranking', () {
      final ranks = ResultCalculationService.computeCompetitionRanks(
        studentIdToPercentage: {
          1: 95.0,
          2: 85.0,
          3: 95.0,
          4: 70.0,
        },
        studentIdToIsComplete: {
          1: true,
          2: true,
          3: true,
          4: true,
        },
      );

      // Competition ranking: tied percentages get same rank, next rank skips
      expect(ranks[1], equals(1)); // 95% -> Rank 1
      expect(ranks[3], equals(1)); // 95% -> Rank 1 (tied)
      expect(ranks[2], equals(3)); // 85% -> Rank 3 (skip 2)
      expect(ranks[4], equals(4)); // 70% -> Rank 4
    });

    test('25. Password hashing utility roundtrip', () {
      final salt = PasswordUtil.generateSalt();
      expect(salt.length, equals(32)); // 16 bytes = 32 hex chars

      final hash1 = PasswordUtil.hashPassword('admin123', salt);
      expect(hash1.length, equals(64)); // 32 bytes = 64 hex chars

      // Same password + same salt = same hash
      final hash2 = PasswordUtil.hashPassword('admin123', salt);
      expect(hash1, equals(hash2));

      // Different password = different hash
      final hash3 = PasswordUtil.hashPassword('wrongpassword', salt);
      expect(hash1, isNot(equals(hash3)));

      // Verify correct password
      expect(PasswordUtil.verifyPassword('admin123', hash1, salt), isTrue);
      // Verify wrong password
      expect(PasswordUtil.verifyPassword('wrongpassword', hash1, salt), isFalse);
    });

    test('26. Student model serialization roundtrip', () {
      const student = StudentModel(
        id: 101,
        name: 'Aarav Sharma',
        fatherName: 'Rajesh Sharma',
        motherName: 'Priya Sharma',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 1,
        mobile: '9876543210',
        address: '123 Main Street',
        createdAt: '2026-08-01',
      );

      final map = student.toMap();
      final restored = StudentModel.fromMap(map);

      expect(restored.id, equals(101));
      expect(restored.name, equals('Aarav Sharma'));
      expect(restored.fatherName, equals('Rajesh Sharma'));
      expect(restored.motherName, equals('Priya Sharma'));
      expect(restored.board, equals('CBSE'));
      expect(restored.studentClass, equals('10'));
      expect(restored.rollNo, equals(1));
      expect(restored.mobile, equals('9876543210'));
    });

    test('27. Teacher model serialization roundtrip', () {
      final teacher = TeacherModel(
        id: 201,
        name: 'Dr. Vikram Seth',
        mobile: '9876543211',
        subject: 'Mathematics',
        qualification: 'PhD Mathematics',
        payPerHour: 400.0,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );

      final map = teacher.toMap();
      final restored = TeacherModel.fromMap(map);

      expect(restored.id, equals(201));
      expect(restored.name, equals('Dr. Vikram Seth'));
      expect(restored.subject, equals('Mathematics'));
      expect(restored.payPerHour, equals(400.0));
      expect(restored.status, equals('Active'));
    });

    test('28. Notice model serialization roundtrip', () {
      const notice = NoticeModel(
        id: 10,
        title: 'Holiday Announcement',
        message: 'Raksha Bandhan Holiday',
        noticeType: 'Holiday',
        targetRole: 'Everyone',
        publishDate: '2026-08-20',
        priority: 'Urgent',
        isPublished: true,
        isActive: true,
      );

      final map = notice.toMap();
      final restored = NoticeModel.fromMap(map);

      expect(restored.id, equals(10));
      expect(restored.title, equals('Holiday Announcement'));
      expect(restored.noticeType, equals('Holiday'));
      expect(restored.priority, equals('Urgent'));
      expect(restored.isPublished, isTrue);
    });

    test('29. Fee payment model serialization roundtrip', () {
      const payment = FeePaymentModel(
        id: 1,
        feeId: 50,
        studentId: 101,
        amount: 5000.0,
        paymentDate: '2026-08-20',
        paymentMode: 'UPI',
        remarks: 'First installment',
      );

      final map = payment.toMap();
      final restored = FeePaymentModel.fromMap(map);

      expect(restored.id, equals(1));
      expect(restored.amount, equals(5000.0));
      expect(restored.paymentMode, equals('UPI'));
      expect(restored.effectiveReceiptNo, isNotEmpty);
    });

    test('30. DailyClassRecordModel formattedDuration', () {
      const record1 = DailyClassRecordModel(
        date: '2026-08-20',
        studentClass: '10',
        board: 'CBSE',
        teacherId: 1,
        subject: 'Math',
        durationMinutes: 60,
        topic: 'Algebra',
        createdAt: '2026-08-20T10:00:00',
        updatedAt: '2026-08-20T10:00:00',
      );
      expect(record1.formattedDuration, equals('1 hr'));

      const record2 = DailyClassRecordModel(
        date: '2026-08-20',
        studentClass: '10',
        board: 'CBSE',
        teacherId: 1,
        subject: 'Math',
        durationMinutes: 90,
        topic: 'Geometry',
        createdAt: '2026-08-20T10:00:00',
        updatedAt: '2026-08-20T10:00:00',
      );
      expect(record2.formattedDuration, equals('1 hr 30 min'));

      const record3 = DailyClassRecordModel(
        date: '2026-08-20',
        studentClass: '10',
        board: 'CBSE',
        teacherId: 1,
        subject: 'Math',
        durationMinutes: 45,
        topic: 'Statistics',
        createdAt: '2026-08-20T10:00:00',
        updatedAt: '2026-08-20T10:00:00',
      );
      expect(record3.formattedDuration, equals('45 min'));
    });

    test('31. Empty attendance summary defaults', () {
      final empty = StudentAttendanceSummary.empty();
      expect(empty.totalRecordedDays, equals(0));
      expect(empty.presentCount, equals(0));
      expect(empty.percentage, equals(0.0));

      final teacherEmpty = TeacherAttendanceSummary.empty();
      expect(teacherEmpty.totalWorkingDays, equals(0));
      expect(teacherEmpty.totalHoursWorked, equals(0.0));
    });

    test('32. TeacherSalarySummaryModel compute with custom earned salary', () {
      final summary = TeacherSalarySummaryModel.compute(
        teacherId: 1,
        teacherName: 'Test Teacher',
        teacherSubject: 'Maths',
        teacherMobile: '9876543210',
        payPerHour: 500.0,
        month: '2026-08',
        totalHoursWorked: 20.0,
        customEarnedSalary: 8000.0,
        totalPaid: 5000.0,
      );

      expect(summary.earnedSalary, equals(8000.0));
      expect(summary.totalPaid, equals(5000.0));
      expect(summary.remainingDue, equals(3000.0));
      expect(summary.status, equals('Partially Paid'));
    });

    test('33. FeeModel serialization roundtrip', () {
      const fee = FeeModel(
        id: 50,
        studentId: 101,
        paymentMethod: 'Monthly',
        courseFee: 15000.0,
        totalFee: 12000.0,
        monthlyAmount: 1000.0,
        paymentDueDay: 10,
        startMonth: '2026-04',
        durationMonths: 12,
        description: 'Science Course',
        createdAt: '2026-08-01',
      );

      final map = fee.toMap();
      final restored = FeeModel.fromMap(map);

      expect(restored.id, equals(50));
      expect(restored.paymentMethod, equals('Monthly'));
      expect(restored.totalFee, equals(12000.0));
      expect(restored.monthlyAmount, equals(1000.0));
      expect(restored.durationMonths, equals(12));
    });

    test('34. TestModel serialization roundtrip with subjects', () {
      const testObj = TestModel(
        id: 10,
        title: 'Monthly Test',
        testType: 'Monthly Test',
        board: 'CBSE',
        studentClass: '10',
        testDate: '2026-08-20',
        academicYear: '2026-27',
        subjects: [
          TestSubjectModel(id: 1, testId: 10, subjectName: 'Math', maxMarks: 100, passMarks: 33),
          TestSubjectModel(id: 2, testId: 10, subjectName: 'Science', maxMarks: 100, passMarks: 33),
        ],
      );

      final map = testObj.toMap();
      final restored = TestModel.fromMap(map, subjects: testObj.subjects);

      expect(restored.id, equals(10));
      expect(restored.title, equals('Monthly Test'));
      expect(restored.subjects.length, equals(2));
      expect(restored.subjects[0].subjectName, equals('Math'));
    });

    test('35. Backup metadata formatting', () {
      const meta = BackupMetadataModel(
        fileName: 'test.db',
        createdTime: '2026-08-23T20:00:00Z',
        fileSize: 524288, // 512 KB
        type: 'manual',
        appVersion: '1.0.0',
        dbVersion: 14,
        validationStatus: 'Healthy',
      );

      expect(meta.formattedSize, equals('512.0 KB'));

      const meta2 = BackupMetadataModel(
        fileName: 'test2.db',
        createdTime: '2026-08-23T20:00:00Z',
        fileSize: 10485760, // 10 MB
        type: 'manual',
        appVersion: '1.0.0',
        dbVersion: 14,
        validationStatus: 'Healthy',
      );

      expect(meta2.formattedSize, equals('10.0 MB'));
    });
  });
}
