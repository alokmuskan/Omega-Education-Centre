import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite database helper.
///
/// Version history:
///   v1 — students table only
///   v2 — adds motherName/isActive/createdAt/updatedAt to students;
///         creates 9 new tables (teachers, teacher_attendance,
///         teacher_payments, student_attendance, fees, fee_payments,
///         tests, test_results, users)
///   v3 — extends fees table with paymentMethod/courseFee/monthlyAmount/
///         paymentDueDay/startMonth/durationMonths columns;
///         adds fee_installments table (TABLE 11)
///   v4 — adds updatedAt column to teachers table (TABLE 2)
///   v5 — adds remarks/createdAt/updatedAt to student_attendance (TABLE 5)
///         and createdAt/updatedAt to teacher_attendance (TABLE 3)
///   v6 — extends teacher_payments (TABLE 4) with year/paymentMethod/createdAt/updatedAt
///   v7 — creates teacher_pay_rate_history (TABLE 10) for historical pay rate tracking
///   v8 — extends tests & test_results with relational test_subjects and UNIQUE(testId, studentId, testSubjectId)
///   v9 — resolves legacy tests.subject NOT NULL constraint via safe table recreate migration
///   v10 — resolves legacy UNIQUE(testId, studentId) constraint on test_results via safe table recreate migration to UNIQUE(testId, studentId, testSubjectId)
///   v11 — creates daily_class_records (TABLE 14) for Daily Class Register module
///   v12 — creates timetable_entries (TABLE 15) and notices (TABLE 16) for Phase 8 Timetable & Notices module
///   v13 — adds periodNumber to timetable_entries, targetBoard & isPublished to notices, and creates notice_reads (TABLE 17)
///   v14 — extends fee_payments table with receiptNo & createdAt for Phase 10 Fee Management
class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String databasePath = await getDatabasesPath();
    final String path = join(databasePath, 'omega_education.db');

    final db = await openDatabase(
      path,
      version: 18,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Auto-repair notices table columns for any existing database installation
    await _ensureNoticeTableColumns(db);

    return db;
  }

  // ──────────────────────────────────────────────────────────────────────
  // onCreate — fresh install: all 18 tables
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createStudentsTable(db);
    await _createTeachersTable(db);
    await _createTeacherAttendanceTable(db);
    await _createTeacherPaymentsTable(db);
    await _createStudentAttendanceTable(db);
    await _createFeesTable(db);
    await _createFeePaymentsTable(db);
    await _createFeeInstallmentsTable(db);
    await _createTestsTable(db);
    await _createTestResultsTable(db);
    await _createUsersTable(db);
    await _createTeacherPayRateHistoryTable(db);
    await _createTestSubjectsTable(db);
    await _createDailyClassRecordsTable(db);
    await _createTimetableEntriesTable(db);
    await _createNoticesTable(db);
    await _createNoticeReadsTable(db);
    await _createAppSettingsTable(db);
    await _createSyncQueueTable(db);
  }

  // ──────────────────────────────────────────────────────────────────────
  // onUpgrade — existing install: ALTER TABLE only, no data loss
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2 migration
      await db.execute(
        'ALTER TABLE students ADD COLUMN motherName TEXT',
      );
      await db.execute(
        'ALTER TABLE students ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        "ALTER TABLE students ADD COLUMN createdAt TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE students ADD COLUMN updatedAt TEXT',
      );

      await _createTeachersTable(db);
      await _createTeacherAttendanceTable(db);
      await _createTeacherPaymentsTable(db);
      await _createStudentAttendanceTable(db);
      await _createFeesTable(db);
      await _createFeePaymentsTable(db);
      await _createTestsTable(db);
      await _createTestResultsTable(db);
      await _createUsersTable(db);
    }

    if (oldVersion < 3) {
      // v2 → v3 migration: extend fees + add fee_installments
      await db.execute(
        "ALTER TABLE fees ADD COLUMN paymentMethod TEXT NOT NULL DEFAULT 'Installments'",
      );
      await db.execute(
        'ALTER TABLE fees ADD COLUMN courseFee REAL',
      );
      await db.execute(
        'ALTER TABLE fees ADD COLUMN monthlyAmount REAL',
      );
      await db.execute(
        'ALTER TABLE fees ADD COLUMN paymentDueDay INTEGER',
      );
      await db.execute(
        'ALTER TABLE fees ADD COLUMN startMonth TEXT',
      );
      await db.execute(
        'ALTER TABLE fees ADD COLUMN durationMonths INTEGER',
      );
      await _createFeeInstallmentsTable(db);
    }

    if (oldVersion < 4) {
      // v3 → v4 migration: add updatedAt column to teachers
      await db.execute(
        'ALTER TABLE teachers ADD COLUMN updatedAt TEXT',
      );
    }

    if (oldVersion < 5) {
      // v4 → v5 migration: add remarks/createdAt/updatedAt to attendance tables
      await db.execute(
        'ALTER TABLE student_attendance ADD COLUMN remarks TEXT',
      );
      await db.execute(
        'ALTER TABLE student_attendance ADD COLUMN createdAt TEXT',
      );
      await db.execute(
        'ALTER TABLE student_attendance ADD COLUMN updatedAt TEXT',
      );

      await db.execute(
        'ALTER TABLE teacher_attendance ADD COLUMN createdAt TEXT',
      );
      await db.execute(
        'ALTER TABLE teacher_attendance ADD COLUMN updatedAt TEXT',
      );
    }

    if (oldVersion < 6) {
      // v5 → v6 migration: add year/paymentMethod/createdAt/updatedAt to teacher_payments
      await db.execute(
        'ALTER TABLE teacher_payments ADD COLUMN year INTEGER',
      );
      await db.execute(
        "ALTER TABLE teacher_payments ADD COLUMN paymentMethod TEXT DEFAULT 'Cash'",
      );
      await db.execute(
        'ALTER TABLE teacher_payments ADD COLUMN createdAt TEXT',
      );
      await db.execute(
        'ALTER TABLE teacher_payments ADD COLUMN updatedAt TEXT',
      );
    }

    if (oldVersion < 7) {
      // v6 → v7 migration: create teacher_pay_rate_history table and seed initial rates
      await _createTeacherPayRateHistoryTable(db);
      await db.execute('''
        INSERT INTO teacher_pay_rate_history (teacherId, payPerHour, effectiveFrom, effectiveTo, createdAt, updatedAt)
        SELECT id, payPerHour, COALESCE(createdAt, '2020-01-01'), NULL, DATETIME('now'), DATETIME('now')
        FROM teachers
      ''');
    }

    if (oldVersion < 8) {
      // v7 → v8 migration: create test_subjects table and extend tests/test_results
      await _createTestSubjectsTable(db);

      // Safe columns addition for tests
      try {
        await db.execute("ALTER TABLE tests ADD COLUMN title TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tests ADD COLUMN testType TEXT DEFAULT 'Monthly Test'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tests ADD COLUMN board TEXT DEFAULT 'CBSE'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tests ADD COLUMN academicYear TEXT DEFAULT '2026-27'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tests ADD COLUMN remarks TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tests ADD COLUMN isArchived INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tests ADD COLUMN updatedAt TEXT");
      } catch (_) {}

      // Update tests title from legacy testName
      await db.execute("UPDATE tests SET title = testName WHERE title IS NULL OR title = ''");

      // Safe columns addition for test_results
      try {
        await db.execute("ALTER TABLE test_results ADD COLUMN testSubjectId INTEGER REFERENCES test_subjects(id)");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE test_results ADD COLUMN createdAt TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE test_results ADD COLUMN updatedAt TEXT");
      } catch (_) {}
    }

    if (oldVersion < 9) {
      // v8 → v9 migration: recreate tests table without legacy subject NOT NULL constraint,
      // preserving all existing test records and migrating legacy subject data to test_subjects.

      final columnsInfo = await db.rawQuery("PRAGMA table_info(tests)");
      final columnNames = columnsInfo.map((c) => c['name'] as String).toSet();

      await db.execute('''
        CREATE TABLE _tests_v9_temp (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          title        TEXT    NOT NULL,
          testType     TEXT    NOT NULL DEFAULT 'Monthly Test',
          board        TEXT    NOT NULL DEFAULT 'CBSE',
          studentClass TEXT    NOT NULL,
          testDate     TEXT    NOT NULL,
          academicYear TEXT    NOT NULL DEFAULT '2026-27',
          remarks      TEXT,
          isArchived   INTEGER NOT NULL DEFAULT 0,
          createdAt    TEXT,
          updatedAt    TEXT
        )
      ''');

      final hasTestName = columnNames.contains('testName');
      final hasTitle = columnNames.contains('title');
      final hasTestType = columnNames.contains('testType');
      final hasBoard = columnNames.contains('board');
      final hasAcademicYear = columnNames.contains('academicYear');
      final hasRemarks = columnNames.contains('remarks');
      final hasSyllabus = columnNames.contains('syllabus');
      final hasIsArchived = columnNames.contains('isArchived');

      final titleExpr = hasTitle && hasTestName
          ? "COALESCE(NULLIF(title, ''), testName, 'Untitled Test')"
          : hasTitle
              ? "COALESCE(NULLIF(title, ''), 'Untitled Test')"
              : hasTestName
                  ? "COALESCE(testName, 'Untitled Test')"
                  : "'Untitled Test'";

      final testTypeExpr = hasTestType ? "COALESCE(testType, 'Monthly Test')" : "'Monthly Test'";
      final boardExpr = hasBoard ? "COALESCE(board, 'CBSE')" : "'CBSE'";
      final academicYearExpr = hasAcademicYear ? "COALESCE(academicYear, '2026-27')" : "'2026-27'";
      final remarksExpr = hasRemarks && hasSyllabus
          ? "COALESCE(remarks, syllabus)"
          : hasRemarks
              ? "remarks"
              : hasSyllabus
                  ? "syllabus"
                  : "NULL";
      final isArchivedExpr = hasIsArchived ? "COALESCE(isArchived, 0)" : "0";

      await db.execute('''
        INSERT INTO _tests_v9_temp (
          id, title, testType, board, studentClass, testDate, academicYear, remarks, isArchived, createdAt, updatedAt
        )
        SELECT 
          id,
          $titleExpr,
          $testTypeExpr,
          $boardExpr,
          studentClass,
          testDate,
          $academicYearExpr,
          $remarksExpr,
          $isArchivedExpr,
          COALESCE(createdAt, DATETIME('now')),
          COALESCE(updatedAt, DATETIME('now'))
        FROM tests
      ''');

      // Migrate legacy single subject to test_subjects if present
      if (columnNames.contains('subject') && columnNames.contains('maxMarks')) {
        await db.execute('''
          INSERT INTO test_subjects (testId, subjectName, maxMarks, passMarks, createdAt, updatedAt)
          SELECT 
            t.id,
            t.subject,
            COALESCE(t.maxMarks, 100.0),
            ROUND(COALESCE(t.maxMarks, 100.0) * 0.33),
            DATETIME('now'),
            DATETIME('now')
          FROM tests t
          WHERE t.subject IS NOT NULL AND t.subject != ''
            AND NOT EXISTS (SELECT 1 FROM test_subjects ts WHERE ts.testId = t.id)
        ''');
      }

      await db.execute("DROP TABLE tests");
      await db.execute("ALTER TABLE _tests_v9_temp RENAME TO tests");
    }

    if (oldVersion < 10) {
      // v9 → v10 migration: recreate test_results table with correct UNIQUE(testId, studentId, testSubjectId) constraint,
      // resolving legacy UNIQUE(testId, studentId) collision that caused multiple subjects for the same student to overwrite each other.

      final columnsInfo = await db.rawQuery("PRAGMA table_info(test_results)");
      final columnNames = columnsInfo.map((c) => c['name'] as String).toSet();

      await db.execute('''
        CREATE TABLE _test_results_v10_temp (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          testId        INTEGER NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
          studentId     INTEGER NOT NULL REFERENCES students(id),
          testSubjectId INTEGER NOT NULL REFERENCES test_subjects(id) ON DELETE CASCADE,
          marksObtained REAL    NOT NULL CHECK (marksObtained >= 0),
          remarks       TEXT,
          createdAt     TEXT,
          updatedAt     TEXT,
          UNIQUE(testId, studentId, testSubjectId)
        )
      ''');

      if (columnNames.contains('testSubjectId')) {
        await db.execute('''
          INSERT INTO _test_results_v10_temp (
            id, testId, studentId, testSubjectId, marksObtained, remarks, createdAt, updatedAt
          )
          SELECT 
            id, testId, studentId, testSubjectId, marksObtained, remarks,
            COALESCE(createdAt, DATETIME('now')),
            COALESCE(updatedAt, DATETIME('now'))
          FROM test_results
          WHERE testSubjectId IS NOT NULL
        ''');
      }

      await db.execute("DROP TABLE test_results");
      await db.execute("ALTER TABLE _test_results_v10_temp RENAME TO test_results");

      // Create explicit unique index
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_test_results_unique 
        ON test_results(testId, studentId, testSubjectId)
      ''');
    }

    if (oldVersion < 11) {
      // v10 → v11 migration: create daily_class_records (TABLE 14) for Daily Class Register module
      await _createDailyClassRecordsTable(db);
    }

    if (oldVersion < 12) {
      // v11 → v12 migration: create timetable_entries (TABLE 15) and notices (TABLE 16)
      await _createTimetableEntriesTable(db);
      await _createNoticesTable(db);
    }

    if (oldVersion < 13) {
      // v12 → v13 migration: ALTER TABLE and create notice_reads (TABLE 17)
      try {
        await db.execute('ALTER TABLE timetable_entries ADD COLUMN periodNumber INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE notices ADD COLUMN targetBoard TEXT DEFAULT "All"');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE notices ADD COLUMN isPublished INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      await _createNoticeReadsTable(db);
    }

    if (oldVersion < 14) {
      // v13 → v14 migration: extend fee_payments table with receiptNo and createdAt
      try {
        await db.execute('ALTER TABLE fee_payments ADD COLUMN receiptNo TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE fee_payments ADD COLUMN createdAt TEXT');
      } catch (_) {}
    }

    if (oldVersion < 15) {
      // v14 → v15 migration: add profilePhotoPath to students and teachers
      try {
        await db.execute('ALTER TABLE students ADD COLUMN profilePhotoPath TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE teachers ADD COLUMN profilePhotoPath TEXT');
      } catch (_) {}
    }

    if (oldVersion < 16) {
      // v15 → v16 migration: create app_settings table for organisation identity & disaster recovery
      await _createAppSettingsTable(db);
    }

    if (oldVersion < 17) {
      // v16 → v17 migration: non-destructive notices table column repair ensuring targetClass and all notice columns exist
      await _ensureNoticeTableColumns(db);
    }

    if (oldVersion < 18) {
      // v17 → v18 migration: create sync_queue table and add sync columns
      await _createSyncQueueTable(db);
      try {
        await db.execute('ALTER TABLE students ADD COLUMN deletedAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE students ADD COLUMN syncedAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE teachers ADD COLUMN deletedAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE teachers ADD COLUMN syncedAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN deletedAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN syncedAt TEXT');
      } catch (_) {}
    }
  }

  Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entityType TEXT NOT NULL,
        localId TEXT NOT NULL,
        operation TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0,
        lastAttempt TEXT,
        syncStatus TEXT NOT NULL DEFAULT 'PENDING',
        errorMessage TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 1 — students
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createStudentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE students (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        fatherName   TEXT    NOT NULL,
        motherName   TEXT,
        board        TEXT    NOT NULL,
        studentClass TEXT    NOT NULL,
        rollNo       INTEGER NOT NULL,
        mobile       TEXT    NOT NULL,
        feeStatus    TEXT    NOT NULL DEFAULT 'Due',
        address      TEXT,
        isActive     INTEGER NOT NULL DEFAULT 1,
        createdAt    TEXT    NOT NULL,
        updatedAt    TEXT,
        profilePhotoPath TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 2 — teachers
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTeachersTable(Database db) async {
    await db.execute('''
      CREATE TABLE teachers (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        mobile        TEXT    NOT NULL,
        subject       TEXT    NOT NULL,
        qualification TEXT,
        payPerHour    REAL    NOT NULL DEFAULT 0,
        joiningDate   TEXT    NOT NULL,
        isActive      INTEGER NOT NULL DEFAULT 1,
        createdAt     TEXT    NOT NULL,
        updatedAt     TEXT,
        profilePhotoPath TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 3 — teacher_attendance
  // UNIQUE(teacherId, date): one record per teacher per day.
  // Use ConflictAlgorithm.replace to edit existing records safely.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTeacherAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE teacher_attendance (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        teacherId   INTEGER NOT NULL REFERENCES teachers(id),
        date        TEXT    NOT NULL,
        hoursWorked REAL    NOT NULL CHECK (hoursWorked >= 0),
        remarks     TEXT,
        createdAt   TEXT,
        updatedAt   TEXT,
        UNIQUE(teacherId, date)
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 4 — teacher_payments
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTeacherPaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE teacher_payments (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        teacherId     INTEGER NOT NULL REFERENCES teachers(id),
        month         TEXT    NOT NULL,
        year          INTEGER,
        amount        REAL    NOT NULL CHECK (amount > 0),
        paymentDate   TEXT    NOT NULL,
        paymentMode   TEXT    NOT NULL DEFAULT 'Cash', -- Legacy schema column (retained for backward compatibility; paymentMethod is authoritative)
        paymentMethod TEXT    NOT NULL DEFAULT 'Cash',
        remarks       TEXT,
        createdAt     TEXT,
        updatedAt     TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 10 — teacher_pay_rate_history
  // Relational table tracking effective pay rates over time per teacher.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTeacherPayRateHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE teacher_pay_rate_history (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        teacherId     INTEGER NOT NULL REFERENCES teachers(id),
        payPerHour    REAL    NOT NULL CHECK (payPerHour > 0),
        effectiveFrom TEXT    NOT NULL,
        effectiveTo   TEXT,
        createdAt     TEXT,
        updatedAt     TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 5 — student_attendance
  // UNIQUE(studentId, date): prevents duplicate daily entries.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createStudentAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE student_attendance (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL REFERENCES students(id),
        date      TEXT    NOT NULL,
        status    TEXT    NOT NULL,
        remarks   TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        UNIQUE(studentId, date)
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 6 — fees
  // totalFee = final agreed fee. paidAmount is NEVER stored here.
  // paymentMethod: 'Monthly' | 'Installments'
  // courseFee: nominal catalogue fee (may differ from totalFee)
  // Monthly fields: monthlyAmount, paymentDueDay, startMonth, durationMonths
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createFeesTable(Database db) async {
    await db.execute('''
      CREATE TABLE fees (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId      INTEGER NOT NULL REFERENCES students(id),
        paymentMethod  TEXT    NOT NULL DEFAULT 'Installments',
        courseFee      REAL,
        totalFee       REAL    NOT NULL,
        monthlyAmount  REAL,
        paymentDueDay  INTEGER,
        startMonth     TEXT,
        durationMonths INTEGER,
        description    TEXT,
        createdAt      TEXT    NOT NULL
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 7 — fee_payments
  // Append-only ledger. Records are NEVER modified or deleted.
  // This is the sole source of truth for money paid.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createFeePaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE fee_payments (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        feeId       INTEGER NOT NULL REFERENCES fees(id),
        studentId   INTEGER NOT NULL REFERENCES students(id),
        amount      REAL    NOT NULL CHECK (amount > 0),
        paymentDate TEXT    NOT NULL,
        paymentMode TEXT    NOT NULL DEFAULT 'Cash',
        remarks     TEXT,
        receiptNo   TEXT,
        createdAt   TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 11 — fee_installments
  // Expected payment schedule. NOT proof of payment.
  // For Monthly: one row per month, auto-generated at admission.
  // For Installments: admin-defined rows, variable amounts and dates.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createFeeInstallmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE fee_installments (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        feeId       INTEGER NOT NULL REFERENCES fees(id),
        studentId   INTEGER NOT NULL REFERENCES students(id),
        amount      REAL    NOT NULL CHECK (amount > 0),
        dueDate     TEXT    NOT NULL,
        description TEXT,
        createdAt   TEXT    NOT NULL
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 8 — tests
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTestsTable(Database db) async {
    await db.execute('''
      CREATE TABLE tests (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        title        TEXT    NOT NULL,
        testType     TEXT    NOT NULL DEFAULT 'Monthly Test',
        board        TEXT    NOT NULL DEFAULT 'CBSE',
        studentClass TEXT    NOT NULL,
        testDate     TEXT    NOT NULL,
        academicYear TEXT    NOT NULL DEFAULT '2026-27',
        remarks      TEXT,
        isArchived   INTEGER NOT NULL DEFAULT 0,
        createdAt    TEXT,
        updatedAt    TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 12 — test_subjects
  // Configuration of subjects and max/pass marks for a test.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTestSubjectsTable(Database db) async {
    await db.execute('''
      CREATE TABLE test_subjects (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        testId      INTEGER NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
        subjectName TEXT    NOT NULL,
        maxMarks    REAL    NOT NULL CHECK (maxMarks > 0),
        passMarks   REAL    NOT NULL CHECK (passMarks >= 0),
        createdAt   TEXT,
        updatedAt   TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 9 — test_results
  // UNIQUE(testId, studentId, testSubjectId): prevents duplicate subject marks.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTestResultsTable(Database db) async {
    await db.execute('''
      CREATE TABLE test_results (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        testId        INTEGER NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
        studentId     INTEGER NOT NULL REFERENCES students(id),
        testSubjectId INTEGER NOT NULL REFERENCES test_subjects(id) ON DELETE CASCADE,
        marksObtained REAL    NOT NULL CHECK (marksObtained >= 0),
        remarks       TEXT,
        createdAt     TEXT,
        updatedAt     TEXT,
        UNIQUE(testId, studentId, testSubjectId)
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_test_results_unique 
      ON test_results(testId, studentId, testSubjectId)
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 10 — users
  // passwordHash: PBKDF2-HMAC-SHA256 derived key (64-char hex)
  // salt:         128-bit cryptographically secure random (32-char hex)
  // sessionToken: PBKDF2 hash of raw session token (not the raw token)
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        username     TEXT    NOT NULL UNIQUE,
        passwordHash TEXT    NOT NULL,
        salt         TEXT    NOT NULL,
        role         TEXT    NOT NULL,
        referenceId  INTEGER,
        sessionToken TEXT,
        isActive     INTEGER NOT NULL DEFAULT 1,
        createdAt    TEXT    NOT NULL
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 14 — daily_class_records
  // Stores actual teaching sessions conducted by teachers.
  // teacherId is the authoritative foreign key to teachers.id.
  // NO ON DELETE CASCADE: historical records remain intact if teacher is removed.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createDailyClassRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE daily_class_records (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        date            TEXT    NOT NULL,
        studentClass    TEXT    NOT NULL,
        board           TEXT    NOT NULL DEFAULT 'CBSE',
        batch           TEXT,
        teacherId       INTEGER NOT NULL REFERENCES teachers(id),
        subject         TEXT    NOT NULL,
        startTime       TEXT,
        endTime         TEXT,
        durationMinutes INTEGER NOT NULL DEFAULT 60,
        topic           TEXT    NOT NULL,
        homework        TEXT,
        remarks         TEXT,
        createdAt       TEXT    NOT NULL,
        updatedAt       TEXT    NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_class_records_date ON daily_class_records(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_class_records_class ON daily_class_records(studentClass)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_class_records_teacher ON daily_class_records(teacherId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_class_records_subject ON daily_class_records(subject)');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 15 — timetable_entries
  // Stores scheduled class sessions by day of week, class, batch, teacher, and subject.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createTimetableEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE timetable_entries (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        studentClass    TEXT    NOT NULL,
        board           TEXT    NOT NULL DEFAULT 'CBSE',
        batch           TEXT,
        dayOfWeek       TEXT    NOT NULL,
        periodNumber    INTEGER NOT NULL DEFAULT 1,
        startTime       TEXT    NOT NULL,
        endTime         TEXT    NOT NULL,
        subject         TEXT    NOT NULL,
        teacherId       INTEGER NOT NULL REFERENCES teachers(id),
        room            TEXT,
        remarks         TEXT,
        isActive        INTEGER NOT NULL DEFAULT 1,
        createdAt       TEXT    NOT NULL,
        updatedAt       TEXT    NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_timetable_day ON timetable_entries(dayOfWeek)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_timetable_class ON timetable_entries(studentClass)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_timetable_teacher ON timetable_entries(teacherId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_timetable_period ON timetable_entries(periodNumber)');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 16 — notices
  // Stores institute notices, announcements, exam alerts, and holidays.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createNoticesTable(Database db) async {
    await db.execute('''
      CREATE TABLE notices (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        title        TEXT    NOT NULL,
        message      TEXT    NOT NULL,
        noticeType   TEXT    NOT NULL DEFAULT 'General',
        targetRole   TEXT    NOT NULL DEFAULT 'Everyone',
        targetClass  TEXT,
        targetBoard  TEXT    DEFAULT 'All',
        targetBatch  TEXT,
        priority     TEXT    NOT NULL DEFAULT 'Normal',
        publishDate  TEXT    NOT NULL,
        expiryDate   TEXT,
        isPublished  INTEGER NOT NULL DEFAULT 1,
        isActive     INTEGER NOT NULL DEFAULT 1,
        createdAt    TEXT    NOT NULL,
        updatedAt    TEXT    NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_type ON notices(noticeType)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_target ON notices(targetRole)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_class ON notices(targetClass)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_publish ON notices(publishDate)');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 17 — notice_reads
  // Per-user read tracking for notices and announcements.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createNoticeReadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notice_reads (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        noticeId  INTEGER NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
        userId    TEXT    NOT NULL,
        readAt    TEXT    NOT NULL,
        UNIQUE(noticeId, userId)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notice_reads_user ON notice_reads(userId)');
  }

  // ──────────────────────────────────────────────────────────────────────
  // TABLE 18 — app_settings
  // Key-Value store for persistent organisation identity and disaster recovery config.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _createAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Retrieves a value from app_settings by key.
  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      final res = await db.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (res.isNotEmpty) {
        return res.first['value'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sets or updates a key-value pair in app_settings.
  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Ensures targetClass and all required columns exist in notices table non-destructively.
  Future<void> _ensureNoticeTableColumns(Database db) async {
    try {
      final columnsInfo = await db.rawQuery("PRAGMA table_info(notices)");
      final existingColumns = columnsInfo.map((c) => (c['name'] as String).toLowerCase()).toSet();

      final requiredColumns = <String, String>{
        'noticeType': "TEXT NOT NULL DEFAULT 'General'",
        'targetRole': "TEXT NOT NULL DEFAULT 'Everyone'",
        'targetClass': "TEXT",
        'targetBoard': "TEXT DEFAULT 'All'",
        'targetBatch': "TEXT",
        'priority': "TEXT NOT NULL DEFAULT 'Normal'",
        'publishDate': "TEXT NOT NULL DEFAULT ''",
        'expiryDate': "TEXT",
        'isPublished': "INTEGER NOT NULL DEFAULT 1",
        'isActive': "INTEGER NOT NULL DEFAULT 1",
        'createdAt': "TEXT",
        'updatedAt': "TEXT",
      };

      for (final entry in requiredColumns.entries) {
        if (!existingColumns.contains(entry.key.toLowerCase())) {
          try {
            await db.execute('ALTER TABLE notices ADD COLUMN ${entry.key} ${entry.value}');
          } catch (_) {}
        }
      }

      await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_type ON notices(noticeType)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_target ON notices(targetRole)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_class ON notices(targetClass)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notices_publish ON notices(publishDate)');
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────
  // Safe close — used by BackupService before copying the DB file.
  // After calling this, call [database] again to reopen.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}