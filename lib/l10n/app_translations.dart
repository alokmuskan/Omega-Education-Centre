import 'package:flutter/material.dart';

/// Static translations for English and Hindi.
///
/// Usage:
///   AppTranslations.of(context).login
///   AppTranslations.of(context).addStudent
class AppTranslations {
  final Locale locale;
  AppTranslations(this.locale);

  static AppTranslations of(BuildContext context) {
    return Localizations.of<AppTranslations>(context, AppTranslations)!;
  }

  bool get isHindi => locale.languageCode == 'hi';

  // ── Navigation & Common ───────────────────────────────────────

  String get login => isHindi ? 'लॉगिन' : 'LOGIN';
  String get logout => isHindi ? 'लॉगआउट' : 'Logout';
  String get save => isHindi ? 'सहेजें' : 'Save';
  String get cancel => isHindi ? 'रद्द करें' : 'Cancel';
  String get delete => isHindi ? 'हटाएं' : 'Delete';
  String get edit => isHindi ? 'संपादित करें' : 'Edit';
  String get add => isHindi ? 'जोड़ें' : 'Add';
  String get search => isHindi ? 'खोजें' : 'Search';
  String get settings => isHindi ? 'सेटिंग्स' : 'Settings';
  String get error => isHindi ? 'त्रुटि' : 'Error';
  String get loading => isHindi ? 'लोड हो रहा है...' : 'Loading...';
  String get noData => isHindi ? 'कोई डेटा उपलब्ध नहीं' : 'No data available';
  String get confirm => isHindi ? 'पुष्टि करें' : 'Confirm';
  String get yes => isHindi ? 'हाँ' : 'Yes';
  String get no => isHindi ? 'नहीं' : 'No';
  String get all => isHindi ? 'सभी' : 'All';
  String get active => isHindi ? 'सक्रिय' : 'Active';
  String get inactive => isHindi ? 'निष्क्रिय' : 'Inactive';
  String get back => isHindi ? 'वापस' : 'Back';
  String get next => isHindi ? 'अगला' : 'Next';
  String get done => isHindi ? 'हो गया' : 'Done';
  String get close => isHindi ? 'बंद करें' : 'Close';
  String get viewAll => isHindi ? 'सभी देखें' : 'View All';
  String get viewDetails => isHindi ? 'विवरण देखें' : 'View Details';

  // ── Authentication ───────────────────────────────────────────

  String get username => isHindi ? 'उपयोगकर्ता नाम' : 'Username';
  String get password => isHindi ? 'पासवर्ड' : 'Password';
  String get loginWithBiometrics => isHindi ? 'बायोमेट्रिक्स से लॉगिन करें' : 'Login with Biometrics';
  String get enableBiometric => isHindi ? 'बायोमेट्रिक्स सक्षम करें' : 'Enable Biometric';
  String get disableBiometric => isHindi ? 'बायोमेट्रिक्स अक्षम करें' : 'Disable Biometric';

  // ── Dashboard ────────────────────────────────────────────────

  String get dashboard => isHindi ? 'डैशबोर्ड' : 'Dashboard';
  String get quickActions => isHindi ? 'त्वरित कार्य' : 'Quick Actions';
  String get attendance => isHindi ? 'उपस्थिति' : 'Attendance';
  String get todayClasses => isHindi ? 'आज की कक्षाएं' : 'Classes Today';
  String get recentNotices => isHindi ? 'हाल की सूचनाएं' : 'Recent Notices';
  String get recentTests => isHindi ? 'हाल की परीक्षाएं' : 'Recent Tests';
  String get studentsToday => isHindi ? 'छात्र आज' : 'Students Today';
  String get teachersToday => isHindi ? 'शिक्षक आज' : 'Teachers Today';

  // ── Students ─────────────────────────────────────────────────

  String get students => isHindi ? 'छात्र' : 'Students';
  String get addStudent => isHindi ? 'छात्र जोड़ें' : 'Add Student';
  String get editStudent => isHindi ? 'छात्र संपादित करें' : 'Edit Student';
  String get studentName => isHindi ? 'छात्र का नाम' : 'Student Name';
  String get fatherName => isHindi ? 'पिता का नाम' : 'Father Name';
  String get motherName => isHindi ? 'माता का नाम' : 'Mother Name';
  String get rollNumber => isHindi ? 'रोल नंबर' : 'Roll Number';
  String get mobile => isHindi ? 'मोबाइल' : 'Mobile';
  String get class_ => isHindi ? 'कक्षा' : 'Class';
  String get board => isHindi ? 'बोर्ड' : 'Board';
  String get feeStatus => isHindi ? 'शुल्क स्थिति' : 'Fee Status';
  String get studentDetails => isHindi ? 'छात्र विवरण' : 'Student Details';
  String get noStudents => isHindi ? 'अभी तक कोई छात्र नामांकित नहीं है' : 'No students enrolled yet';
  String get studentIdCard => isHindi ? 'छात्र पहचान पत्र' : 'Student ID Card';

  // ── Teachers ─────────────────────────────────────────────────

  String get teachers => isHindi ? 'शिक्षक' : 'Teachers';
  String get addTeacher => isHindi ? 'शिक्षक जोड़ें' : 'Add Teacher';
  String get teacherName => isHindi ? 'शिक्षक का नाम' : 'Teacher Name';
  String get subject => isHindi ? 'विषय' : 'Subject';
  String get qualification => isHindi ? 'योग्यता' : 'Qualification';
  String get payPerHour => isHindi ? 'प्रति घंटा वेतन' : 'Pay Per Hour';
  String get joiningDate => isHindi ? 'जुड़ने की तिथि' : 'Joining Date';
  String get noTeachers => isHindi ? 'अभी तक कोई शिक्षक नहीं जोड़ा गया' : 'No teachers added yet';

  // ── Attendance ───────────────────────────────────────────────

  String get markAttendance => isHindi ? 'उपस्थिति दर्ज करें' : 'Mark Attendance';
  String get present => isHindi ? 'उपस्थित' : 'Present';
  String get absent => isHindi ? 'अनुपस्थित' : 'Absent';
  String get late => isHindi ? 'विलंबित' : 'Late';
  String get leave => isHindi ? 'अवकाश' : 'Leave';
  String get attendanceHistory => isHindi ? 'उपस्थिति इतिहास' : 'Attendance History';

  // ── Fees ─────────────────────────────────────────────────────

  String get fees => isHindi ? 'शुल्क' : 'Fees';
  String get feeManagement => isHindi ? 'शुल्क प्रबंधन' : 'Fee Management';
  String get recordPayment => isHindi ? 'भुगतान दर्ज करें' : 'Record Payment';
  String get feeDues => isHindi ? 'शुल्क बकाया' : 'Fee Dues';
  String get paid => isHindi ? 'भुगतान हो गया' : 'Paid';
  String get due => isHindi ? 'बकाया' : 'Due';
  String get partiallyPaid => isHindi ? 'आंशिक भुगतान' : 'Partially Paid';

  // ── Tests & Results ─────────────────────────────────────────

  String get tests => isHindi ? 'परीक्षाएं' : 'Tests';
  String get createTest => isHindi ? 'परीक्षा बनाएं' : 'Create Test';
  String get results => isHindi ? 'परिणाम' : 'Results';
  String get marksObtained => isHindi ? 'प्राप्त अंक' : 'Marks Obtained';
  String get maxMarks => isHindi ? 'अधिकतम अंक' : 'Max Marks';

  // ── Notices ──────────────────────────────────────────────────

  String get notices => isHindi ? 'सूचनाएं' : 'Notices';
  String get createNotice => isHindi ? 'सूचना बनाएं' : 'Create Notice';
  String get noticeTitle => isHindi ? 'सूचना शीर्षक' : 'Notice Title';
  String get noticeMessage => isHindi ? 'सूचना संदेश' : 'Notice Message';

  // ── Homework ─────────────────────────────────────────────────

  String get homework => isHindi ? 'गृहकार्य' : 'Homework';
  String get assignHomework => isHindi ? 'गृहकार्य सौंपें' : 'Assign Homework';
  String get dueDate => isHindi ? 'देय तिथि' : 'Due Date';
  String get priority => isHindi ? 'प्राथमिकता' : 'Priority';
  String get submitted => isHindi ? 'जमा हो गया' : 'Submitted';
  String get pending => isHindi ? 'लंबित' : 'Pending';

  // ── Academic Calendar ────────────────────────────────────────

  String get academicCalendar => isHindi ? 'शैक्षणिक कैलेंडर' : 'Academic Calendar';
  String get holidays => isHindi ? 'अवकाश' : 'Holidays';
  String get events => isHindi ? 'कार्यक्रम' : 'Events';
  String get addHoliday => isHindi ? 'अवकाश जोड़ें' : 'Add Holiday';
  String get addEvent => isHindi ? 'कार्यक्रम जोड़ें' : 'Add Event';

  // ── Salary ───────────────────────────────────────────────────

  String get salary => isHindi ? 'वेतन' : 'Salary';
  String get salaryDashboard => isHindi ? 'वेतन डैशबोर्ड' : 'Salary Dashboard';
  String get paymentHistory => isHindi ? 'भुगतान इतिहास' : 'Payment History';

  // ── Settings ─────────────────────────────────────────────────

  String get displaySettings => isHindi ? 'डिस्प्ले सेटिंग्स' : 'Display Settings';
  String get themeMode => isHindi ? 'थीम मोड' : 'Theme Mode';
  String get darkMode => isHindi ? 'डार्क मोड' : 'Dark Mode';
  String get lightMode => isHindi ? 'लाइट मोड' : 'Light Mode';
  String get systemDefault => isHindi ? 'सिस्टम डिफ़ॉल्ट' : 'System Default';
  String get language => isHindi ? 'भाषा' : 'Language';
  String get english => isHindi ? 'अंग्रेज़ी' : 'English';
  String get hindi => isHindi ? 'हिन्दी' : 'हिन्दी';
  String get sessionTimeout => isHindi ? 'सत्र समय-सीमा' : 'Session Timeout';
  String get biometricLogin => isHindi ? 'बायोमेट्रिक लॉगिन' : 'Biometric Login';
  String get securitySettings => isHindi ? 'सुरक्षा सेटिंग्स' : 'Security Settings';

  // ── Batches ──────────────────────────────────────────────────

  String get batches => isHindi ? 'बैच' : 'Batches';
  String get createBatch => isHindi ? 'बैच बनाएं' : 'Create Batch';
  String get batchName => isHindi ? 'बैच का नाम' : 'Batch Name';
  String get manageStudents => isHindi ? 'छात्र प्रबंधित करें' : 'Manage Students';

  // ── Backup & Restore ────────────────────────────────────────

  String get backup => isHindi ? 'बैकअप' : 'Backup';
  String get restore => isHindi ? 'रिस्टोर' : 'Restore';
  String get backupRestore => isHindi ? 'बैकअप और रिस्टोर' : 'Backup & Restore';

  // ── Audit Log ────────────────────────────────────────────────

  String get auditLog => isHindi ? 'ऑडिट लॉग' : 'Audit Log';
  String get analytics => isHindi ? 'विश्लेषण' : 'Analytics';

  // ── Messages ─────────────────────────────────────────────────

  String get savedSuccessfully => isHindi ? 'सफलतापूर्वक सहेजा गया' : 'Saved successfully';
  String get deletedSuccessfully => isHindi ? 'सफलतापूर्वक हटाया गया' : 'Deleted successfully';
  String get errorOccurred => isHindi ? 'त्रुटि हुई' : 'An error occurred';
  String get areYouSure => isHindi ? 'क्या आप निश्चित हैं?' : 'Are you sure?';
  String get noResultsFound => isHindi ? 'कोई परिणाम नहीं मिला' : 'No results found';
  String get pullToRefresh => isHindi ? 'रिफ्रेश के लिए खींचें' : 'Pull to refresh';
}

/// Delegate for Flutter's localization system.
class AppTranslationsDelegate extends LocalizationsDelegate<AppTranslations> {
  const AppTranslationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppTranslations> load(Locale locale) async {
    return AppTranslations(locale);
  }

  @override
  bool shouldReload(AppTranslationsDelegate old) => false;
}
