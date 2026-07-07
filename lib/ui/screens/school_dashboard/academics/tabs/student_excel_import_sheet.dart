import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, TextStyle, BorderStyle; // 'Border', 'TextStyle', and 'BorderStyle' conflict with material
import '../../../../../client.dart';
import '../../../../../database/database.dart';
import '../../../../../database/daos/enrollments_dao.dart';
import '../../../../../database/daos/members_dao.dart';
import '../../../../../database/tables/enums.dart';
import '../../../../../models/result.dart';
import '../../../../../services/members.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/edu_sheet.dart';

class StudentExcelImportSheet extends StatefulWidget {
  const StudentExcelImportSheet({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.gradeLabel,
    required this.streamCode,
    required this.streamName,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final String gradeLabel;
  final int streamCode;
  final String streamName;

  @override
  State<StudentExcelImportSheet> createState() => _StudentExcelImportSheetState();
}

enum _ImportPhase {
  chooseFile,
  mapColumns,
  processing,
  completed,
}

class _StudentExcelImportSheetState extends State<StudentExcelImportSheet> {
  final _membersDao = MembersDao(db);
  final _enrollmentsDao = EnrollmentsDao(db);
  late final MemberCreationService _memberService;

  _ImportPhase _phase = _ImportPhase.chooseFile;
  bool _pickingFile = false;
  File? _selectedFile;
  Excel? _excel;
  List<String> _headers = [];

  // Column mapping states (value is the selected header name)
  String? _admCol;
  String? _nameCol;
  String? _phoneCol;
  String? _guardianNameCol;

  // Import progress tracking
  int _totalRows = 0;
  int _currentRow = 0;
  int _successCount = 0;
  int _failureCount = 0;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _memberService = MemberCreationService(_membersDao);
  }

  String _cellVal(dynamic cell) {
    if (cell == null) return '';
    final val = cell.value;
    if (val == null) return '';
    return val.toString().trim();
  }

  String? _findMatchingHeader(List<String> headers, List<String> keywords) {
    for (final header in headers) {
      final norm = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final kw in keywords) {
        if (norm.contains(kw)) {
          return header;
        }
      }
    }
    return null;
  }

  Future<void> _pickFile() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final bytes = file.readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        if (excel.tables.isEmpty) {
          throw Exception('The spreadsheet contains no sheets.');
        }

        final firstSheetKey = excel.tables.keys.first;
        final sheet = excel.tables[firstSheetKey];
        if (sheet == null || sheet.rows.isEmpty) {
          throw Exception('The sheet is empty.');
        }

        final headers = sheet.rows.first.map((cell) => _cellVal(cell)).toList();
        if (headers.isEmpty || headers.every((h) => h.isEmpty)) {
          throw Exception('No header columns detected in the first row.');
        }

        setState(() {
          _selectedFile = file;
          _excel = excel;
          _headers = headers;
          _phase = _ImportPhase.mapColumns;

          // Fuzzy-match mapping defaults
          _admCol = _findMatchingHeader(headers, ['adm', 'admission', 'studentno', 'studentnum', 'reg', 'id']);
          _nameCol = _findMatchingHeader(headers, ['name', 'studentname', 'fullname', 'fname', 'lname']);
          _phoneCol = _findMatchingHeader(headers, ['parentphone', 'guardianphone', 'phone', 'mobile', 'contact', 'tel', 'parentcontact', 'guardiancontact']);
          _guardianNameCol = _findMatchingHeader(headers, ['parentname', 'guardianname', 'parent', 'guardian', 'father', 'mother', 'gname', 'pname']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading Excel: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  Future<void> _startImport() async {
    if (_excel == null || _selectedFile == null) return;
    if (_nameCol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student Name mapping is required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active account found. Please sign in again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final firstSheetKey = _excel!.tables.keys.first;
    final sheet = _excel!.tables[firstSheetKey]!;
    final rows = sheet.rows;

    setState(() {
      _phase = _ImportPhase.processing;
      _totalRows = rows.length - 1; // skip header
      _currentRow = 0;
      _successCount = 0;
      _failureCount = 0;
      _errors = [];
    });

    final admIdx = _admCol != null ? _headers.indexOf(_admCol!) : -1;
    final nameIdx = _headers.indexOf(_nameCol!);
    final phoneIdx = _phoneCol != null ? _headers.indexOf(_phoneCol!) : -1;
    final guardianNameIdx = _guardianNameCol != null ? _headers.indexOf(_guardianNameCol!) : -1;

    for (int i = 1; i < rows.length; i++) {
      if (!mounted) break;
      final row = rows[i];
      setState(() => _currentRow = i);

      // Extract values using indices
      final studentName = nameIdx >= 0 && nameIdx < row.length ? _cellVal(row[nameIdx]) : '';
      if (studentName.isEmpty) {
        _failureCount++;
        _errors.add('Row ${i + 1}: Student Name is blank. Skipped.');
        continue;
      }

      String admStr = admIdx >= 0 && admIdx < row.length ? _cellVal(row[admIdx]) : '';
      int? parsedAdm;
      if (admStr.isNotEmpty) {
        parsedAdm = int.tryParse(admStr);
        if (parsedAdm == null) {
          // If ADM cannot be parsed, use null to auto-generate
          _errors.add('Row ${i + 1}: Could not parse admission number "$admStr" as number. Auto-assigning.');
        }
      }

      final guardianPhone = phoneIdx >= 0 && phoneIdx < row.length ? _cellVal(row[phoneIdx]) : '';
      final guardianName = guardianNameIdx >= 0 && guardianNameIdx < row.length ? _cellVal(row[guardianNameIdx]) : '';

      try {
        // Step 1: Create Student
        final studentResult = await _memberService.createStudent(
          schoolId: widget.schoolId,
          name: studentName,
          adm: parsedAdm,
        );

        switch (studentResult) {
          case Ok(:final value):
            final student = value;
            // Step 2: Enroll Student
            await _enrollmentsDao.enrollStudent(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: widget.grade,
              stream: widget.streamCode,
              studentAdm: student.adm,
              accountId: accountId,
            );

            // Step 3: Create Guardian if phone is provided
            if (guardianPhone.isNotEmpty) {
              final cleanPhone = guardianPhone.replaceAll(RegExp(r'[^0-9+]'), '');
              if (cleanPhone.length >= 7) {
                final parentName = guardianName.isNotEmpty ? guardianName : '$studentName Guardian';
                final guardianResult = await _memberService.createGuardian(
                  schoolId: widget.schoolId,
                  studentAdm: student.adm,
                  phone: cleanPhone,
                  name: parentName,
                );
                if (guardianResult is Err) {
                  _errors.add('Row ${i + 1} (${student.name}): Student enrolled, but guardian creation failed: ${(guardianResult as Err).error}');
                }
              } else {
                _errors.add('Row ${i + 1} (${student.name}): Invalid parent phone format "$guardianPhone". Guardian link skipped.');
              }
            }

            _successCount++;
            break;

          case Err(:final error):
            _failureCount++;
            _errors.add('Row ${i + 1} ($studentName): Creation failed: ${error.name}');
            break;
        }
      } catch (e) {
        _failureCount++;
        _errors.add('Row ${i + 1} ($studentName): Error occurred: ${e.toString()}');
      }

      // Small delay to keep the UI smooth and responsive
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() => _phase = _ImportPhase.completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Students from Excel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enroll into ${widget.gradeLabel} · ${widget.streamName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // Content body based on import phase
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildPhaseContent(cs, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(ColorScheme cs, bool isDark) {
    switch (_phase) {
      case _ImportPhase.chooseFile:
        return _buildChooseFilePhase(cs, isDark);
      case _ImportPhase.mapColumns:
        return _buildMapColumnsPhase(cs, isDark);
      case _ImportPhase.processing:
        return _buildProcessingPhase(cs, isDark);
      case _ImportPhase.completed:
        return _buildCompletedPhase(cs, isDark);
    }
  }

  Widget _buildChooseFilePhase(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _pickingFile ? null : _pickFile,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.upload_file_outlined,
                      size: 26,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select spreadsheet file',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Supports Excel files (.xlsx)',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your Excel file should contain columns for Student Admission Number (optional), Student Name, Guardian Phone Number, and Guardian Name.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_pickingFile)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Parsing spreadsheet...',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapColumnsPhase(ColorScheme cs, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Map Spreadsheet Columns',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We detected ${_headers.length} columns. Assign them to our expected fields below.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Fields
                _buildMappingDropdown(
                  label: 'Student Name (Required)',
                  value: _nameCol,
                  icon: Icons.person_outline_rounded,
                  onChanged: (val) => setState(() => _nameCol = val),
                ),
                const SizedBox(height: 14),
                _buildMappingDropdown(
                  label: 'Student Admission Number (Optional)',
                  value: _admCol,
                  icon: Icons.pin_outlined,
                  onChanged: (val) => setState(() => _admCol = val),
                  hint: 'Auto-assign if unmapped',
                ),
                const SizedBox(height: 14),
                _buildMappingDropdown(
                  label: 'Guardian Phone Number (Optional)',
                  value: _phoneCol,
                  icon: Icons.phone_outlined,
                  onChanged: (val) => setState(() => _phoneCol = val),
                  hint: 'Do not import guardians if unmapped',
                ),
                const SizedBox(height: 14),
                _buildMappingDropdown(
                  label: 'Guardian Name (Optional)',
                  value: _guardianNameCol,
                  icon: Icons.badge_outlined,
                  onChanged: (val) => setState(() => _guardianNameCol = val),
                  hint: 'Fall back to default if unmapped',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _phase = _ImportPhase.chooseFile;
                      _selectedFile = null;
                      _excel = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _nameCol == null ? null : _startImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandGreen,
                    disabledBackgroundColor: cs.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                  ),
                  child: const Text('Start Import'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMappingDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String? hint,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _headers.contains(value) ? value : null,
                    hint: Text(
                      hint ?? 'Select column...',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    items: [
                      if (hint != null)
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            hint,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ..._headers.map((h) {
                        return DropdownMenuItem<String>(
                          value: h,
                          child: Text(
                            h,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface,
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingPhase(ColorScheme cs, bool isDark) {
    final progress = _totalRows > 0 ? _currentRow / _totalRows : 0.0;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.brandGreen,
                value: progress,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Importing Students...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Row $_currentRow of $_totalRows parsed',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: cs.surfaceContainerHighest,
              color: AppTheme.brandGreen,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressStat(
                label: 'Succeeded',
                value: _successCount.toString(),
                color: AppTheme.brandGreen,
              ),
              _buildProgressStat(
                label: 'Failed',
                value: _failureCount.toString(),
                color: cs.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required String label,
    required String value,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedPhase(ColorScheme cs, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _failureCount == 0
                              ? AppTheme.brandGreen.withValues(alpha: 0.12)
                              : cs.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _failureCount == 0
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          size: 24,
                          color: _failureCount == 0 ? AppTheme.brandGreen : cs.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _failureCount == 0 ? 'Import Completed!' : 'Import completed with warnings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Successfully imported $_successCount students',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_errors.isNotEmpty) ...[
                  Text(
                    'Import Logs & Failures (${_errors.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _errors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: _errors[index].contains('failed') ? cs.error : cs.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errors[index],
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
            ),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}

extension on ColorScheme {
  Color get amber => Colors.amber;
}
