import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const AttendanceApp());
}

Future<File> _scheduleFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/schedule.pdf');
}

Future<File> _studentListFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/student_list.xlsx');
}

Future<Uint8List> _loadStudentBytes() async {
  // Prefer stored student list; fallback to bundled asset.
  final stored = await _studentListFile();
  if (await stored.exists()) {
    return await stored.readAsBytes();
  }
  try {
    final data = await rootBundle.load('database/class_list.xlsx');
    return data.buffer.asUint8List();
  } catch (_) {
    throw Exception('No student list found. Please upload an .xlsx via Update Files.');
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<File?> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _loadStoredSchedule();
  }

  Future<File?> _loadStoredSchedule() async {
    final file = await _scheduleFile();
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: FutureBuilder<File?>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Could not load schedule.\n${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _pdfFuture = _loadStoredSchedule();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final file = snapshot.data;
          if (file == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No schedule uploaded yet',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return PDFView(
            filePath: file.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: true,
            pageFling: true,
          );
        },
      ),
    );
  }
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeTile(
              label: 'Attendance',
              description: "Tap to start marking today's class",
              icon: Icons.fact_check,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AttendanceSetupScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeTile(
              label: 'Student Contacts',
              description: 'Quickly look up roll, admission, and phone',
              icon: Icons.contacts,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudentContactsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeTile(
              label: 'Schedule',
              description: 'View saved class schedule (PDF)',
              icon: Icons.schedule,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScheduleScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeTile(
              label: 'Update Files',
              description: 'Replace schedule PDF or student list',
              icon: Icons.upload_file,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UpdateFilesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class AttendanceSetupScreen extends StatefulWidget {
  const AttendanceSetupScreen({super.key});

  @override
  State<AttendanceSetupScreen> createState() => _AttendanceSetupScreenState();
}

class _AttendanceSetupScreenState extends State<AttendanceSetupScreen> {
  final TextEditingController _subjectController = TextEditingController();
  TimeOfDay? _classStart;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _classStart ?? now,
    );
    if (picked != null) {
      setState(() => _classStart = picked);
    }
  }

  bool get _canStart =>
      _subjectController.text.trim().isNotEmpty && _classStart != null;

  void _start() {
    if (!_canStart) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceMarkingScreen(
          subjectName: _subjectController.text.trim(),
          classStartTime: _classStart!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _classStart == null
                          ? 'Pick class start time'
                          : 'Starts at ${_classStart!.format(context)}',
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canStart ? _start : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Start Attendance'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceMarkingScreen extends StatefulWidget {
  const AttendanceMarkingScreen({
    super.key,
    required this.subjectName,
    required this.classStartTime,
  });

  final String subjectName;
  final TimeOfDay classStartTime;

  @override
  State<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  late Future<List<Student>> _studentsFuture;
  final Map<String, bool> _presence = {};

  @override
  void initState() {
    super.initState();
    _studentsFuture = _loadStudents();
  }

  Future<List<Student>> _loadStudents() async {
    final excelBytes = await _loadStudentBytes();
    final excel = Excel.decodeBytes(excelBytes);

    if (excel.tables.isEmpty) {
      throw Exception('No sheets found in Excel');
    }
    final sheet = excel.tables.values.first;
    final students = <Student>[];

    for (var i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      // Skip the header row (S.No, Roll Number, Name, SBU Admission Number)
      if (i == 0) continue;

      final serialCell = row.isNotEmpty ? row[0] : null;
      final rollCell = row.length > 1 ? row[1] : null;
      final nameCell = row.length > 2 ? row[2] : null;
      final admissionCell = row.length > 3 ? row[3] : null;

      final serial = _cellToString(serialCell);
      final roll = _cellToString(rollCell);
      final name = _cellToString(nameCell);
      final admission = _cellToString(admissionCell);

      if (serial.isEmpty && roll.isEmpty && name.isEmpty && admission.isEmpty) {
        continue;
      }

      final student = Student(
        serialNumber: serial,
        rollNumber: roll,
        name: name,
        admissionNumber: admission,
      );
      students.add(student);
      _presence[student.rollNumber] = false;
    }

    if (students.isEmpty) {
      throw Exception('No student data found. Ensure the Excel has Roll and Name in the first two columns.');
    }

    return students;
  }

  static String _cellToString(Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    return value.toString().trim();
  }

  void _togglePresence(String roll) {
    setState(() {
      _presence[roll] = !(_presence[roll] ?? false);
    });
  }

  Future<void> _exportPdf(List<Student> students) async {
    final startDateTime = _timeOfDayToDateTime(widget.classStartTime);
    final dateStr = DateFormat('yMMMd').format(startDateTime);
    final timeStr = DateFormat('h:mm a').format(startDateTime);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Subject: ${widget.subjectName}'),
            pw.Text('Date: $dateStr'),
            pw.Text('Class start: $timeStr'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const ['S.No', 'Roll Number', 'Name', 'SBU Admission Number', 'Status'],
              data: students
                  .map(
                    (s) => [
                      s.serialNumber,
                      s.rollNumber,
                      s.name,
                      s.admissionNumber,
                      _presence[s.rollNumber] == true ? 'Present' : 'Absent',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 32),
            pw.Text('Teacher signature:'),
            pw.SizedBox(height: 48),
            pw.Container(height: 1, color: PdfColors.grey),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'attendance_${DateFormat('yyyyMMdd').format(startDateTime)}.pdf',
    );
  }

  DateTime _timeOfDayToDateTime(TimeOfDay time) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subjectName} • ${widget.classStartTime.format(context)}'),
      ),
      body: FutureBuilder<List<Student>>(
        future: _studentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load student list.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _studentsFuture = _loadStudents();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final students = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final present = _presence[student.rollNumber] ?? false;
                    return Card(
                      child: InkWell(
                        onTap: () => _togglePresence(student.rollNumber),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${student.rollNumber} | ${student.admissionNumber}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  Switch.adaptive(
                                    value: present,
                                    onChanged: (_) => _togglePresence(student.rollNumber),
                                  ),
                                  Text(
                                    present ? 'Present' : 'Absent',
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: students.length,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Export to PDF & Share'),
                      ),
                      onPressed: () => _exportPdf(students),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class Student {
  Student({
    required this.serialNumber,
    required this.rollNumber,
    required this.name,
    required this.admissionNumber,
  });

  final String serialNumber;
  final String rollNumber;
  final String name;
  final String admissionNumber;
}

class StudentContactsScreen extends StatefulWidget {
  const StudentContactsScreen({super.key});

  @override
  State<StudentContactsScreen> createState() => _StudentContactsScreenState();
}

class _StudentContactsScreenState extends State<StudentContactsScreen> {
  late Future<List<ContactEntry>> _contactsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<ContactEntry> _all = [];
  List<ContactEntry> _filtered = [];

  @override
  void initState() {
    super.initState();
    _contactsFuture = _loadContacts();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ContactEntry>> _loadContacts() async {
    final excelBytes = await _loadStudentBytes();
    final excel = Excel.decodeBytes(excelBytes);

    if (excel.tables.isEmpty) {
      throw Exception('No sheets found in Excel');
    }
    final sheet = excel.tables.values.first;
    final contacts = <ContactEntry>[];

    for (var i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;
      if (i == 0) continue; // skip header

      final rollCell = row.length > 1 ? row[1] : null;
      final nameCell = row.length > 2 ? row[2] : null;
      final admissionCell = row.length > 3 ? row[3] : null;
      final phoneCell = row.length > 4 ? row[4] : null;

      final roll = _cellToString(rollCell);
      final name = _cellToString(nameCell);
      final admission = _cellToString(admissionCell);
      final phone = _cellToString(phoneCell);

      if (roll.isEmpty && name.isEmpty && admission.isEmpty && phone.isEmpty) {
        continue;
      }

      contacts.add(
        ContactEntry(
          name: name,
          rollNumber: roll,
          admissionNumber: admission,
          phoneNumber: phone,
        ),
      );
    }

    _all = contacts;
    _filtered = List.of(contacts);
    return contacts;
  }

  String _cellToString(Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    return value.toString().trim();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filtered = List.of(_all);
      });
      return;
    }

    setState(() {
      _filtered = _all.where((c) {
        return c.name.toLowerCase().contains(query) ||
            c.rollNumber.toLowerCase().contains(query) ||
            c.admissionNumber.toLowerCase().contains(query) ||
            c.phoneNumber.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Contacts')),
      body: FutureBuilder<List<ContactEntry>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Could not load contacts.\n${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _contactsFuture = _loadContacts();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final contacts = _filtered;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search by name, roll, admission, phone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    return ListTile(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: c.phoneNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Phone number copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      title: Text(
                        c.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${c.rollNumber} | ${c.admissionNumber} | ${c.phoneNumber}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ContactEntry {
  ContactEntry({
    required this.name,
    required this.rollNumber,
    required this.admissionNumber,
    required this.phoneNumber,
  });

  final String name;
  final String rollNumber;
  final String admissionNumber;
  final String phoneNumber;
}

class UpdateFilesScreen extends StatefulWidget {
  const UpdateFilesScreen({super.key});

  @override
  State<UpdateFilesScreen> createState() => _UpdateFilesScreenState();
}

class _UpdateFilesScreenState extends State<UpdateFilesScreen> {
  bool _isSaving = false;

  Future<void> _pickSchedule() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final file = File(path);
    if (!file.path.toLowerCase().endsWith('.pdf')) return;
    await _saveFile(file, await _scheduleFile());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule updated'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _pickStudentList() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final file = File(path);
    if (!file.path.toLowerCase().endsWith('.xlsx')) return;
    await _saveFile(file, await _studentListFile());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student list updated'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _saveFile(File source, File dest) async {
    setState(() => _isSaving = true);
    try {
      final bytes = await source.readAsBytes();
      await dest.writeAsBytes(bytes, flush: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Files')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Update Schedule PDF'),
              onPressed: _isSaving ? null : _pickSchedule,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.table_view),
              label: const Text('Update Student List (.xlsx)'),
              onPressed: _isSaving ? null : _pickStudentList,
            ),
            const SizedBox(height: 12),
            if (_isSaving) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
