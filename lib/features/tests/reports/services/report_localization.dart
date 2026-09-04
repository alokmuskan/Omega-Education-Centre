/// Report Localization Helper
///
/// Provides bilingual (English/Hindi) text for report card generation.
/// Used by PDF generators to produce multi-language report cards.
class ReportLocalization {
  final String language; // 'en' or 'hi'

  ReportLocalization({this.language = 'en'});

  bool get isHindi => language == 'hi';

  // ══════════════════════════════════════════════════════════════════════
  // REPORT CARD TITLES
  // ══════════════════════════════════════════════════════════════════════

  String get reportCardTitle => isHindi ? 'छात्र परीक्षा प्रतिवेदन पत्र' : 'STUDENT EXAMINATION REPORT CARD';
  String get classResultTitle => isHindi ? 'परीक्षा कक्षा परिणाम पत्र' : 'EXAMINATION CLASS RESULT SHEET';
  String get academicYearLabel => isHindi ? 'शैक्षणिक वर्ष' : 'Academic Year';
  String get officialRecord => isHindi ? 'ओमेगा शिक्षा केंद्र — आधिकारिक नोटिस बोर्ड परिणाम' : 'OMEGA EDUCATION CENTRE — Official Notice Board Result Record';

  // ══════════════════════════════════════════════════════════════════════
  // STUDENT INFORMATION
  // ══════════════════════════════════════════════════════════════════════

  String get studentInfo => isHindi ? 'छात्र जानकारी' : 'STUDENT INFORMATION';
  String get studentName => isHindi ? 'छात्र का नाम' : 'Student Name';
  String get rollNumber => isHindi ? 'रोल नंबर' : 'Roll Number';
  String get classBoard => isHindi ? 'कक्षा और बोर्ड' : 'Class & Board';
  String get fatherName => isHindi ? 'पिता का नाम' : "Father's Name";
  String get contactNumber => isHindi ? 'संपर्क नंबर' : 'Contact Number';

  // ══════════════════════════════════════════════════════════════════════
  // EXAMINATION DETAILS
  // ══════════════════════════════════════════════════════════════════════

  String get examInfo => isHindi ? 'परीक्षा विवरण' : 'EXAMINATION DETAILS';
  String get testName => isHindi ? 'परीक्षा का नाम' : 'Test Name';
  String get testType => isHindi ? 'परीक्षा का प्रकार' : 'Test Type';
  String get testDate => isHindi ? 'परीक्षा तिथि' : 'Test Date';
  String get subjects => isHindi ? 'विषय' : 'SUBJECTS';

  // ══════════════════════════════════════════════════════════════════════
  // RESULTS
  // ══════════════════════════════════════════════════════════════════════

  String get obtained => isHindi ? 'प्राप्त' : 'Obtained';
  String get maximum => isHindi ? 'अधिकतम' : 'Maximum';
  String get percentage => isHindi ? 'प्रतिशत' : 'Percentage';
  String get grade => isHindi ? 'ग्रेड' : 'Grade';
  String get result => isHindi ? 'परिणाम' : 'Result';
  String get total => isHindi ? 'कुल' : 'Total';
  String get rank => isHindi ? 'रैंक' : 'Rank';
  String get pass => isHindi ? 'उत्तीर्ण' : 'Pass';
  String get fail => isHindi ? 'अनुत्तीर्ण' : 'Fail';
  String get distinction => isHindi ? 'विशिष्ट' : 'Distinction';
  String get firstDivision => isHindi ? 'प्रथम श्रेणी' : 'First Division';
  String get secondDivision => isHindi ? 'द्वितीय श्रेणी' : 'Second Division';
  String get thirdDivision => isHindi ? 'तृतीय श्रेणी' : 'Third Division';

  // ══════════════════════════════════════════════════════════════════════
  // ATTENDANCE
  // ══════════════════════════════════════════════════════════════════════

  String get attendanceSummary => isHindi ? 'उपस्थिति सारांश' : 'ATTENDANCE SUMMARY';
  String get totalDays => isHindi ? 'कुल दिन' : 'Total Days';
  String get presentDays => isHindi ? 'उपस्थित दिन' : 'Present Days';
  String get absentDays => isHindi ? 'अनुपस्थित दिन' : 'Absent Days';
  String get attendancePercentage => isHindi ? 'उपस्थिति प्रतिशत' : 'Attendance %';

  // ══════════════════════════════════════════════════════════════════════
  // REMARKS & SIGNATURES
  // ══════════════════════════════════════════════════════════════════════

  String get remarks => isHindi ? 'टिप्पणियाँ' : 'Remarks';
  String get classTeacherSignature => isHindi ? 'कक्षा शिक्षक के हस्ताक्षर' : "Class Teacher's Signature";
  String get parentSignature => isHindi ? 'अभिभावक के हस्ताक्षर' : "Parent's Signature";
  String get principalSignature => isHindi ? 'प्रधानाचार्य के हस्ताक्षर' : "Principal's Signature";
  String get date => isHindi ? 'तिथि' : 'Date';
  String get stamp => isHindi ? 'मुहर' : 'Stamp';

  // ══════════════════════════════════════════════════════════════════════
  // CLASS RESULT SHEET HEADERS
  // ══════════════════════════════════════════════════════════════════════

  String get rankHeader => isHindi ? 'रैंक' : 'Rank';
  String get rollNoHeader => isHindi ? 'रोल नं.' : 'Roll No';
  String get studentNameHeader => isHindi ? 'छात्र का नाम' : 'Student Name';
  String get totalHeader => isHindi ? 'कुल' : 'Total';
  String get maxHeader => isHindi ? 'अधिकतम' : 'Max';
  String get percentHeader => isHindi ? 'प्रतिशत' : 'Percent';
  String get gradeHeader => isHindi ? 'ग्रेड' : 'Grade';
  String get resultHeader => isHindi ? 'परिणाम' : 'Result';

  // ══════════════════════════════════════════════════════════════════════
  // UTILITY
  // ══════════════════════════════════════════════════════════════════════

  /// Get localized text based on language
  String localize({required String english, required String hindi}) {
    return isHindi ? hindi : english;
  }

  /// Factory constructor for English
  factory ReportLocalization.english() => ReportLocalization(language: 'en');

  /// Factory constructor for Hindi
  factory ReportLocalization.hindi() => ReportLocalization(language: 'hi');

  /// Factory from locale string
  factory ReportLocalization.fromLocale(String locale) {
    return ReportLocalization(language: locale == 'hi' ? 'hi' : 'en');
  }
}
