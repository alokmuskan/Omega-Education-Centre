import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/features/settings/models/institute_profile_model.dart';
import 'package:omega_education_centre/features/settings/models/master_data_model.dart';
import 'package:omega_education_centre/features/settings/services/institute_config_service.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late InstituteConfigService service;

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('app_settings');
    service = InstituteConfigService();
  });

  tearDown(() async {
    await DatabaseHelper.instance.closeDatabase();
  });

  group('Phase 23 — Institute Configuration & Profile Settings Tests', () {
    test('1. Default Institute Profile loads fallback AppConstants', () async {
      final profile = await service.getInstituteProfile();

      expect(profile.name, AppConstants.appName);
      expect(profile.address, 'Samastipur, Bihar');
      expect(profile.phone, '+91 9876543210');
      expect(profile.email, 'info@omegaeducation.com');
      expect(profile.principalName, 'Director Name');
      expect(profile.academicYear, '2026-27');
    });

    test('2. Saves and retrieves updated Institute Profile settings', () async {
      final newProfile = const InstituteProfileModel(
        name: 'Omega Higher Academy',
        address: 'Patna, Bihar',
        phone: '+91 9999988888',
        email: 'admin@omegahigher.org',
        principalName: 'Dr. A. K. Sharma',
        academicYear: '2027-28',
        logoPath: 'assets/logo/custom_logo.png',
      );

      await service.saveInstituteProfile(newProfile);

      final retrieved = await service.getInstituteProfile();
      expect(retrieved.name, 'Omega Higher Academy');
      expect(retrieved.address, 'Patna, Bihar');
      expect(retrieved.phone, '+91 9999988888');
      expect(retrieved.email, 'admin@omegahigher.org');
      expect(retrieved.principalName, 'Dr. A. K. Sharma');
      expect(retrieved.academicYear, '2027-28');
      expect(retrieved.logoPath, 'assets/logo/custom_logo.png');
    });

    test('3. Saves and retrieves active Academic Year', () async {
      final initialYr = await service.getAcademicYear();
      expect(initialYr, '2026-27');

      await service.saveAcademicYear('2028-29');
      final updatedYr = await service.getAcademicYear();
      expect(updatedYr, '2028-29');
    });
  });

  group('Phase 23 — Master Data Management & Active Filtering Tests', () {
    test('4. Seeds default Master Data categories automatically', () async {
      final classes = await service.getActiveMasterNames(MasterCategory.studentClass);
      expect(classes, containsAll(['10', '11', '12']));

      final boards = await service.getActiveMasterNames(MasterCategory.board);
      expect(boards, containsAll(['CBSE', 'BSEB', 'ICSE']));

      final subjects = await service.getActiveMasterNames(MasterCategory.subject);
      expect(subjects, containsAll(['Mathematics', 'Physics', 'Chemistry']));

      final examTypes = await service.getActiveMasterNames(MasterCategory.examType);
      expect(examTypes, containsAll(['Monthly Test', 'Unit Test', 'Final Exam']));
    });

    test('5. Adds new custom master item and verifies active list', () async {
      await service.addMasterItem(MasterCategory.studentClass, 'Foundation');
      await service.addMasterItem(MasterCategory.subject, 'Robotics');

      final activeClasses = await service.getActiveMasterNames(MasterCategory.studentClass);
      expect(activeClasses, contains('Foundation'));

      final activeSubjects = await service.getActiveMasterNames(MasterCategory.subject);
      expect(activeSubjects, contains('Robotics'));
    });

    test('6. Deactivates master item and verifies exclusion from active list', () async {
      final items = await service.getMasterItems(MasterCategory.board);
      final cbseItem = items.firstWhere((i) => i.name == 'CBSE');

      await service.toggleMasterItemActive(MasterCategory.board, cbseItem.id, false);

      final activeBoards = await service.getActiveMasterNames(MasterCategory.board);
      expect(activeBoards, isNot(contains('CBSE')));

      // All items (including deactivated) should still be stored
      final allBoards = await service.getMasterItems(MasterCategory.board);
      expect(allBoards.any((i) => i.name == 'CBSE' && !i.isActive), isTrue);
    });

    test('7. Historical preservation incorporates historical value even if deactivated', () async {
      final items = await service.getMasterItems(MasterCategory.subject);
      final mathItem = items.firstWhere((i) => i.name == 'Mathematics');
      await service.toggleMasterItemActive(MasterCategory.subject, mathItem.id, false);

      // Active names only should NOT contain Mathematics
      final activeOnly = await service.getActiveMasterNames(MasterCategory.subject);
      expect(activeOnly, isNot(contains('Mathematics')));

      // Active names WITH historical value SHOULD contain Mathematics
      final withHistorical = await service.getActiveMasterNamesWithHistorical(
        MasterCategory.subject,
        'Mathematics',
      );
      expect(withHistorical, contains('Mathematics'));
    });

    test('8. Renames existing master item without altering ID', () async {
      final items = await service.getMasterItems(MasterCategory.examType);
      final item = items.firstWhere((i) => i.name == 'Monthly Test');

      final updatedItem = item.copyWith(name: 'Periodic Test');
      await service.updateMasterItem(MasterCategory.examType, updatedItem);

      final activeExamTypes = await service.getActiveMasterNames(MasterCategory.examType);
      expect(activeExamTypes, contains('Periodic Test'));
      expect(activeExamTypes, isNot(contains('Monthly Test')));
    });
  });

  group('Phase 23 — Role-Based Access Protection Tests', () {
    test('9. Admin session verification for configuration screen', () {
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);

      final mockTeacher = TeacherModel(
        id: 1,
        name: 'Teacher One',
        mobile: '9876543210',
        subject: 'Physics',
        payPerHour: 300,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      );
      AppSession.instance.setTeacherSession(mockTeacher);
      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.isTeacher, isTrue);

      final mockStudent = const StudentModel(
        id: 1,
        name: 'Student One',
        fatherName: 'Father',
        mobile: '9876543210',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 101,
        createdAt: '2025-01-01T00:00:00Z',
      );
      AppSession.instance.setStudentSession(mockStudent);
      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.isStudent, isTrue);
    });
  });
}
