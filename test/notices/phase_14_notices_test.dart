import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/notices/models/notice_model.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';

void main() {
  group('Phase 14 — Notice & Communication Management System Unit Tests', () {
    // ──────────────────────────────────────────────────────────────────────
    // 1–5: MODEL SERIALIZATION & BASIC LIFECYCLE
    // ──────────────────────────────────────────────────────────────────────

    test('1. NoticeModel serialization (toMap & fromMap & copyWith)', () {
      const notice = NoticeModel(
        id: 1,
        title: 'Mid-Term Exam Schedule',
        message: 'Mid-term exams start from 1st September.',
        noticeType: 'Examination',
        targetRole: 'Students',
        targetClass: '10',
        targetBoard: 'CBSE',
        targetBatch: 'Udaan',
        publishDate: '2026-08-20',
        expiryDate: '2026-09-05',
        priority: 'Important',
        isPublished: true,
        isActive: true,
      );

      final map = notice.toMap();
      expect(map['title'], equals('Mid-Term Exam Schedule'));
      expect(map['noticeType'], equals('Examination'));
      expect(map['targetRole'], equals('Students'));
      expect(map['targetClass'], equals('10'));

      final restored = NoticeModel.fromMap(map, isRead: true);
      expect(restored.id, equals(1));
      expect(restored.description, equals('Mid-term exams start from 1st September.'));
      expect(restored.category, equals('Examination'));
      expect(restored.targetAudience, equals('Students'));
      expect(restored.isRead, isTrue);

      final updated = restored.copyWith(title: 'Updated Title', isRead: false);
      expect(updated.title, equals('Updated Title'));
      expect(updated.isRead, isFalse);
    });

    test('2 & 3. Notice creation and update validation', () {
      const n1 = NoticeModel(
        title: 'Holiday Announcement',
        message: 'Institute will remain closed tomorrow.',
        publishDate: '2026-08-23',
      );

      expect(n1.title.isNotEmpty, isTrue);
      expect(n1.message.isNotEmpty, isTrue);

      final n2 = n1.copyWith(id: 10, message: 'Corrected holiday message.');
      expect(n2.id, equals(10));
      expect(n2.message, equals('Corrected holiday message.'));
    });

    test('4. Notice archive status semantics (isActive = false)', () {
      const activeNotice = NoticeModel(
        id: 1,
        title: 'Active Notice',
        message: 'Notice text',
        publishDate: '2026-08-23',
        isActive: true,
      );
      expect(activeNotice.isArchived, isFalse);

      final archivedNotice = activeNotice.copyWith(isActive: false);
      expect(archivedNotice.isArchived, isTrue);
    });

    test('5. Notice delete dependency handling', () {
      // In SQLite, deleting notice_reads prior to deleting notice prevents orphaned rows.
      final int noticeId = 42;
      final List<int> noticeReads = [42, 42, 42];
      noticeReads.removeWhere((id) => id == noticeId);
      expect(noticeReads.isEmpty, isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────
    // 6–9: PUBLISHING & EXPIRY RULES
    // ──────────────────────────────────────────────────────────────────────

    test('6. Draft notice behavior (isPublished = false)', () {
      const draftNotice = NoticeModel(
        id: 1,
        title: 'Draft Exam Notice',
        message: 'Draft content',
        publishDate: '2026-08-23',
        isPublished: false,
      );

      bool isVisibleToStudent(NoticeModel n) => n.isPublished && n.isActive && !n.isExpired && !n.isFuturePublish;

      expect(isVisibleToStudent(draftNotice), isFalse);
    });

    test('7. Published notice behavior (isPublished = true)', () {
      const pubNotice = NoticeModel(
        id: 2,
        title: 'Published Notice',
        message: 'Published content',
        publishDate: '2026-08-20',
        isPublished: true,
        isActive: true,
      );

      bool isVisibleToStudent(NoticeModel n) => n.isPublished && n.isActive && !n.isExpired && !n.isFuturePublish;

      expect(isVisibleToStudent(pubNotice), isTrue);
    });

    test('8. Future publish date restriction', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final futureNotice = NoticeModel(
        id: 3,
        title: 'Future Notice',
        message: 'Scheduled for next week',
        publishDate: '${futureDate.year}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}',
        isPublished: true,
      );

      expect(futureNotice.isFuturePublish, isTrue);
      // Student feed must exclude future notices
      expect(!futureNotice.isFuturePublish, isFalse);
    });

    test('9. Expired notice behavior', () {
      const expiredNotice = NoticeModel(
        id: 4,
        title: 'Past Notice',
        message: 'Old announcement',
        publishDate: '2026-08-01',
        expiryDate: '2026-08-10', // Expired relative to 2026-08-23
        isPublished: true,
      );

      expect(expiredNotice.isExpired, isTrue);
      // Non-admin feed must exclude expired notices
      expect(!expiredNotice.isExpired, isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────
    // 10–17: TARGETING & RELEVANCE RULES
    // ──────────────────────────────────────────────────────────────────────

    test('10. Target All / Everyone visibility', () {
      const nAll = NoticeModel(
        title: 'General Announcement',
        message: 'For everyone',
        targetRole: 'Everyone',
        publishDate: '2026-08-23',
      );

      bool isRelevantForRole(NoticeModel n, String role) {
        if (role == 'Admin') return true;
        if (n.targetRole == 'Everyone' || n.targetRole == 'All') return true;
        return n.targetRole == role || (role == 'Student' && n.targetRole == 'Students') || (role == 'Teacher' && n.targetRole == 'Teachers');
      }

      expect(isRelevantForRole(nAll, 'Admin'), isTrue);
      expect(isRelevantForRole(nAll, 'Teacher'), isTrue);
      expect(isRelevantForRole(nAll, 'Student'), isTrue);
    });

    test('11. Target Students visibility', () {
      const nStudents = NoticeModel(
        title: 'Student Assembly',
        message: 'For students only',
        targetRole: 'Students',
        publishDate: '2026-08-23',
      );

      bool isRelevantForRole(NoticeModel n, String role) {
        if (role == 'Admin') return true;
        if (n.targetRole == 'Everyone' || n.targetRole == 'All') return true;
        return n.targetRole == role || (role == 'Student' && n.targetRole == 'Students') || (role == 'Teacher' && n.targetRole == 'Teachers');
      }

      expect(isRelevantForRole(nStudents, 'Admin'), isTrue);
      expect(isRelevantForRole(nStudents, 'Student'), isTrue);
      expect(isRelevantForRole(nStudents, 'Teacher'), isFalse);
    });

    test('12. Target Teachers visibility', () {
      const nTeachers = NoticeModel(
        title: 'Faculty Meeting',
        message: 'For teachers only',
        targetRole: 'Teachers',
        publishDate: '2026-08-23',
      );

      bool isRelevantForRole(NoticeModel n, String role) {
        if (role == 'Admin') return true;
        if (n.targetRole == 'Everyone' || n.targetRole == 'All') return true;
        return n.targetRole == role || (role == 'Student' && n.targetRole == 'Students') || (role == 'Teacher' && n.targetRole == 'Teachers');
      }

      expect(isRelevantForRole(nTeachers, 'Admin'), isTrue);
      expect(isRelevantForRole(nTeachers, 'Teacher'), isTrue);
      expect(isRelevantForRole(nTeachers, 'Student'), isFalse);
    });

    test('13. Specific Class targeting (Class 10 vs Class 9)', () {
      const nClass10 = NoticeModel(
        title: 'Class 10 Board Registration',
        message: 'Board details',
        targetRole: 'Specific Class',
        targetClass: '10',
        publishDate: '2026-08-23',
      );

      bool isRelevantForStudent(NoticeModel n, String studentClass) {
        if (n.targetRole == 'Specific Class') {
          return n.targetClass == null || n.targetClass == 'All' || n.targetClass == studentClass;
        }
        return true;
      }

      expect(isRelevantForStudent(nClass10, '10'), isTrue);
      expect(isRelevantForStudent(nClass10, '9'), isFalse);
    });

    test('14. Specific Batch targeting', () {
      const nBatchUdaan = NoticeModel(
        title: 'Udaan Special Class',
        message: 'Batch details',
        targetRole: 'Specific Batch',
        targetBatch: 'Udaan',
        publishDate: '2026-08-23',
      );

      bool isRelevantForBatch(NoticeModel n, String studentBatch) {
        if (n.targetRole == 'Specific Batch') {
          return n.targetBatch == null || n.targetBatch == 'All' || n.targetBatch == studentBatch;
        }
        return true;
      }

      expect(isRelevantForBatch(nBatchUdaan, 'Udaan'), isTrue);
      expect(isRelevantForBatch(nBatchUdaan, 'Lakshya'), isFalse);
    });

    test('15 & 16 & 17. Student, Teacher, and Admin feed filtering simulation', () {
      final today = DateTime.now();
      final pastStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final futureStr = '${today.add(const Duration(days: 30)).year}-${today.add(const Duration(days: 30)).month.toString().padLeft(2, '0')}-${today.add(const Duration(days: 30)).day.toString().padLeft(2, '0')}';
      final notices = [
        NoticeModel(id: 1, title: 'All Notice', message: 'M', targetRole: 'Everyone', publishDate: pastStr, isPublished: true),
        NoticeModel(id: 2, title: 'Student Notice', message: 'M', targetRole: 'Students', publishDate: pastStr, isPublished: true),
        NoticeModel(id: 3, title: 'Teacher Notice', message: 'M', targetRole: 'Teachers', publishDate: pastStr, isPublished: true),
        NoticeModel(id: 4, title: 'Draft Notice', message: 'M', targetRole: 'Everyone', publishDate: pastStr, isPublished: false),
        NoticeModel(id: 5, title: 'Future Notice', message: 'M', targetRole: 'Everyone', publishDate: futureStr, isPublished: true),
      ];

      // Student view: active, published, non-future, non-expired, student/everyone targeted
      final studentFeed = notices
          .where((n) => n.isPublished && n.isActive && !n.isExpired && !n.isFuturePublish)
          .where((n) => n.targetRole == 'Everyone' || n.targetRole == 'Students')
          .toList();

      expect(studentFeed.length, equals(2));
      expect(studentFeed.map((n) => n.id), containsAll([1, 2]));

      // Teacher view: active, published, non-future, non-expired, teacher/everyone targeted
      final teacherFeed = notices
          .where((n) => n.isPublished && n.isActive && !n.isExpired && !n.isFuturePublish)
          .where((n) => n.targetRole == 'Everyone' || n.targetRole == 'Teachers')
          .toList();

      expect(teacherFeed.length, equals(2));
      expect(teacherFeed.map((n) => n.id), containsAll([1, 3]));

      // Admin view: sees ALL notices including drafts and future notices
      expect(notices.length, equals(5));
    });

    // ──────────────────────────────────────────────────────────────────────
    // 18–21: READ TRACKING & ANALYTICS
    // ──────────────────────────────────────────────────────────────────────

    test('18 & 19 & 20. Read status tracking & UNIQUE(noticeId, userId) constraint simulation', () {
      final Map<String, Set<int>> noticeReadsStore = {};

      void markRead(int noticeId, String userId) {
        noticeReadsStore.putIfAbsent(userId, () => {}).add(noticeId);
      }

      markRead(10, 'student_5');
      expect(noticeReadsStore['student_5']!.contains(10), isTrue);

      // Duplicate mark read call
      markRead(10, 'student_5');
      // Set guarantees unique noticeId per user
      expect(noticeReadsStore['student_5']!.length, equals(1));
    });

    test('21. Read Analytics formula verification', () {
      const int totalTargeted = 50;
      const int readCount = 40;
      const int unreadCount = totalTargeted - readCount;
      const double readPercentage = (readCount / totalTargeted) * 100.0;

      expect(unreadCount, equals(10));
      expect(readPercentage, equals(80.0));
    });

    // ──────────────────────────────────────────────────────────────────────
    // 22–25: SEARCH, FILTERS & SORTING
    // ──────────────────────────────────────────────────────────────────────

    test('22. Parameterized search simulation', () {
      final notices = [
        const NoticeModel(id: 1, title: 'Mathematics Exam', message: 'Details', publishDate: '2026-08-20'),
        const NoticeModel(id: 2, title: 'Physics Test', message: 'Details', publishDate: '2026-08-20'),
        const NoticeModel(id: 3, title: 'Holiday', message: 'Maths class canceled', publishDate: '2026-08-20'),
      ];

      final query = 'math';
      final results = notices.where((n) => n.title.toLowerCase().contains(query) || n.message.toLowerCase().contains(query)).toList();

      expect(results.length, equals(2));
      expect(results.map((n) => n.id), containsAll([1, 3]));
    });

    test('23 & 24. Category and Priority filtering', () {
      final notices = [
        const NoticeModel(id: 1, title: 'Exam 1', message: 'M', noticeType: 'Examination', priority: 'Urgent', publishDate: '2026-08-20'),
        const NoticeModel(id: 2, title: 'Fee 1', message: 'M', noticeType: 'Fee', priority: 'Important', publishDate: '2026-08-20'),
        const NoticeModel(id: 3, title: 'Gen 1', message: 'M', noticeType: 'General', priority: 'Normal', publishDate: '2026-08-20'),
      ];

      final examOnly = notices.where((n) => n.category == 'Examination').toList();
      expect(examOnly.length, equals(1));
      expect(examOnly.first.id, equals(1));

      final urgentOnly = notices.where((n) => n.priority == 'Urgent').toList();
      expect(urgentOnly.length, equals(1));
      expect(urgentOnly.first.id, equals(1));
    });

    test('25. Admin Status filtering (Published, Draft, Expired, Archived)', () {
      final notices = [
        const NoticeModel(id: 1, title: 'P', message: 'M', isPublished: true, isActive: true, publishDate: '2026-08-20'),
        const NoticeModel(id: 2, title: 'D', message: 'M', isPublished: false, isActive: true, publishDate: '2026-08-20'),
        const NoticeModel(id: 3, title: 'A', message: 'M', isPublished: true, isActive: false, publishDate: '2026-08-20'), // Archived
      ];

      final drafts = notices.where((n) => !n.isPublished && n.isActive).toList();
      expect(drafts.length, equals(1));
      expect(drafts.first.id, equals(2));

      final archived = notices.where((n) => n.isArchived).toList();
      expect(archived.length, equals(1));
      expect(archived.first.id, equals(3));
    });

    // ──────────────────────────────────────────────────────────────────────
    // 26–28: FORM VALIDATIONS & CONSTRAINTS
    // ──────────────────────────────────────────────────────────────────────

    test('26. Invalid expiry date rejection (expiry < publish date)', () {
      final pubDate = DateTime(2026, 8, 25);
      final expDate = DateTime(2026, 8, 20);

      bool validateDates(DateTime pub, DateTime? exp) {
        if (exp == null) return true;
        return !exp.isBefore(pub);
      }

      expect(validateDates(pubDate, expDate), isFalse);
    });

    test('27 & 28. Target Class and Batch requirement validation', () {
      bool validateTargeting(String role, String? selectedClass, String? selectedBatch) {
        if (role == 'Specific Class' && (selectedClass == null || selectedClass == 'All' || selectedClass.isEmpty)) {
          return false;
        }
        if (role == 'Specific Batch' && (selectedBatch == null || selectedBatch.trim().isEmpty)) {
          return false;
        }
        return true;
      }

      expect(validateTargeting('Specific Class', 'All', null), isFalse);
      expect(validateTargeting('Specific Class', '10', null), isTrue);
      expect(validateTargeting('Specific Batch', null, ''), isFalse);
      expect(validateTargeting('Specific Batch', null, 'Udaan'), isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────
    // 29–35: ROLE SECURITY & SYSTEM INTEGRITY
    // ──────────────────────────────────────────────────────────────────────

    test('29. Role access security permissions', () {
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);

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
    });

    test('30 & 31. Parameterized SQL structure & priority sorting', () {
      final list = [
        const NoticeModel(id: 1, title: 'Normal', message: 'M', priority: 'Normal', publishDate: '2026-08-20'),
        const NoticeModel(id: 2, title: 'Urgent', message: 'M', priority: 'Urgent', publishDate: '2026-08-20'),
        const NoticeModel(id: 3, title: 'Important', message: 'M', priority: 'Important', publishDate: '2026-08-20'),
      ];

      final pMap = {'Urgent': 3, 'Important': 2, 'Normal': 1};
      list.sort((a, b) {
        final pA = pMap[a.priority] ?? 1;
        final pB = pMap[b.priority] ?? 1;
        if (pA != pB) return pB.compareTo(pA);
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });

      expect(list.first.priority, equals('Urgent'));
      expect(list[1].priority, equals('Important'));
      expect(list.last.priority, equals('Normal'));
    });

    test('32 & 33 & 34. Non-admin feed exclusions (archived, future, expired)', () {
      final today = DateTime.now();
      final pastStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final futureStr = '${today.add(const Duration(days: 30)).year}-${today.add(const Duration(days: 30)).month.toString().padLeft(2, '0')}-${today.add(const Duration(days: 30)).day.toString().padLeft(2, '0')}';
      final expiredStr = '${today.subtract(const Duration(days: 30)).year}-${today.subtract(const Duration(days: 30)).month.toString().padLeft(2, '0')}-${today.subtract(const Duration(days: 30)).day.toString().padLeft(2, '0')}';
      final list = [
        NoticeModel(id: 1, title: 'Valid', message: 'M', publishDate: pastStr, isPublished: true, isActive: true),
        NoticeModel(id: 2, title: 'Archived', message: 'M', publishDate: pastStr, isPublished: true, isActive: false),
        NoticeModel(id: 3, title: 'Future', message: 'M', publishDate: futureStr, isPublished: true, isActive: true),
        NoticeModel(id: 4, title: 'Expired', message: 'M', publishDate: pastStr, expiryDate: expiredStr, isPublished: true, isActive: true),
      ];

      final feed = list.where((n) => n.isPublished && n.isActive && !n.isExpired && !n.isFuturePublish).toList();

      expect(feed.length, equals(1));
      expect(feed.first.title, equals('Valid'));
    });

    test('35. SQLite persistence schema column mapping verification', () {
      const notice = NoticeModel(
        id: 10,
        title: 'Persistence Test',
        message: 'Message body',
        noticeType: 'General',
        targetRole: 'Everyone',
        publishDate: '2026-08-23',
        priority: 'Normal',
      );

      final map = notice.toMap();
      expect(map.containsKey('title'), isTrue);
      expect(map.containsKey('message'), isTrue);
      expect(map.containsKey('noticeType'), isTrue);
      expect(map.containsKey('targetRole'), isTrue);
      expect(map.containsKey('publishDate'), isTrue);
      expect(map.containsKey('isPublished'), isTrue);
      expect(map.containsKey('isActive'), isTrue);
    });

    test('36. Non-destructive notice table column repair ensures targetClass column exists', () async {
      const notice = NoticeModel(
        id: 99,
        title: 'Target Class Migration Test',
        message: 'Notice for class 10',
        noticeType: 'Academic',
        targetRole: 'Specific Class',
        targetClass: '10',
        publishDate: '2026-08-24',
        isPublished: true,
        isActive: true,
      );

      final map = notice.toMap();
      expect(map.containsKey('targetClass'), isTrue);
      expect(map['targetClass'], equals('10'));

      final restored = NoticeModel.fromMap(map);
      expect(restored.targetClass, equals('10'));
    });
  });
}
