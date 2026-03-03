import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/attendance_model.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

final _sessionStart = DateTime(2026, 2, 23);
final _sessionEnd   = DateTime(2026, 5, 10);

class TeacherAttendanceTableScreen extends StatefulWidget {
  final SubjectModel subject;
  const TeacherAttendanceTableScreen({Key? key, required this.subject})
      : super(key: key);

  @override
  State<TeacherAttendanceTableScreen> createState() =>
      _TeacherAttendanceTableScreenState();
}

class _TeacherAttendanceTableScreenState
    extends State<TeacherAttendanceTableScreen> {
  final _db   = DatabaseService();
  final _auth = AuthService();

  late final List<DateTime> _dates;
  List<UserModel> _students = [];
  Map<String, Map<String, String?>>       _cellState    = {};
  Map<String, Map<String, AttendanceModel>> _savedRecords = {};

  String? _teacherId;
  bool _isLoading         = true;
  bool _isSaving          = false;
  bool _isExporting       = false;
  bool _hasUnsavedChanges = false;

  // ── Month / day label helpers ──────────────────────────────────────
  final _monthNames = ['','Jan','Feb','Mar','Apr','May','Jun',
                       'Jul','Aug','Sep','Oct','Nov','Dec'];
  final _dayNames   = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override
  void initState() {
    super.initState();
    _dates = _buildDateRange();
    _loadAll();
  }

  // ── Date helpers ───────────────────────────────────────────────────

  List<DateTime> _buildDateRange() {
    final List<DateTime> out = [];
    DateTime cur = _sessionStart;
    while (!cur.isAfter(_sessionEnd)) {
      out.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return out;
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

  bool _isPastOrToday(DateTime date) {
    final today = DateTime.now();
    return !DateTime(date.year, date.month, date.day)
        .isAfter(DateTime(today.year, today.month, today.day));
  }

  bool _isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  // ── Load ───────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    final user = await _auth.getCurrentUserData();
    _teacherId = user?.uid;

    // Fetch students
    final raw = await _db.getStudentsByClass(
      widget.subject.class_,
      widget.subject.section,
    );

    // Sort by roll number
    raw.sort((a, b) => (a.rollNo ?? '').compareTo(b.rollNo ?? ''));
    _students = raw;

    // Fetch attendance records
    _savedRecords = await _db.getAttendanceForSubjectClass(
      widget.subject.code,
      widget.subject.class_,
    );

    // Build cell state — null means no Firebase record (blank)
    _cellState = {};
    for (final s in _students) {
      final rn = s.rollNo!;
      _cellState[rn] = {};
      for (final d in _dates) {
        final k = _dateKey(d);
        _cellState[rn]![k] = _savedRecords[rn]?[k]?.status;
      }
    }

    setState(() {
      _isLoading = false;
      _hasUnsavedChanges = false;
    });
  }

  // ── Toggle ─────────────────────────────────────────────────────────

  void _toggleCell(String rollNo, String dateKey) {
    setState(() {
      _hasUnsavedChanges = true;
      final cur = _cellState[rollNo]?[dateKey];
      if (cur == null) {
        _cellState[rollNo]![dateKey] = 'present';
      } else if (cur == 'present') {
        _cellState[rollNo]![dateKey] = 'absent';
      } else {
        _cellState[rollNo]![dateKey] = null;
      }
    });
  }

  // ── Save ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_teacherId == null) return;
    setState(() => _isSaving = true);

    final List<AttendanceModel> toSave   = [];
    final List<String>          toDelete = [];

    for (final student in _students) {
      final rn = student.rollNo!;
      for (final date in _dates) {
        final key      = _dateKey(date);
        final state    = _cellState[rn]?[key];
        final existing = _savedRecords[rn]?[key];

        if (state == null) {
          if (_isPastOrToday(date) && _anyRecordOnDate(key)) {
            // Auto-absent only if class happened that day
            if (existing != null) {
              if (existing.status != 'absent')
                toSave.add(existing.copyWith(status: 'absent', markedBy: 'auto_absent'));
            } else {
              toSave.add(_newRecord(student, date, 'absent', 'auto_absent'));
            }
          } else if (existing != null && existing.id.isNotEmpty) {
            toDelete.add(existing.id);
          }
        } else {
          if (existing != null) {
            if (existing.status != state)
              toSave.add(existing.copyWith(status: state, markedBy: 'manual'));
          } else {
            toSave.add(_newRecord(student, date, state, 'manual'));
          }
        }
      }
    }

    for (final id in toDelete) {
      await _db.deleteAttendance(id);
    }

    bool ok = true;
    if (toSave.isNotEmpty) ok = await _db.saveAttendanceBatch(toSave);

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = !ok;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Attendance saved!' : '❌ Failed. Try again.'),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      if (ok) await _loadAll();
    }
  }

  bool _anyRecordOnDate(String dateKey) {
    for (final s in _students) {
      if (_savedRecords[s.rollNo!]?[dateKey] != null) return true;
      if (_cellState[s.rollNo!]?[dateKey] != null) return true;
    }
    return false;
  }

  AttendanceModel _newRecord(
      UserModel s, DateTime date, String status, String by) {
    return AttendanceModel(
      id: '',
      studentRollNo: s.rollNo!,
      studentName:   s.name,
      subjectCode:   widget.subject.code,
      subjectName:   widget.subject.name,
      teacherId:     _teacherId!,
      class_:        widget.subject.class_,
      dateTime:      DateTime(date.year, date.month, date.day, 9, 0),
      status:        status,
      markedBy:      by,
    );
  }

  // ── Summary ────────────────────────────────────────────────────────

  int _studentPresent(String rn) =>
      _cellState[rn]?.values.where((v) => v == 'present').length ?? 0;
  int _studentAbsent(String rn) =>
      _cellState[rn]?.values.where((v) => v == 'absent').length ?? 0;
  int _datePresent(String dk) =>
      _students.where((s) => _cellState[s.rollNo!]?[dk] == 'present').length;
  int _dateAbsent(String dk) =>
      _students.where((s) => _cellState[s.rollNo!]?[dk] == 'absent').length;

  // ── EXCEL EXPORT ───────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Attendance'];
      excel.delete('Sheet1');

      // Header style
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E65100'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        textWrapping: TextWrapping.WrapText,
      );
      final weekendStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#7B1FA2'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        textWrapping: TextWrapping.WrapText,
      );
      final presentStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
        fontColorHex: ExcelColor.fromHexString('#2E7D32'),
        bold: true,
      );
      final absentStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#FFEBEE'),
        fontColorHex: ExcelColor.fromHexString('#C62828'),
        bold: true,
      );
      final summaryStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
        fontColorHex: ExcelColor.fromHexString('#E65100'),
      );

      // Title rows
      sheet.merge(
          CellIndex.indexByString('A1'),
          CellIndex.indexByColumnRow(
              columnIndex: 3 + _dates.length, rowIndex: 0));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue(
          'Attendance Register — ${widget.subject.name} (${widget.subject.code})');
      titleCell.cellStyle = CellStyle(
          bold: true, fontSize: 14, horizontalAlign: HorizontalAlign.Center);

      sheet.merge(
          CellIndex.indexByString('A2'),
          CellIndex.indexByColumnRow(
              columnIndex: 3 + _dates.length, rowIndex: 1));
      final subCell = sheet.cell(CellIndex.indexByString('A2'));
      subCell.value = TextCellValue(
          'Class: ${widget.subject.class_}  |  Section: ${widget.subject.section}  |  Session: 23 Feb 2026 – 10 May 2026');
      subCell.cellStyle =
          CellStyle(horizontalAlign: HorizontalAlign.Center, italic: true);

      // Column headers — row 3 (index 2)
      final headers = ['#', 'Roll No', 'Student Name'];
      for (int i = 0; i < headers.length; i++) {
        final cell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }
      // Date headers
      for (int i = 0; i < _dates.length; i++) {
        final d    = _dates[i];
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 3 + i, rowIndex: 2));
        cell.value = TextCellValue(
            '${_dayNames[d.weekday]}\n${d.day} ${_monthNames[d.month]}');
        cell.cellStyle = _isWeekend(d) ? weekendStyle : headerStyle;
      }
      // P / A headers
      final pHdr = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: 3 + _dates.length, rowIndex: 2));
      pHdr.value = TextCellValue('Total P');
      pHdr.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#388E3C'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: HorizontalAlign.Center);

      final aHdr = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: 4 + _dates.length, rowIndex: 2));
      aHdr.value = TextCellValue('Total A');
      aHdr.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#C62828'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: HorizontalAlign.Center);

      // Student rows — starting row index 3
      for (int si = 0; si < _students.length; si++) {
        final s  = _students[si];
        final rn = s.rollNo!;
        final row = 3 + si;

        // Sr. No
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = IntCellValue(si + 1);

        // Roll No
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(rn);

        // Name — ✅ FIX: use s.name directly, wrap if long
        final nameCell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
        nameCell.value = TextCellValue(s.name);
        nameCell.cellStyle = CellStyle(textWrapping: TextWrapping.WrapText);

        // Attendance cells
        for (int di = 0; di < _dates.length; di++) {
          final dk    = _dateKey(_dates[di]);
          final state = _cellState[rn]?[dk];
          final cell  = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 3 + di, rowIndex: row));
          if (state == 'present') {
            cell.value = TextCellValue('P');
            cell.cellStyle = presentStyle;
          } else if (state == 'absent') {
            cell.value = TextCellValue('A');
            cell.cellStyle = absentStyle;
          } else {
            cell.value = TextCellValue('');
          }
        }

        // Totals
        final pCell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 3 + _dates.length, rowIndex: row));
        pCell.value = IntCellValue(_studentPresent(rn));
        pCell.cellStyle = summaryStyle;

        final aCell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 4 + _dates.length, rowIndex: row));
        aCell.value = IntCellValue(_studentAbsent(rn));
        aCell.cellStyle = summaryStyle;
      }

      // Summary rows at bottom
      final presRow = 3 + _students.length;
      final absRow  = 4 + _students.length;

      final presLabel = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: presRow));
      presLabel.value = TextCellValue('Total Present');
      presLabel.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
          fontColorHex: ExcelColor.fromHexString('#2E7D32'));

      final absLabel = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: absRow));
      absLabel.value = TextCellValue('Total Absent');
      absLabel.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#FFEBEE'),
          fontColorHex: ExcelColor.fromHexString('#C62828'));

      for (int di = 0; di < _dates.length; di++) {
        final dk = _dateKey(_dates[di]);
        final pc = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 3 + di, rowIndex: presRow));
        final ac = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 3 + di, rowIndex: absRow));
        final p = _datePresent(dk);
        final a = _dateAbsent(dk);
        pc.value = p == 0 ? TextCellValue('') : IntCellValue(p);
        ac.value = a == 0 ? TextCellValue('') : IntCellValue(a);
        pc.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
            fontColorHex: ExcelColor.fromHexString('#2E7D32'),
            bold: true);
        ac.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: ExcelColor.fromHexString('#FFEBEE'),
            fontColorHex: ExcelColor.fromHexString('#C62828'),
            bold: true);
      }

      // Column widths
      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 12);
      sheet.setColumnWidth(2, 22);
      for (int i = 0; i < _dates.length; i++) {
        sheet.setColumnWidth(3 + i, 7);
      }
      sheet.setColumnWidth(3 + _dates.length, 10);
      sheet.setColumnWidth(4 + _dates.length, 10);

      // Save & share
      final bytes = excel.encode()!;
      final dir   = await getTemporaryDirectory();
      final file  = File(
          '${dir.path}/Attendance_${widget.subject.code}_${widget.subject.class_}.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject:
            'Attendance — ${widget.subject.name} (${widget.subject.class_})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Export failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _isExporting = false);
  }

  // ── PDF EXPORT ─────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final pdf = pw.Document();

      // Split dates into chunks of 20 per page (landscape fits ~20 dates)
      const int chunkSize = 20;
      final List<List<DateTime>> chunks = [];
      for (int i = 0; i < _dates.length; i += chunkSize) {
        chunks.add(_dates.sublist(
            i, i + chunkSize > _dates.length ? _dates.length : i + chunkSize));
      }

      for (int ci = 0; ci < chunks.length; ci++) {
        final chunk = chunks[ci];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(16),
            build: (ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Title
                  pw.Text(
                    'Attendance Register — ${widget.subject.name} (${widget.subject.code})',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Class: ${widget.subject.class_}  |  Section: ${widget.subject.section}  |  Session: 23 Feb 2026 – 10 May 2026  |  Page ${ci + 1}/${chunks.length}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 8),

                  // Table
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey400, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(22),  // #
                      1: const pw.FixedColumnWidth(48),  // Roll
                      2: const pw.FixedColumnWidth(90),  // Name
                      for (int i = 0; i < chunk.length; i++)
                        3 + i: const pw.FixedColumnWidth(22), // dates
                      3 + chunk.length:
                          const pw.FixedColumnWidth(24), // P total
                      4 + chunk.length:
                          const pw.FixedColumnWidth(24), // A total
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.deepOrange700),
                        children: [
                          _pdfHeaderCell('#'),
                          _pdfHeaderCell('Roll No'),
                          _pdfHeaderCell('Student Name'),
                          ...chunk.map((d) => _pdfHeaderCell(
                              '${_dayNames[d.weekday]}\n${d.day} ${_monthNames[d.month]}',
                              isWeekend: _isWeekend(d))),
                          _pdfHeaderCell('P', color: PdfColors.green800),
                          _pdfHeaderCell('A', color: PdfColors.red800),
                        ],
                      ),
                      // Student rows
                      ..._students.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final s   = entry.value;
                        final rn  = s.rollNo!;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: idx.isOdd
                                ? PdfColors.grey100
                                : PdfColors.white,
                          ),
                          children: [
                            _pdfCell('${idx + 1}', center: true),
                            _pdfCell(rn, center: true),
                            _pdfCell(s.name), // ✅ student name
                            ...chunk.map((d) {
                              final state = _cellState[rn]?[_dateKey(d)];
                              return _pdfAttendanceCell(state);
                            }),
                            _pdfCell('${_studentPresent(rn)}',
                                center: true,
                                color: PdfColors.green800,
                                bold: true),
                            _pdfCell('${_studentAbsent(rn)}',
                                center: true,
                                color: PdfColors.red800,
                                bold: true),
                          ],
                        );
                      }),
                      // Summary rows
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.green50),
                        children: [
                          _pdfCell('', center: true),
                          _pdfCell('', center: true),
                          _pdfCell('Total Present',
                              bold: true, color: PdfColors.green800),
                          ...chunk.map((d) {
                            final c = _datePresent(_dateKey(d));
                            return _pdfCell(c == 0 ? '—' : '$c',
                                center: true,
                                color: c == 0
                                    ? PdfColors.grey400
                                    : PdfColors.green800,
                                bold: true);
                          }),
                          _pdfCell('', center: true),
                          _pdfCell('', center: true),
                        ],
                      ),
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.red50),
                        children: [
                          _pdfCell('', center: true),
                          _pdfCell('', center: true),
                          _pdfCell('Total Absent',
                              bold: true, color: PdfColors.red800),
                          ...chunk.map((d) {
                            final c = _dateAbsent(_dateKey(d));
                            return _pdfCell(c == 0 ? '—' : '$c',
                                center: true,
                                color: c == 0
                                    ? PdfColors.grey400
                                    : PdfColors.red800,
                                bold: true);
                          }),
                          _pdfCell('', center: true),
                          _pdfCell('', center: true),
                        ],
                      ),
                    ],
                  ),

                  pw.Spacer(),
                  pw.Divider(color: PdfColors.grey400),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          'Exported on: ${DateTime.now().day} ${_monthNames[DateTime.now().month]} ${DateTime.now().year}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Teacher: ${widget.subject.teacherName}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('NIT Nagpur — CSE Dept.',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      final dir   = await getTemporaryDirectory();
      final file  = File(
          '${dir.path}/Attendance_${widget.subject.code}_${widget.subject.class_}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject:
            'Attendance PDF — ${widget.subject.name} (${widget.subject.class_})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ PDF export failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _isExporting = false);
  }

  // ── PDF cell helpers ───────────────────────────────────────────────

  pw.Widget _pdfHeaderCell(String text,
      {bool isWeekend = false, PdfColor color = PdfColors.white}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      color: isWeekend ? PdfColors.purple700 : null,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: color),
      ),
    );
  }

  pw.Widget _pdfCell(String text,
      {bool center = false,
      bool bold = false,
      PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
            fontSize: 7,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color),
      ),
    );
  }

  pw.Widget _pdfAttendanceCell(String? state) {
    String label;
    PdfColor fg;
    PdfColor bg;

    if (state == 'present') {
      label = 'P';
      fg = PdfColors.green800;
      bg = PdfColors.green50;
    } else if (state == 'absent') {
      label = 'A';
      fg = PdfColors.red800;
      bg = PdfColors.red50;
    } else {
      label = '';
      fg = PdfColors.grey400;
      bg = PdfColors.white;
    }

    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(label,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: fg)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subject.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${widget.subject.class_}  •  Sec ${widget.subject.section}',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_hasUnsavedChanges)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded,
                        color: Colors.white, size: 20),
                    label: const Text('Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? _buildNoStudents()
              : Column(
                  children: [
                    Expanded(child: _buildTable()),
                    _buildExportBar(),
                  ],
                ),
    );
  }

  // ── Export bottom bar ──────────────────────────────────────────────

  Widget _buildExportBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.download_rounded,
              size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Export:',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black54)),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportExcel,
              icon: const Icon(Icons.table_chart_rounded, size: 18),
              label: const Text('Excel (.xlsx)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_isExporting) ...[
            const SizedBox(width: 12),
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ]
        ],
      ),
    );
  }

  Widget _buildNoStudents() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No students found for ${widget.subject.class_}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          TextButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────

  Widget _buildTable() {
    const double rollColW    = 50.0;
    const double nameColW    = 130.0;
    const double dateColW    = 46.0;
    const double summaryColW = 42.0;
    const double rowH        = 52.0; // taller to allow name wrap
    const double headerH     = 66.0;

    Color dateBg(DateTime d) => _isWeekend(d)
        ? Colors.purple.shade100
        : Colors.orange.shade50;
    Color dateFg(DateTime d) => _isWeekend(d)
        ? Colors.purple.shade800
        : Colors.orange.shade900;

    return Column(
      children: [
        // Legend
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _legendItem(Icons.check_circle_rounded,
                  Colors.green.shade600, 'Present'),
              const SizedBox(width: 14),
              _legendItem(
                  Icons.cancel_rounded, Colors.red.shade500, 'Absent'),
              const SizedBox(width: 14),
              _legendItem(Icons.radio_button_unchecked,
                  Colors.grey.shade400, 'Blank'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6)),
                child: Text('🟣 Weekend',
                    style: TextStyle(
                        fontSize: 11, color: Colors.purple.shade700)),
              ),
            ],
          ),
        ),

        if (_hasUnsavedChanges)
          Container(
            width: double.infinity,
            color: Colors.orange.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Text('Unsaved changes — tap Save to confirm.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),

        const SizedBox(height: 2),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const ClampingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── FROZEN LEFT: Roll + Name ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _cell('#', rollColW, headerH,
                          bg: Colors.orange.shade700,
                          fg: Colors.white,
                          bold: true,
                          fontSize: 12),
                      _cell('Student Name', nameColW, headerH,
                          bg: Colors.orange.shade700,
                          fg: Colors.white,
                          bold: true,
                          fontSize: 12),
                    ]),
                    // ✅ FIX: use s.name directly, with text wrapping
                    ..._students.map((s) => Row(children: [
                          _cell(s.rollNo ?? '-', rollColW, rowH,
                              bg: Colors.grey.shade50,
                              fg: Colors.blueGrey.shade600,
                              bold: true,
                              fontSize: 10),
                          _nameCell(s.name, nameColW, rowH),
                        ])),
                    Row(children: [
                      _cell('', rollColW, rowH,
                          bg: Colors.green.shade50, fg: Colors.transparent),
                      _cell('Total Present', nameColW, rowH,
                          bg: Colors.green.shade50,
                          fg: Colors.green.shade800,
                          bold: true,
                          fontSize: 11,
                          align: TextAlign.left),
                    ]),
                    Row(children: [
                      _cell('', rollColW, rowH,
                          bg: Colors.red.shade50, fg: Colors.transparent),
                      _cell('Total Absent', nameColW, rowH,
                          bg: Colors.red.shade50,
                          fg: Colors.red.shade800,
                          bold: true,
                          fontSize: 11,
                          align: TextAlign.left),
                    ]),
                  ],
                ),

                // ── SCROLLABLE DATES ──
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: _dates.map((d) => _cell(
                            '${_dayNames[d.weekday]}\n${d.day} ${_monthNames[d.month]}',
                            dateColW, headerH,
                            bg: dateBg(d),
                            fg: dateFg(d),
                            bold: true,
                            fontSize: 9,
                          )).toList(),
                        ),
                        ..._students.map((student) {
                          final rn = student.rollNo!;
                          return Row(
                            children: _dates.map((d) {
                              final key   = _dateKey(d);
                              final state = _cellState[rn]?[key];
                              return _attendanceCell(
                                state: state,
                                onTap: () => _toggleCell(rn, key),
                                width: dateColW,
                                height: rowH,
                              );
                            }).toList(),
                          );
                        }),
                        Row(
                          children: _dates.map((d) {
                            final c = _datePresent(_dateKey(d));
                            return _cell(c == 0 ? '—' : '$c',
                                dateColW, rowH,
                                bg: Colors.green.shade50,
                                fg: c == 0 ? Colors.grey.shade300 : Colors.green.shade800,
                                bold: true, fontSize: 11);
                          }).toList(),
                        ),
                        Row(
                          children: _dates.map((d) {
                            final c = _dateAbsent(_dateKey(d));
                            return _cell(c == 0 ? '—' : '$c',
                                dateColW, rowH,
                                bg: Colors.red.shade50,
                                fg: c == 0 ? Colors.grey.shade300 : Colors.red.shade800,
                                bold: true, fontSize: 11);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── FROZEN RIGHT: P / A ──
                Column(
                  children: [
                    Row(children: [
                      _cell('P', summaryColW, headerH,
                          bg: Colors.green.shade700, fg: Colors.white,
                          bold: true, fontSize: 13),
                      _cell('A', summaryColW, headerH,
                          bg: Colors.red.shade700, fg: Colors.white,
                          bold: true, fontSize: 13),
                    ]),
                    ..._students.map((s) {
                      final p = _studentPresent(s.rollNo!);
                      final a = _studentAbsent(s.rollNo!);
                      return Row(children: [
                        _cell('$p', summaryColW, rowH,
                            bg: Colors.green.shade50,
                            fg: Colors.green.shade800, bold: true),
                        _cell('$a', summaryColW, rowH,
                            bg: Colors.red.shade50,
                            fg: Colors.red.shade800, bold: true),
                      ]);
                    }),
                    Row(children: [
                      _cell(
                        '${_students.fold(0, (s, st) => s + _studentPresent(st.rollNo!))}',
                        summaryColW, rowH,
                        bg: Colors.green.shade200,
                        fg: Colors.green.shade900, bold: true, fontSize: 12),
                      _cell(
                        '${_students.fold(0, (s, st) => s + _studentAbsent(st.rollNo!))}',
                        summaryColW, rowH,
                        bg: Colors.red.shade200,
                        fg: Colors.red.shade900, bold: true, fontSize: 12),
                    ]),
                    Row(children: [
                      _cell('', summaryColW, rowH,
                          bg: Colors.grey.shade100, fg: Colors.transparent),
                      _cell('', summaryColW, rowH,
                          bg: Colors.grey.shade100, fg: Colors.transparent),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _cell(String text, double w, double h,
      {required Color bg,
      required Color fg,
      bool bold = false,
      double fontSize = 12,
      TextAlign align = TextAlign.center}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: Colors.grey.shade200, width: 0.5)),
      alignment:
          align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      padding: EdgeInsets.symmetric(
          horizontal: align == TextAlign.left ? 8 : 3, vertical: 4),
      child: Text(text,
          textAlign: align,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: fg)),
    );
  }

  // ✅ FIX: name cell uses softWrap + overflow visible so long names wrap
  Widget _nameCell(String name, double w, double h) {
    return Container(
      width: w,
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200, width: 0.5)),
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        softWrap: true,       // ✅ allow wrapping
        overflow: TextOverflow.visible, // ✅ don't clip
        maxLines: 2,          // max 2 lines
      ),
    );
  }

  Widget _attendanceCell(
      {required String? state,
      required VoidCallback onTap,
      required double width,
      required double height}) {
    Widget icon;
    Color bg;
    if (state == 'present') {
      icon = Icon(Icons.check_circle_rounded,
          color: Colors.green.shade600, size: 22);
      bg = Colors.green.shade50;
    } else if (state == 'absent') {
      icon =
          Icon(Icons.cancel_rounded, color: Colors.red.shade500, size: 22);
      bg = Colors.red.shade50;
    } else {
      icon = Icon(Icons.radio_button_unchecked,
          color: Colors.grey.shade300, size: 18);
      bg = Colors.white;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: Colors.grey.shade200, width: 0.5)),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}