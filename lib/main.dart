import 'package:excel/excel.dart';
import 'dart:convert';
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

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
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

String cleanTextValue(dynamic value) {
  String text;
  if (value is num) {
    // Avoid trailing .0 on integer-like numbers
    if (value is int || value == value.roundToDouble()) {
      text = value.toInt().toString();
    } else {
      text = value.toString();
    }
  } else {
    text = value.toString();
  }
  text = text.trim();
  // Strip a trailing .0 if it snuck in as text
  if (text.endsWith('.0')) {
    final possibleInt = text.substring(0, text.length - 2);
    if (possibleInt.isNotEmpty && RegExp(r'^-?\d+$').hasMatch(possibleInt)) {
      return possibleInt;
    }
  }
  return text;
}

String _cleanTextValue(dynamic value) => cleanTextValue(value);

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
              label: 'Groups',
              description: 'Create class groups for activities',
              icon: Icons.groups,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GroupsScreen(),
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
  final TextEditingController _searchController = TextEditingController();
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];

  @override
  void initState() {
    super.initState();
    _studentsFuture = _loadStudents().then((students) {
      _allStudents = students;
      _filteredStudents = List.of(students);
      return students;
    });
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final phoneCell = row.length > 4 ? row[4] : null;

      final serial = _cellToString(serialCell);
      final roll = _cellToString(rollCell);
      final name = _cellToString(nameCell);
      final admission = _cellToString(admissionCell);
      final phone = _cellToString(phoneCell);

      if (serial.isEmpty && roll.isEmpty && name.isEmpty && admission.isEmpty) {
        continue;
      }

      final student = Student(
        serialNumber: serial,
        rollNumber: roll,
        name: name,
        admissionNumber: admission,
        phoneNumber: phone,
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
    return _cleanTextValue(value);
  }

  void _togglePresence(String roll) {
    setState(() {
      _presence[roll] = !(_presence[roll] ?? false);
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredStudents = List.of(_allStudents));
      return;
    }

    setState(() {
      _filteredStudents = _allStudents.where((s) {
        return s.name.toLowerCase().contains(query) ||
            s.rollNumber.toLowerCase().contains(query) ||
            s.admissionNumber.toLowerCase().contains(query);
      }).toList();
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
              data: _allStudents
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

          final students = _filteredStudents.isNotEmpty || _searchController.text.isNotEmpty
              ? _filteredStudents
              : (_allStudents.isNotEmpty ? _allStudents : snapshot.data!);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search by name, roll, admission',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
    this.phoneNumber = '',
  });

  final String serialNumber;
  final String rollNumber;
  final String name;
  final String admissionNumber;
  final String phoneNumber;
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
    return _cleanTextValue(value);
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

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<void> _loadFuture;
  List<Student> _students = [];
  List<GroupSet> _groupSets = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAll();
  }

  Future<void> _loadAll() async {
    _students = await _loadStudentsForGroups();
    _groupSets = await _loadGroupSets();
    _sanitizeGroupMembersStrings();
  }

  void _sanitizeGroupMembersStrings() {
    if (_groupSets.isEmpty) return;
    bool changed = false;
    for (final set in _groupSets) {
      for (final group in set.groups) {
        final cleaned = group.members
            .map((m) => StudentRef(
                  rollNumber: _cleanTextValue(m.rollNumber),
                  name: _cleanTextValue(m.name),
                  admissionNumber: _cleanTextValue(m.admissionNumber),
                  phoneNumber: _cleanTextValue(m.phoneNumber),
                ))
            .toList();
        if (!_listEqualsMembers(cleaned, group.members)) {
          group.members
            ..clear()
            ..addAll(cleaned);
          changed = true;
        }
      }
    }
    if (changed) {
      _saveGroupSets();
    }
  }

  bool _listEqualsMembers(List<StudentRef> a, List<StudentRef> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].rollNumber != b[i].rollNumber ||
          a[i].name != b[i].name ||
          a[i].admissionNumber != b[i].admissionNumber ||
          a[i].phoneNumber != b[i].phoneNumber) {
        return false;
      }
    }
    return true;
  }

  Future<List<Student>> _loadStudentsForGroups() async {
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
      if (i == 0) continue;
      final serialCell = row.isNotEmpty ? row[0] : null;
      final rollCell = row.length > 1 ? row[1] : null;
      final nameCell = row.length > 2 ? row[2] : null;
      final admissionCell = row.length > 3 ? row[3] : null;
      final phoneCell = row.length > 4 ? row[4] : null;
      final serial = _cellToStringGroup(serialCell);
      final roll = _cellToStringGroup(rollCell);
      final name = _cellToStringGroup(nameCell);
      final admission = _cellToStringGroup(admissionCell);
      final phone = _cellToStringGroup(phoneCell);
      if (serial.isEmpty && roll.isEmpty && name.isEmpty && admission.isEmpty) continue;
      students.add(Student(
        serialNumber: serial,
        rollNumber: roll,
        name: name,
        admissionNumber: admission,
        phoneNumber: phone,
      ));
    }
    return students;
  }

  String _cellToStringGroup(Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    return _cleanTextValue(value);
  }

  Future<File> _groupsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/groups.json');
  }

  Future<List<GroupSet>> _loadGroupSets() async {
    final file = await _groupsFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final data = json.decode(content) as List<dynamic>;
    return data.map((e) => GroupSet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveGroupSets() async {
    final file = await _groupsFile();
    final content = json.encode(_groupSets.map((e) => e.toJson()).toList());
    await file.writeAsString(content, flush: true);
  }

  Future<bool> _confirmDelete(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm delete'),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteGroupSet(GroupSet set) async {
    final ok = await _confirmDelete('Delete this group set? This cannot be undone.');
    if (!ok) return;
    setState(() {
      _groupSets.remove(set);
    });
    await _saveGroupSets();
  }

  Future<void> _deleteGroup(GroupSet set, Group group) async {
    final ok = await _confirmDelete('Delete ${group.name}? Students will be unassigned in this set.');
    if (!ok) return;
    setState(() {
      set.groups.remove(group);
    });
    await _saveGroupSets();
  }

  Future<void> _addStudentToGroup(GroupSet set, Group group) async {
    final assignedRolls = _assignedRolls(set);
    final available = _students.where((s) => !assignedRolls.contains(s.rollNumber)).toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All students already assigned')));
      }
      return;
    }

    final searchController = TextEditingController();
    Student? selected;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final q = searchController.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? available
                : available.where((s) {
                    return s.name.toLowerCase().contains(q) ||
                        s.rollNumber.toLowerCase().contains(q) ||
                        s.admissionNumber.toLowerCase().contains(q);
                  }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 12,
                left: 12,
                right: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Add student to ${group.name}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search by name, roll, admission',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setStateModal(() {}),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 320,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        return ListTile(
                          title: Text(s.name),
                          subtitle: Text('${s.rollNumber} • ${s.admissionNumber}'),
                          onTap: () {
                            selected = s;
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;

    setState(() {
      group.members.add(StudentRef.fromStudent(selected!));
    });
    await _saveGroupSets();
  }

  void _removeStudentFromGroup(GroupSet set, Group group, StudentRef student) async {
    setState(() {
      group.members.removeWhere((m) => m.rollNumber == student.rollNumber);
    });
    await _saveGroupSets();
  }

  Set<String> _assignedRolls(GroupSet set) {
    return set.groups.expand((g) => g.members.map((m) => m.rollNumber)).toSet();
  }

  Future<void> _exportGroupSet(GroupSet set) async {
    final opts = await _pickExportFields();
    if (opts == null) return;
    if (!(opts.includeGroupName || opts.includeSerial || opts.includeStudentName || opts.includeRoll || opts.includeAdmission || opts.includePhone)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one field to export')));
      }
      return;
    }
    final dateStr = DateFormat('yMMMd').format(set.createdAt);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text('Group Set: ${set.name}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Date: $dateStr'),
            pw.SizedBox(height: 16),
            ...set.groups.expand((g) {
              int serialCounter = 1;
              final headers = <String>[];
              if (opts.includeGroupName) headers.add('Group');
              if (opts.includeSerial) headers.add('S.No');
              if (opts.includeStudentName) headers.add('Name');
              if (opts.includeRoll) headers.add('Roll Number');
              if (opts.includeAdmission) headers.add('SBU Admission Number');
              if (opts.includePhone) headers.add('Phone Numbers');

              final rows = g.members.map((m) {
                final row = <String>[];
                if (opts.includeGroupName) row.add(g.name);
                if (opts.includeSerial) row.add((serialCounter++).toString());
                if (opts.includeStudentName) row.add(m.name);
                if (opts.includeRoll) row.add(m.rollNumber);
                if (opts.includeAdmission) row.add(m.admissionNumber);
                if (opts.includePhone) row.add(m.phoneNumber);
                return row;
              }).toList();

              return [
                pw.Text(g.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table.fromTextArray(
                  headers: headers,
                  data: rows,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 16),
              ];
            }).toList(),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'groups_${DateFormat('yyyyMMdd').format(set.createdAt)}.pdf');
  }

  Future<_ExportOptions?> _pickExportFields() async {
    bool includeGroup = true;
    bool includeSerial = true;
    bool includeName = true;
    bool includeRoll = true;
    bool includeAdmission = true;
    bool includePhone = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Export fields'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: includeGroup,
                      onChanged: (v) => setStateDialog(() => includeGroup = v ?? true),
                      title: const Text('Group Name/Number'),
                    ),
                    CheckboxListTile(
                      value: includeSerial,
                      onChanged: (v) => setStateDialog(() => includeSerial = v ?? true),
                      title: const Text('S.No'),
                    ),
                    CheckboxListTile(
                      value: includeName,
                      onChanged: (v) => setStateDialog(() => includeName = v ?? true),
                      title: const Text('Student Name'),
                    ),
                    CheckboxListTile(
                      value: includeRoll,
                      onChanged: (v) => setStateDialog(() => includeRoll = v ?? true),
                      title: const Text('Roll Number'),
                    ),
                    CheckboxListTile(
                      value: includeAdmission,
                      onChanged: (v) => setStateDialog(() => includeAdmission = v ?? true),
                      title: const Text('SBU Admission Number'),
                    ),
                    CheckboxListTile(
                      value: includePhone,
                      onChanged: (v) => setStateDialog(() => includePhone = v ?? true),
                      title: const Text('Phone Number'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Export')),
              ],
            );
          },
        );
      },
    );

    if (result != true) return null;
    return _ExportOptions(
      includeGroupName: includeGroup,
      includeSerial: includeSerial,
      includeStudentName: includeName,
      includeRoll: includeRoll,
      includeAdmission: includeAdmission,
      includePhone: includePhone,
    );
  }

  Future<void> _createGroupSet() async {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final manualGroupCountController = TextEditingController();
    final subjectController = TextEditingController();
    var mode = _GroupMode.groupSize;
    var manualMode = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Group Set', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Group set name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Manual grouping'),
                    value: manualMode,
                    onChanged: (v) {
                      setStateModal(() {
                        manualMode = v;
                      });
                    },
                  ),
                  if (!manualMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<_GroupMode>(
                            title: const Text('Group size'),
                            value: _GroupMode.groupSize,
                            groupValue: mode,
                            onChanged: (v) {
                              setStateModal(() {
                                mode = v ?? _GroupMode.groupSize;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<_GroupMode>(
                            title: const Text('Number of groups'),
                            value: _GroupMode.groupCount,
                            groupValue: mode,
                            onChanged: (v) {
                              setStateModal(() {
                                mode = v ?? _GroupMode.groupCount;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: numberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: mode == _GroupMode.groupSize ? 'Students per group' : 'Number of groups',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: manualGroupCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of groups',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (manualMode) {
                          if (nameController.text.trim().isEmpty || subjectController.text.trim().isEmpty || manualGroupCountController.text.trim().isEmpty) {
                            return;
                          }
                        } else {
                          if (nameController.text.trim().isEmpty || numberController.text.trim().isEmpty) {
                            return;
                          }
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != true) return;
    final name = nameController.text.trim();
    if (_students.isEmpty) return;

    if (manualMode) {
      final groupCount = int.tryParse(manualGroupCountController.text.trim()) ?? 0;
      final subject = subjectController.text.trim();
      if (groupCount <= 0 || subject.isEmpty) return;
      final newSet = _createManualGroupSet(name: name, subject: subject, groupCount: groupCount);
      setState(() {
        _groupSets.add(newSet);
      });
      await _saveGroupSets();
    } else {
      final number = int.tryParse(numberController.text.trim()) ?? 0;
      if (number <= 0) return;
      final newSet = _generateGroupSet(name: name, mode: mode, number: number, students: _students);
      setState(() {
        _groupSets.add(newSet);
      });
      await _saveGroupSets();
    }
  }

  GroupSet _generateGroupSet({required String name, required _GroupMode mode, required int number, required List<Student> students}) {
    final groups = <Group>[];
    if (mode == _GroupMode.groupSize) {
      final size = number;
      if (size <= 0) {
        return GroupSet(
          name: name,
          groups: groups,
          mode: mode == _GroupMode.groupSize ? 'size' : 'count',
          number: number,
          createdAt: DateTime.now(),
          subject: '',
          isManual: false,
        );
      }
      for (var i = 0; i < students.length; i += size) {
        final slice = students.sublist(i, i + size > students.length ? students.length : i + size);
        groups.add(Group(name: 'Group ${groups.length + 1}', members: slice.map((s) => StudentRef.fromStudent(s)).toList()));
      }
    } else {
      var count = number;
      if (count > students.length) {
        count = students.length; // cap to avoid empty groups
      }
      if (count <= 0) {
        return GroupSet(
          name: name,
          groups: groups,
          mode: mode == _GroupMode.groupSize ? 'size' : 'count',
          number: number,
          createdAt: DateTime.now(),
          subject: '',
          isManual: false,
        );
      }
      final base = students.length ~/ count;
      final extra = students.length % count;
      int index = 0;
      for (var g = 0; g < count; g++) {
        final size = base + (g < extra ? 1 : 0);
        final slice = students.sublist(index, index + size);
        index += size;
        groups.add(Group(name: 'Group ${groups.length + 1}', members: slice.map((s) => StudentRef.fromStudent(s)).toList()));
      }
    }

    return GroupSet(
      name: name,
      groups: groups,
      mode: mode == _GroupMode.groupSize ? 'size' : 'count',
      number: number,
      createdAt: DateTime.now(),
      subject: '',
      isManual: false,
    );
  }

  GroupSet _createManualGroupSet({required String name, required String subject, required int groupCount}) {
    final groups = List<Group>.generate(
      groupCount,
      (i) => Group(name: 'Group ${i + 1}', members: []),
    );
    return GroupSet(
      name: name,
      subject: subject,
      groups: groups,
      mode: 'manual',
      number: groupCount,
      createdAt: DateTime.now(),
      isManual: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: FutureBuilder<void>(
        future: _loadFuture,
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
                    Text('Could not load groups/students.\n${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _loadFuture = _loadAll();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_students.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No students found. Please upload a student list via Update Files.'),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: _groupSets.isEmpty
                    ? const Center(child: Text('No group sets yet. Tap + to create.'))
                    : ListView.builder(
                        itemCount: _groupSets.length,
                        itemBuilder: (context, index) {
                          final set = _groupSets[index];
                          return ExpansionTile(
                            title: Text(set.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${set.groups.length} groups${set.isManual && set.subject.isNotEmpty ? ' • ${set.subject}' : ''} • Created ${DateFormat('yMMMd').format(set.createdAt)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  onPressed: () => _exportGroupSet(set),
                                  tooltip: 'Export to PDF',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteGroupSet(set),
                                  tooltip: 'Delete group set',
                                ),
                              ],
                            ),
                            children: set.groups.map((g) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(g.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () => _deleteGroup(set, g),
                                          tooltip: 'Delete group',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (set.isManual) ...[
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: g.members
                                            .map(
                                              (m) => Chip(
                                                label: Text('${m.name} (${m.rollNumber})'),
                                                onDeleted: () => _removeStudentFromGroup(set, g, m),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.person_add),
                                          label: const Text('Add Student'),
                                          onPressed: () => _addStudentToGroup(set, g),
                                        ),
                                      ),
                                    ] else ...[
                                      ...g.members.map((m) => Text('- ${m.name} (${m.rollNumber})')).toList(),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Group Set'),
                      onPressed: _createGroupSet,
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

enum _GroupMode { groupSize, groupCount }

class GroupSet {
  GroupSet({
    required this.name,
    required this.groups,
    required this.mode,
    required this.number,
    required this.createdAt,
    required this.isManual,
    required this.subject,
  });

  final String name;
  final List<Group> groups;
  final String mode; // 'size' or 'count'
  final int number;
  final DateTime createdAt;
  final bool isManual;
  final String subject;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mode': mode,
        'number': number,
        'createdAt': createdAt.toIso8601String(),
        'isManual': isManual,
        'subject': subject,
        'groups': groups.map((g) => g.toJson()).toList(),
      };

  factory GroupSet.fromJson(Map<String, dynamic> json) => GroupSet(
        name: json['name'] as String,
        mode: json['mode'] as String,
        number: json['number'] as int,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        isManual: json['isManual'] as bool? ?? false,
        subject: json['subject'] as String? ?? '',
        groups: (json['groups'] as List<dynamic>)
            .map((e) => Group.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Group {
  Group({required this.name, required this.members});

  final String name;
  final List<StudentRef> members;

  Map<String, dynamic> toJson() => {
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        name: json['name'] as String,
        members: (json['members'] as List<dynamic>)
            .map((e) => StudentRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StudentRef {
  StudentRef({
    required this.rollNumber,
    required this.name,
    required this.admissionNumber,
    this.phoneNumber = '',
  });

  final String rollNumber;
  final String name;
  final String admissionNumber;
  final String phoneNumber;

  Map<String, dynamic> toJson() => {
        'rollNumber': rollNumber,
        'name': name,
        'admissionNumber': admissionNumber,
        'phoneNumber': phoneNumber,
      };

  factory StudentRef.fromJson(Map<String, dynamic> json) => StudentRef(
        rollNumber: _cleanTextValue(json['rollNumber'] ?? ''),
        name: _cleanTextValue(json['name'] ?? ''),
        admissionNumber: _cleanTextValue(json['admissionNumber'] ?? ''),
        phoneNumber: _cleanTextValue(json['phoneNumber'] ?? ''),
      );

  factory StudentRef.fromStudent(Student s) =>
      StudentRef(
        rollNumber: s.rollNumber,
        name: s.name,
        admissionNumber: s.admissionNumber,
        phoneNumber: s.phoneNumber,
      );
}

class _ExportOptions {
  _ExportOptions({
    required this.includeGroupName,
    required this.includeSerial,
    required this.includeStudentName,
    required this.includeRoll,
    required this.includeAdmission,
    required this.includePhone,
  });

  final bool includeGroupName;
  final bool includeSerial;
  final bool includeStudentName;
  final bool includeRoll;
  final bool includeAdmission;
  final bool includePhone;
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
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path!;
    final file = File(path);
    if (!file.path.toLowerCase().endsWith('.xlsx')) return;
    await _saveFile(file, await _studentListFile());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student list updated. Restart to reload data.')),
    );
  }

  Future<void> _downloadTemplate() async {
    final templateFile = await _templateFile();
    if (!await templateFile.exists()) {
      final ok = await _ensureTemplateCached();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template file missing in project database folder.')),
        );
        return;
      }
    }

    final bytes = await templateFile.readAsBytes();
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save student list template',
      fileName: 'class_list.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: bytes,
    );
    if (savePath == null || savePath.isEmpty) return;
    final destPath = savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx';
    final destFile = File(destPath);
    if (await destFile.exists()) {
      final overwrite = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Overwrite file?'),
              content: Text('File already exists at $destPath. Overwrite?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Overwrite')),
              ],
            ),
          ) ??
          false;
      if (!overwrite) return;
    }

    // Ensure bytes are written to the exact path (saveFile writes on mobile when bytes are provided, but we also persist to the normalized path).
    await destFile.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student list template saved successfully')),
    );
  }

  Future<File> _templateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/student_list_template.xlsx');
  }

  Future<bool> _ensureTemplateCached() async {
    try {
      final data = await rootBundle.load('database/class_list.xlsx');
      final file = await _templateFile();
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return true;
    } catch (_) {
      return false;
    }
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
            const SizedBox(height: 24),
            _UpdateTile(
              icon: Icons.picture_as_pdf,
              title: 'Update Schedule PDF',
              subtitle: 'Replace the current schedule document',
              onTap: _pickSchedule,
            ),
            const SizedBox(height: 12),
            _UpdateTile(
              icon: Icons.table_view,
              title: 'Update Student List (.xlsx)',
              subtitle: 'Replace the current student list Excel file',
              onTap: _pickStudentList,
            ),
            const SizedBox(height: 12),
            _UpdateTile(
              icon: Icons.download,
              title: 'Download Student List Template (.xlsx)',
              subtitle: 'Get an empty Excel with required headers',
              onTap: _downloadTemplate,
            ),
            const SizedBox(height: 12),
            if (_isSaving) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
