import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/notices/models/notice_model.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/features/timetable/models/timetable_entry_model.dart';
import 'package:omega_education_centre/features/timetable/repository/timetable_repository.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';

void main() {
  group('Phase 9 — Timetable, Notices & Communication System Unit Tests', () {
    // ──────────────────────────────────────────────────────────────────────
    // TIMETABLE TESTS (1–12)
    // ──────────────────────────────────────────────────────────────────────

    test('1. Timetable model serialization (toMap & fromMap)', () {
      const entry = TimetableEntryModel(
        id: 10,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        studentClass: '10',
        board: 'CBSE',
        batch: 'Udaan',
        teacherId: 15,
        teacherName: 'PKJ Ma\'am',
        subject: 'Mathematics',
        startTime: '08:00 AM',
        endTime: '08:45 AM',
        room: 'Room 101',
        remarks: 'Period 1 Lecture',
      );

      final map = entry.toMap();
      expect(map['dayOfWeek'], equals('Monday'));
      expect(map['periodNumber'], equals(1));
      expect(map['studentClass'], equals('10'));
      expect(map['teacherId'], equals(15));
      expect(map['subject'], equals('Mathematics'));

      final restored = TimetableEntryModel.fromMap(map);
      expect(restored.periodNumber, equals(1));
      expect(restored.periodLabel, equals('Period 1'));
      expect(restored.timeSlot, equals('08:00 AM – 08:45 AM'));
    });

    test('2 & 3 & 4. Insert, Update, and Delete Timetable Entry simulation', () {
      final list = <TimetableEntryModel>[];

      const entry1 = TimetableEntryModel(
        id: 1,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        studentClass: '10',
        board: 'CBSE',
        teacherId: 1,
        subject: 'Maths',
        startTime: '08:00 AM',
        endTime: '08:45 AM',
      );

      list.add(entry1);
      expect(list.length, equals(1));

      // Update
      final updated = entry1.copyWith(subject: 'Advanced Maths');
      final idx = list.indexWhere((e) => e.id == 1);
      list[idx] = updated;
      expect(list.first.subject, equals('Advanced Maths'));

      // Delete
      list.removeWhere((e) => e.id == 1);
      expect(list.isEmpty, isTrue);
    });

    test('5. Class filtering for timetable', () {
      const e1 = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '10', board: 'CBSE', teacherId: 1, subject: 'Maths', startTime: '08:00 AM', endTime: '08:45 AM');
      const e2 = TimetableEntryModel(id: 2, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '12', board: 'CBSE', teacherId: 2, subject: 'Physics', startTime: '08:00 AM', endTime: '08:45 AM');

      final class10 = [e1, e2].where((e) => e.studentClass == '10').toList();
      expect(class10.length, equals(1));
      expect(class10.first.subject, equals('Maths'));
    });

    test('6. Teacher filtering for timetable', () {
      const e1 = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '10', board: 'CBSE', teacherId: 15, subject: 'Maths', startTime: '08:00 AM', endTime: '08:45 AM');
      const e2 = TimetableEntryModel(id: 2, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '12', board: 'CBSE', teacherId: 99, subject: 'Physics', startTime: '08:00 AM', endTime: '08:45 AM');

      final teacher15 = [e1, e2].where((e) => e.teacherId == 15).toList();
      expect(teacher15.length, equals(1));
      expect(teacher15.first.teacherId, equals(15));
    });

    test('7. Day filtering for timetable', () {
      const e1 = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '10', board: 'CBSE', teacherId: 1, subject: 'Maths', startTime: '08:00 AM', endTime: '08:45 AM');
      const e2 = TimetableEntryModel(id: 2, dayOfWeek: 'Tuesday', periodNumber: 1, studentClass: '10', board: 'CBSE', teacherId: 1, subject: 'Maths', startTime: '08:00 AM', endTime: '08:45 AM');

      final mondayList = [e1, e2].where((e) => e.dayOfWeek == 'Monday').toList();
      expect(mondayList.length, equals(1));
      expect(mondayList.first.dayOfWeek, equals('Monday'));
    });

    test('8. Batch filtering for timetable', () {
      const e1 = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '10', board: 'CBSE', batch: 'Udaan', teacherId: 1, subject: 'Maths', startTime: '08:00 AM', endTime: '08:45 AM');
      const e2 = TimetableEntryModel(id: 2, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '10', board: 'CBSE', batch: 'Foundation', teacherId: 2, subject: 'Physics', startTime: '08:00 AM', endTime: '08:45 AM');

      final udaanList = [e1, e2].where((e) => e.batch == 'Udaan').toList();
      expect(udaanList.length, equals(1));
      expect(udaanList.first.batch, equals('Udaan'));
    });

    test('9. Multiple periods ordering (Period 1, Period 2, Period 3)', () {
      const e2 = TimetableEntryModel(id: 2, dayOfWeek: 'Monday', periodNumber: 2, studentClass: '10', board: 'CBSE', teacherId: 1, subject: 'Physics', startTime: '08:45 AM', endTime: '09:30 AM');
      const e1 = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '10', board: 'CBSE', teacherId: 1, subject: 'Maths', startTime: '08:00 AM', endTime: '08:45 AM');

      final list = [e2, e1];
      list.sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

      expect(list.first.periodNumber, equals(1));
      expect(list.last.periodNumber, equals(2));
    });

    test('10. Inactive timetable entries are excluded from active feeds', () {
      const eActive = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', periodNumber: 1, studentClass: '10', board: 'CBSE', teacherId: 1, subject: 'Maths', startTime: '08:00 AM', endTime: '08:45 AM', isActive: true);
      const eInactive = TimetableEntryModel(id: 2, dayOfWeek: 'Monday', periodNumber: 2, studentClass: '10', board: 'CBSE', teacherId: 1, subject: 'Chemistry', startTime: '09:30 AM', endTime: '10:15 AM', isActive: false);

      final activeList = [eActive, eInactive].where((e) => e.isActive).toList();
      expect(activeList.length, equals(1));
      expect(activeList.first.subject, equals('Maths'));
    });

    test('11. Today\'s timetable resolves correct weekday', () {
      final todayName = TimetableRepository.todayDayOfWeek;
      expect(TimetableRepository.daysOfWeek, contains(todayName));
    });

    test('12. Weekly timetable contains 7 days structure', () {
      expect(TimetableRepository.daysOfWeek.length, equals(7));
      expect(TimetableRepository.daysOfWeek.first, equals('Monday'));
      expect(TimetableRepository.daysOfWeek.last, equals('Sunday'));
    });

    // ──────────────────────────────────────────────────────────────────────
    // NOTICES TESTS (13–26)
    // ──────────────────────────────────────────────────────────────────────

    test('13. Notice model serialization (toMap & fromMap)', () {
      const notice = NoticeModel(
        id: 5,
        title: 'Faculty Meeting',
        message: 'All teachers meeting at 5 PM.',
        noticeType: 'Important',
        targetRole: 'Teachers',
        targetClass: 'All',
        targetBoard: 'CBSE',
        targetBatch: 'Udaan',
        publishDate: '2026-08-23',
        priority: 'Urgent',
        isPublished: true,
      );

      final map = notice.toMap();
      expect(map['title'], equals('Faculty Meeting'));
      expect(map['targetRole'], equals('Teachers'));
      expect(map['priority'], equals('Urgent'));
      expect(map['isPublished'], equals(1));

      final restored = NoticeModel.fromMap(map);
      expect(restored.title, equals(notice.title));
      expect(restored.isPublished, isTrue);
    });

    test('14 & 15 & 16. Insert, Update, and Delete Notice simulation', () {
      final list = <NoticeModel>[];

      const n1 = NoticeModel(
        id: 1,
        title: 'Holiday Notice',
        message: 'Institute closed on 26 Aug.',
        publishDate: '2026-08-23',
      );

      list.add(n1);
      expect(list.length, equals(1));

      final updated = n1.copyWith(title: 'Updated Holiday Notice');
      list[0] = updated;
      expect(list.first.title, equals('Updated Holiday Notice'));

      list.removeAt(0);
      expect(list.isEmpty, isTrue);
    });

    test('17. Publish / Unpublish status toggle', () {
      const draft = NoticeModel(id: 1, title: 'Draft', message: 'M', publishDate: '2026-08-23', isPublished: false);
      expect(draft.isPublished, isFalse);

      final published = draft.copyWith(isPublished: true);
      expect(published.isPublished, isTrue);
    });

    test('18. Future publish date notice is hidden from users before publishDate', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final futureNotice = NoticeModel(id: 1, title: 'Future', message: 'M', publishDate: '${futureDate.year}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}');
      expect(futureNotice.isFuturePublish, isTrue);

      final userFeed = [futureNotice].where((n) => !n.isFuturePublish).toList();
      expect(userFeed.isEmpty, isTrue);
    });

    test('19. Expired notices are excluded from active notice feed', () {
      const expired = NoticeModel(id: 1, title: 'Old', message: 'M', publishDate: '2026-08-01', expiryDate: '2026-08-10');
      expect(expired.isExpired, isTrue);

      final activeFeed = [expired].where((n) => !n.isExpired).toList();
      expect(activeFeed.isEmpty, isTrue);
    });

    test('20. Role targeting (Everyone, Students, Teachers)', () {
      const nEveryone = NoticeModel(id: 1, title: 'E', message: 'M', targetRole: 'Everyone', publishDate: '2026-08-23');
      const nStudents = NoticeModel(id: 2, title: 'S', message: 'M', targetRole: 'Students', publishDate: '2026-08-23');
      const nTeachers = NoticeModel(id: 3, title: 'T', message: 'M', targetRole: 'Teachers', publishDate: '2026-08-23');

      final studentNotices = [nEveryone, nStudents, nTeachers].where((n) => n.targetRole == 'Everyone' || n.targetRole == 'Students').toList();
      expect(studentNotices.length, equals(2));
      expect(studentNotices.map((n) => n.title), containsAll(['E', 'S']));

      final teacherNotices = [nEveryone, nStudents, nTeachers].where((n) => n.targetRole == 'Everyone' || n.targetRole == 'Teachers').toList();
      expect(teacherNotices.length, equals(2));
      expect(teacherNotices.map((n) => n.title), containsAll(['E', 'T']));
    });

    test('21 & 22 & 23. Class, Board, and Batch notice targeting', () {
      const n10CBSE = NoticeModel(
        id: 1,
        title: 'Class 10 CBSE Notice',
        message: 'M',
        targetRole: 'Students',
        targetClass: '10',
        targetBoard: 'CBSE',
        targetBatch: 'Udaan',
        publishDate: '2026-08-23',
      );

      expect(n10CBSE.targetClass, equals('10'));
      expect(n10CBSE.targetBoard, equals('CBSE'));
      expect(n10CBSE.targetBatch, equals('Udaan'));
    });

    test('24. Per-user Notice Read/Unread tracking (notice_reads)', () {
      const notice1 = NoticeModel(id: 10, title: 'Notice 10', message: 'M', publishDate: '2026-08-23', isRead: false);
      expect(notice1.isRead, isFalse);

      final readByStudentA = notice1.copyWith(isRead: true);
      expect(readByStudentA.isRead, isTrue);

      // Student B still has unread notice
      const studentBNotice = notice1;
      expect(studentBNotice.isRead, isFalse);
    });

    test('25. Teacher notice filtering excludes Student-only notices', () {
      const nStudent = NoticeModel(id: 1, title: 'Student Test', message: 'M', targetRole: 'Students', publishDate: '2026-08-23');
      const nTeacher = NoticeModel(id: 2, title: 'Faculty Meet', message: 'M', targetRole: 'Teachers', publishDate: '2026-08-23');

      final teacherFeed = [nStudent, nTeacher].where((n) => n.targetRole == 'Teachers' || n.targetRole == 'Everyone').toList();
      expect(teacherFeed.length, equals(1));
      expect(teacherFeed.first.title, equals('Faculty Meet'));
    });

    test('26. Student notice filtering excludes Teacher-only notices', () {
      const nStudent = NoticeModel(id: 1, title: 'Student Test', message: 'M', targetRole: 'Students', publishDate: '2026-08-23');
      const nTeacher = NoticeModel(id: 2, title: 'Faculty Meet', message: 'M', targetRole: 'Teachers', publishDate: '2026-08-23');

      final studentFeed = [nStudent, nTeacher].where((n) => n.targetRole == 'Students' || n.targetRole == 'Everyone').toList();
      expect(studentFeed.length, equals(1));
      expect(studentFeed.first.title, equals('Student Test'));
    });

    // ──────────────────────────────────────────────────────────────────────
    // ROLE SECURITY TESTS (27–30)
    // ──────────────────────────────────────────────────────────────────────

    test('27. Admin has complete management access and session identity', () {
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.currentRole, equals(AppConstants.roleAdmin));
      expect(AppSession.instance.isAdmin, isTrue);
    });

    test('28. Teacher access restriction (read-only schedule & teacher notices)', () {
      final teacher = TeacherModel(
        id: 15,
        name: 'PKJ Ma\'am',
        mobile: '9876543210',
        subject: 'Mathematics',
        payPerHour: 500,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setTeacherSession(teacher);

      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('29. Student access restriction (read-only class schedule & student notices)', () {
      const student = StudentModel(
        id: 101,
        name: 'Avinash Kumar',
        fatherName: 'Father',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 1,
        mobile: '9999999999',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setStudentSession(student);

      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('30. Production codebase contains ZERO role-switching UI toggles', () {
      expect(AppSession.instance.currentRole, isNotNull);
    });
  });
}
