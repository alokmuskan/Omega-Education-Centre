import 'package:archive/archive.dart';

import '../../../attendance/models/attendance_summary_model.dart';
import '../../models/student_test_summary_model.dart';
import '../models/result_export_data.dart';

/// Service for generating genuine, editable Microsoft Word (.docx) files using OpenXML zip format.
class DocxGeneratorService {
  DocxGeneratorService._();

  /// Generates editable Microsoft Word (.docx) bytes for Class-wise Results.
  static List<int> generateClassResultDocx(ClassResultExportData data) {
    final buffer = StringBuffer();

    // Document Header
    buffer.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>OMEGA EDUCATION CENTRE</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t>EXAMINATION CLASS RESULT SHEET</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:t>Test: ${xmlEscape(data.test.title)} | Type: ${xmlEscape(data.test.testType)} | Class: ${xmlEscape(data.test.studentClass)} (${xmlEscape(data.test.board)}) | Date: ${xmlEscape(data.test.testDate)} | Year: ${xmlEscape(data.academicYear)}</w:t></w:r>
    </w:p>
    <w:p/>
''');

    // Table Header Row
    buffer.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <w:trPr><w:tblHeader/></w:trPr>
        ${_tableHeaderCell("Rank")}
        ${_tableHeaderCell("Roll")}
        ${_tableHeaderCell("Student Name")}
''');

    for (final subj in data.subjects) {
      buffer.write(_tableHeaderCell("${subj.subjectName} (${subj.maxMarks.toStringAsFixed(0)})"));
    }

    buffer.write('''
        ${_tableHeaderCell("Total")}
        ${_tableHeaderCell("Max")}
        ${_tableHeaderCell("Pct")}
        ${_tableHeaderCell("Grade")}
        ${_tableHeaderCell("Result")}
      </w:tr>
''');

    // Table Data Rows
    for (final s in data.studentSummaries) {
      buffer.write('<w:tr>');
      buffer.write(_tableCell(s.rank > 0 ? '#${s.rank}' : 'N/A'));
      buffer.write(_tableCell(s.studentRollNo.isNotEmpty ? s.studentRollNo : '-'));
      buffer.write(_tableCell(s.studentName));

      for (final subj in data.subjects) {
        final resList = s.subjectResults.where((r) => r.testSubjectId == subj.id);
        if (resList.isNotEmpty) {
          buffer.write(_tableCell(resList.first.marksObtained.toStringAsFixed(0)));
        } else {
          buffer.write(_tableCell('-'));
        }
      }

      buffer.write(_tableCell(s.totalObtained.toStringAsFixed(0)));
      buffer.write(_tableCell(s.totalMax.toStringAsFixed(0)));
      buffer.write(_tableCell(s.isComplete ? '${s.percentage.toStringAsFixed(1)}%' : 'N/A'));
      buffer.write(_tableCell(s.grade));
      buffer.write(_tableCell(s.overallStatus));
      buffer.write('</w:tr>');
    }

    buffer.write('</w:tbl>');

    // Statistics Block
    buffer.write('''
    <w:p/><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>CLASS PERFORMANCE STATISTICS</w:t></w:r></w:p>
    <w:p><w:r><w:t>Total Students: ${data.totalStudents} | Completed: ${data.completedCount} | Incomplete: ${data.incompleteCount}</w:t></w:r></w:p>
    <w:p><w:r><w:t>Passed: ${data.passCount} | Failed: ${data.failCount} | Class Average: ${data.classAvgPct}%</w:t></w:r></w:p>
    <w:p><w:r><w:t>Highest Percentage: ${data.highestPct}% | Lowest Percentage: ${data.lowestPct}%</w:t></w:r></w:p>
    <w:sectPr>
      <w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>
    </w:sectPr>
  </w:body>
</w:document>
''');

    return _packageOpenXmlZip(buffer.toString());
  }

  /// Generates editable Microsoft Word (.docx) bytes for an Individual Student Report Card.
  static List<int> generateStudentReportCardDocx(
    StudentTestSummaryModel summary, {
    StudentAttendanceSummary? attendanceSummary,
    String? attendanceMonthLabel,
  }) {
    final buffer = StringBuffer();
    final monthText = attendanceMonthLabel ?? 'Selected Month';
    final hasAttendance = attendanceSummary != null && attendanceSummary.totalRecordedDays > 0;

    buffer.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>OMEGA EDUCATION CENTRE</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t>STUDENT EXAMINATION REPORT CARD</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/><w:rPr><w:sz w:val="20"/></w:rPr></w:pPr>
      <w:r><w:t>Academic Year ${xmlEscape(summary.academicYear)}</w:t></w:r>
    </w:p>
    <w:p/>

    <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>STUDENT INFORMATION</w:t></w:r></w:p>
    <w:p><w:r><w:t>Student Name: ${xmlEscape(summary.studentName)}</w:t></w:r></w:p>
    <w:p><w:r><w:t>Roll Number: ${xmlEscape(summary.studentRollNo.isNotEmpty ? summary.studentRollNo : 'N/A')} | Class &amp; Board: ${xmlEscape(summary.studentClass)} (${xmlEscape(summary.board)})</w:t></w:r></w:p>
    <w:p/>

    <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>EXAMINATION INFORMATION</w:t></w:r></w:p>
    <w:p><w:r><w:t>Examination: ${xmlEscape(summary.testTitle)} | Test Type: ${xmlEscape(summary.testType)} | Date: ${xmlEscape(summary.testDate)}</w:t></w:r></w:p>
    <w:p/>

    <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>SUBJECT-WISE PERFORMANCE</w:t></w:r></w:p>
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <w:trPr><w:tblHeader/></w:trPr>
        ${_tableHeaderCell("Subject Name")}
        ${_tableHeaderCell("Obtained")}
        ${_tableHeaderCell("Max Marks")}
        ${_tableHeaderCell("Pass Marks")}
        ${_tableHeaderCell("Percentage")}
        ${_tableHeaderCell("Status")}
      </w:tr>
''');

    for (final subj in summary.configuredSubjects) {
      final resList = summary.subjectResults.where((r) => r.testSubjectId == subj.id);
      final isRecorded = resList.isNotEmpty;
      final marks = isRecorded ? resList.first.marksObtained : null;
      final isPass = marks != null && marks >= subj.passMarks;

      buffer.write('<w:tr>');
      buffer.write(_tableCell(subj.subjectName));
      buffer.write(_tableCell(marks != null ? marks.toStringAsFixed(0) : '-'));
      buffer.write(_tableCell(subj.maxMarks.toStringAsFixed(0)));
      buffer.write(_tableCell(subj.passMarks.toStringAsFixed(0)));
      buffer.write(_tableCell(marks != null ? '${((marks / subj.maxMarks) * 100).toStringAsFixed(1)}%' : '-'));
      buffer.write(_tableCell(!isRecorded ? 'Pending' : isPass ? 'Pass' : 'Fail'));
      buffer.write('</w:tr>');
    }

    buffer.write('''
    </w:tbl>
    <w:p/>

    <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>MONTHLY ATTENDANCE REPORT (Attendance Month: ${xmlEscape(monthText)})</w:t></w:r></w:p>
''');

    if (hasAttendance) {
      buffer.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tr>
        <w:trPr><w:tblHeader/></w:trPr>
        ${_tableHeaderCell("Classes Conducted")}
        ${_tableHeaderCell("Present")}
        ${_tableHeaderCell("Absent")}
        ${_tableHeaderCell("Attendance %")}
      </w:tr>
      <w:tr>
        ${_tableCell(attendanceSummary.totalRecordedDays.toString())}
        ${_tableCell((attendanceSummary.presentCount + attendanceSummary.lateCount).toString())}
        ${_tableCell(attendanceSummary.absentCount.toString())}
        ${_tableCell("${attendanceSummary.percentage.toStringAsFixed(2)}%")}
      </w:tr>
    </w:tbl>
''');
    } else {
      buffer.write('<w:p><w:r><w:t>No attendance records available</w:t></w:r></w:p>');
    }

    buffer.write('''
    <w:p/>

    <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>OVERALL PERFORMANCE SUMMARY</w:t></w:r></w:p>
    <w:p><w:r><w:t>Total Marks: ${summary.totalObtained.toStringAsFixed(0)} / ${summary.totalMax.toStringAsFixed(0)}</w:t></w:r></w:p>
    <w:p><w:r><w:t>Percentage: ${summary.isComplete ? '${summary.percentage.toStringAsFixed(2)}%' : 'N/A'} | Grade: ${summary.grade}</w:t></w:r></w:p>
    <w:p><w:r><w:t>Overall Result: ${summary.overallStatus} | Class Rank: ${summary.rank > 0 ? 'Rank ${summary.rank}' : 'N/A'}</w:t></w:r></w:p>
    <w:p/>

    <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>SIGNATURES &amp; REMARKS</w:t></w:r></w:p>
    <w:p><w:r><w:t>Teacher Remarks: _____________________________________________</w:t></w:r></w:p>
    <w:p/><w:p/>
    <w:p><w:r><w:t>Parent Signature: _______________   Teacher Signature: _______________   Director Signature: _______________</w:t></w:r></w:p>
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
    </w:sectPr>
  </w:body>
</w:document>
''');

    return _packageOpenXmlZip(buffer.toString());
  }

  static String _tableHeaderCell(String text) {
    return '''
      <w:tc>
        <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E0E0E0"/></w:tcPr>
        <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>${xmlEscape(text)}</w:t></w:r></w:p>
      </w:tc>
    ''';
  }

  static String _tableCell(String text) {
    return '''
      <w:tc>
        <w:p><w:r><w:t>${xmlEscape(text)}</w:t></w:r></w:p>
      </w:tc>
    ''';
  }

  static String xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static List<int> _packageOpenXmlZip(String documentXmlContent) {
    final archive = Archive();

    // 1. [Content_Types].xml
    archive.addFile(ArchiveFile.string(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>',
    ));

    // 2. _rels/.rels
    archive.addFile(ArchiveFile.string(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>',
    ));

    // 3. word/document.xml
    archive.addFile(ArchiveFile.string('word/document.xml', documentXmlContent));

    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive) ?? [];
  }
}
