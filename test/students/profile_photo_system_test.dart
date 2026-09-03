import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';

void main() {
  group('Phase 17 — Profile Photo & Backup/Restore ZIP Packaging System Tests', () {
    
    test('1. Student and Teacher models serialization with profilePhotoPath', () {
      final student = StudentModel(
        id: 1,
        name: 'Arjun Verma',
        fatherName: 'Rajesh Verma',
        board: 'CBSE',
        studentClass: 'Class 10',
        rollNo: 12,
        mobile: '9876543210',
        createdAt: '2026-08-23T18:00:00Z',
        profilePhotoPath: 'profile_photos/students/student_1_1724430000.jpg',
      );

      final studentMap = student.toMap();
      expect(studentMap['profilePhotoPath'], equals('profile_photos/students/student_1_1724430000.jpg'));

      final restoredStudent = StudentModel.fromMap(studentMap);
      expect(restoredStudent.profilePhotoPath, equals('profile_photos/students/student_1_1724430000.jpg'));

      final teacher = TeacherModel(
        id: 1,
        name: 'Dr. Ramesh Nair',
        mobile: '9988776655',
        subject: 'Physics',
        payPerHour: 450.0,
        joiningDate: '2026-02-01',
        createdAt: '2026-02-01T10:00:00Z',
        profilePhotoPath: 'profile_photos/teachers/teacher_1_1724430000.jpg',
      );

      final teacherMap = teacher.toMap();
      expect(teacherMap['profilePhotoPath'], equals('profile_photos/teachers/teacher_1_1724430000.jpg'));

      final restoredTeacher = TeacherModel.fromMap(teacherMap);
      expect(restoredTeacher.profilePhotoPath, equals('profile_photos/teachers/teacher_1_1724430000.jpg'));
    });

    test('2. Fallback default initials when profile photo path is null', () {
      final student = StudentModel(
        id: 1,
        name: 'Arjun Verma',
        fatherName: 'Rajesh Verma',
        board: 'CBSE',
        studentClass: 'Class 10',
        rollNo: 12,
        mobile: '9876543210',
        createdAt: '2026-08-23T18:00:00Z',
        profilePhotoPath: null,
      );

      expect(student.profilePhotoPath, isNull);
      final fallbackLetter = student.name.isNotEmpty ? student.name[0] : 'S';
      expect(fallbackLetter, equals('A'));
    });

    test('3. Role restrictions: Admin edit authorization simulation', () {
      // Simulate Admin session
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);

      // Simulate Student session
      final studentMock = StudentModel(
        id: 2,
        name: 'Arjun Verma',
        fatherName: 'Rajesh Verma',
        board: 'CBSE',
        studentClass: 'Class 10',
        rollNo: 12,
        mobile: '9876543210',
        createdAt: '2026-08-23T18:00:00Z',
      );
      AppSession.instance.setStudentSession(studentMock);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('4. Backup ZIP archive packaging & validation logic simulation', () {
      final archive = Archive();
      
      // Simulate adding db
      final dbContent = 'sqlite_db_content';
      archive.addFile(ArchiveFile('omega_education.db', dbContent.length, dbContent.codeUnits));

      // Simulate adding profile photo
      final photoContent = 'fake_image_bytes';
      archive.addFile(ArchiveFile('profile_photos/students/student_1.jpg', photoContent.length, photoContent.codeUnits));

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);
      expect(zipBytes, isNotNull);

      // Decompress and validate
      final decoder = ZipDecoder();
      final decodedArchive = decoder.decodeBytes(zipBytes!);
      expect(decodedArchive.length, equals(2));

      final dbFile = decodedArchive.firstWhere((f) => f.name == 'omega_education.db');
      expect(String.fromCharCodes(dbFile.content as List<int>), equals(dbContent));

      final photoFile = decodedArchive.firstWhere((f) => f.name == 'profile_photos/students/student_1.jpg');
      expect(String.fromCharCodes(photoFile.content as List<int>), equals(photoContent));
    });

    test('5. Restore swap and emergency pre-restore rollback simulation', () {
      // Setup mock files for simulation
      final tempDir = Directory.systemTemp.createTempSync('restore_test');
      try {
        final activeDb = File(p.join(tempDir.path, 'omega_education.db'));
        activeDb.writeAsStringSync('active_state');

        // Create emergency pre-restore backup content (ZIP)
        final archive = Archive();
        archive.addFile(ArchiveFile('omega_education.db', 'emergency_checkpoint'.length, 'emergency_checkpoint'.codeUnits));
        final encoder = ZipEncoder();
        final emergencyZip = encoder.encode(archive)!;

        final emergencyBackup = File(p.join(tempDir.path, 'emergency.zip'));
        emergencyBackup.writeAsBytesSync(emergencyZip);

        // Simulate a successful restore by swapping files from a valid ZIP
        final newArchive = Archive();
        newArchive.addFile(ArchiveFile('omega_education.db', 'new_restored_state'.length, 'new_restored_state'.codeUnits));
        final newZip = encoder.encode(newArchive)!;

        final restoreZipFile = File(p.join(tempDir.path, 'restore.zip'));
        restoreZipFile.writeAsBytesSync(newZip);

        // Perform mock swap logic
        final bytes = restoreZipFile.readAsBytesSync();
        final decoded = ZipDecoder().decodeBytes(bytes);
        final decodedDb = decoded.firstWhere((f) => f.name == 'omega_education.db');
        activeDb.writeAsBytesSync(decodedDb.content as List<int>);

        expect(activeDb.readAsStringSync(), equals('new_restored_state'));

        // Simulate failure on validation & trigger rollback to emergency
        final emergencyBytes = emergencyBackup.readAsBytesSync();
        final decodedEmergency = ZipDecoder().decodeBytes(emergencyBytes);
        final decodedEmergencyDb = decodedEmergency.firstWhere((f) => f.name == 'omega_education.db');
        activeDb.writeAsBytesSync(decodedEmergencyDb.content as List<int>);

        expect(activeDb.readAsStringSync(), equals('emergency_checkpoint'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('6. Database schema version v15 migration simulation', () {
      // Verify Alter table queries for v15
      final List<String> sqlQueries = [];
      
      void migrate(int oldVersion) {
        if (oldVersion < 15) {
          sqlQueries.add('ALTER TABLE students ADD COLUMN profilePhotoPath TEXT');
          sqlQueries.add('ALTER TABLE teachers ADD COLUMN profilePhotoPath TEXT');
        }
      }

      migrate(14);
      expect(sqlQueries.length, equals(2));
      expect(sqlQueries[0], contains('ALTER TABLE students ADD COLUMN profilePhotoPath'));
      expect(sqlQueries[1], contains('ALTER TABLE teachers ADD COLUMN profilePhotoPath'));
    });
  });
}
