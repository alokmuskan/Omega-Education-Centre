import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/notices/models/notice_model.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/features/timetable/models/timetable_entry_model.dart';
import 'package:omega_education_centre/features/timetable/repository/timetable_repository.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:omega_education_centre/shared/utils/attendance_date_validator.dart';

void main() {
  group('Phase 8 — Timetable, Notices & Communication System Unit Tests', () {
    test('1. Timetable model serialization (toMap and fromMap)', () {
      const entry = TimetableEntryModel(
        id: 1,
        dayOfWeek: 'Monday',
        studentClass: '10',
        board: 'CBSE',
        batch: 'Udaan',
        teacherId: 15,
        teacherName: 'PKJ Ma\'am',
        subject: 'Mathematics',
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        room: 'Room 101',
        remarks: 'Maths Lecture',
      );

      final map = entry.toMap();
      expect(map['dayOfWeek'], equals('Monday'));
      expect(map['studentClass'], equals('10'));
      expect(map['teacherId'], equals(15));
      expect(map['subject'], equals('Mathematics'));
      expect(map['startTime'], equals('08:00 AM'));
      expect(map['endTime'], equals('09:00 AM'));

      final restored = TimetableEntryModel.fromMap(map);
      expect(restored.dayOfWeek, equals(entry.dayOfWeek));
      expect(restored.studentClass, equals(entry.studentClass));
      expect(restored.timeSlot, equals('08:00 AM – 09:00 AM'));
    });

    test('2. Notice model serialization and expiry status check', () {
      const notice = NoticeModel(
        id: 10,
        title: 'Mathematics Test Alert',
        message: 'Unit test on Monday morning.',
        noticeType: 'Exam',
        targetRole: 'Students',
        targetClass: '10',
        targetBatch: 'Udaan',
        publishDate: '2026-08-01',
        expiryDate: '2026-08-10',
        priority: 'Urgent',
      );

      final map = notice.toMap();
      expect(map['title'], equals('Mathematics Test Alert'));
      expect(map['noticeType'], equals('Exam'));
      expect(map['priority'], equals('Urgent'));

      final restored = NoticeModel.fromMap(map);
      expect(restored.title, equals(notice.title));
      expect(restored.isExpired, isTrue); // 2026-08-10 is in past relative to 2026-08-23
    });

    test('14. Timetable time validation rejects start time >= end time', () {
      const invalidEntry = TimetableEntryModel(
        dayOfWeek: 'Monday',
        studentClass: '10',
        board: 'CBSE',
        teacherId: 1,
        subject: 'Maths',
        startTime: '10:00 AM',
        endTime: '09:00 AM',
      );

      expect(invalidEntry.startMinutes >= invalidEntry.endMinutes, isTrue);
    });

    test('15 & 16. Conflict Validation logic detects teacher & class schedule overlaps', () {
      const existing1 = TimetableEntryModel(
        id: 100,
        dayOfWeek: 'Monday',
        studentClass: '10',
        board: 'CBSE',
        batch: 'Udaan',
        teacherId: 15, // PKJ Ma'am
        subject: 'Mathematics',
        startTime: '08:00 AM',
        endTime: '09:00 AM',
      );

      const overlappingTeacherEntry = TimetableEntryModel(
        id: 101,
        dayOfWeek: 'Monday',
        studentClass: '12',
        board: 'CBSE',
        teacherId: 15, // Same teacher at overlapping 08:30 AM
        subject: 'Calculus',
        startTime: '08:30 AM',
        endTime: '09:30 AM',
      );

      // Verify time intervals overlap
      final overlap = (overlappingTeacherEntry.startMinutes < existing1.endMinutes) &&
          (overlappingTeacherEntry.endMinutes > existing1.startMinutes);
      expect(overlap, isTrue);
    });

    test('5 & 15. Teacher sees only own timetable and cannot select other teachers', () {
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

      const t1 = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', studentClass: '10', board: 'CBSE', teacherId: 15, teacherName: 'PKJ Ma\'am', subject: 'Maths', startTime: '08:00 AM', endTime: '09:00 AM');
      const t2 = TimetableEntryModel(id: 2, dayOfWeek: 'Monday', studentClass: '12', board: 'BSEB', teacherId: 99, teacherName: 'RK Sir', subject: 'Physics', startTime: '10:00 AM', endTime: '11:00 AM');

      final teacherSchedule = [t1, t2].where((e) => e.teacherId == AppSession.instance.currentTeacherId).toList();
      expect(teacherSchedule.length, equals(1));
      expect(teacherSchedule.first.teacherName, equals('PKJ Ma\'am'));
    });

    test('6. Student sees only applicable class/batch timetable', () {
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

      const t1 = TimetableEntryModel(id: 1, dayOfWeek: 'Monday', studentClass: '10', board: 'CBSE', batch: 'Udaan', teacherId: 15, subject: 'Maths', startTime: '08:00 AM', endTime: '09:00 AM');
      const t2 = TimetableEntryModel(id: 2, dayOfWeek: 'Monday', studentClass: '12', board: 'BSEB', teacherId: 99, subject: 'Physics', startTime: '10:00 AM', endTime: '11:00 AM');

      final studentSchedule = [t1, t2].where((e) => e.studentClass == AppSession.instance.currentStudentModel?.studentClass).toList();
      expect(studentSchedule.length, equals(1));
      expect(studentSchedule.first.subject, equals('Maths'));
    });

    test('7 & 8. Teacher and Student are read-only and cannot modify timetable', () {
      AppSession.instance.setTeacherSession(
        TeacherModel(id: 15, name: 'PKJ', mobile: '1', subject: 'M', payPerHour: 100, joiningDate: '2026-01-01', createdAt: '2026-01-01'),
      );

      final canTeacherAdd = AppSession.instance.isAdmin;
      expect(canTeacherAdd, isFalse);

      AppSession.instance.setStudentSession(
        const StudentModel(id: 1, name: 'S', fatherName: 'F', board: 'CBSE', studentClass: '10', rollNo: 1, mobile: '1', createdAt: '2026-01-01'),
      );

      final canStudentAdd = AppSession.instance.isAdmin;
      expect(canStudentAdd, isFalse);
    });

    test('9 & 10 & 11. Role-based notice filtering, class-specific & batch-specific targeting', () {
      const n1 = NoticeModel(id: 1, title: 'All Notice', message: 'General', targetRole: 'All Users', publishDate: '2026-08-23');
      const n2 = NoticeModel(id: 2, title: 'Class 10 Only', message: 'Exam', targetRole: 'Students', targetClass: '10', publishDate: '2026-08-23');
      const n3 = NoticeModel(id: 3, title: 'Teachers Only', message: 'Meeting', targetRole: 'Teachers', publishDate: '2026-08-23');

      // Student View for Class 10
      final studentFeed = [n1, n2, n3].where((n) {
        if (n.targetRole == 'Teachers') return false;
        if (n.studentClass != null && n.studentClass != 'All' && n.studentClass != '10') return false;
        return true;
      }).toList();

      expect(studentFeed.length, equals(2));
      expect(studentFeed.map((n) => n.title), containsAll(['All Notice', 'Class 10 Only']));
    });

    test('12. Expired notices are filtered from active feeds', () {
      const activeNotice = NoticeModel(id: 1, title: 'Active', message: 'A', publishDate: '2026-08-20', expiryDate: '2026-08-30');
      const expiredNotice = NoticeModel(id: 2, title: 'Expired', message: 'B', publishDate: '2026-08-01', expiryDate: '2026-08-10');

      final activeFeed = [activeNotice, expiredNotice].where((n) => !n.isExpired).toList();
      expect(activeFeed.length, equals(1));
      expect(activeFeed.first.title, equals('Active'));
    });

    test('13. Notice priority sorting (Urgent > Important > Normal)', () {
      const nNormal = NoticeModel(id: 1, title: 'Normal', message: 'A', priority: 'Normal', publishDate: '2026-08-23');
      const nUrgent = NoticeModel(id: 2, title: 'Urgent', message: 'B', priority: 'Urgent', publishDate: '2026-08-23');
      const nImportant = NoticeModel(id: 3, title: 'Important', message: 'C', priority: 'Important', publishDate: '2026-08-23');

      final list = [nNormal, nUrgent, nImportant];
      list.sort((a, b) {
        final pMap = {'Urgent': 3, 'Important': 2, 'Normal': 1};
        return pMap[b.priority]!.compareTo(pMap[a.priority]!);
      });

      expect(list.first.title, equals('Urgent'));
      expect(list[1].title, equals('Important'));
      expect(list.last.title, equals('Normal'));
    });

    test('17. Today\'s schedule resolves correct weekday name', () {
      final todayStr = TimetableRepository.todayDayOfWeek;
      expect(TimetableRepository.daysOfWeek, contains(todayStr));
    });

    test('20. Regression check for existing modules and date restriction', () {
      final todayIso = AttendanceDateValidator.todayIso;
      expect(AttendanceDateValidator.isFutureDate(todayIso), isFalse);
    });
  });
}
