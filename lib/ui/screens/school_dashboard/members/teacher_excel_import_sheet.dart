import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle; // 'Border' and 'BorderStyle' conflict with material
import '../../../../client.dart';
import '../../../../core/extensions.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../models/result.dart';
import '../../../../services/members.dart';
import '../../../theme/app_theme.dart';

class TeacherExcelImportSheet extends StatefulWidget {
  const TeacherExcelImportSheet({
    super.key,
    required this.schoolId,
  });

  final String schoolId;

  @override
  State<TeacherExcelImportSheet> createState() => _TeacherExcelImportSheetState();
}

enum _ImportPhase {
  chooseFile,
  mapColumns,
  processing,
  completed,
}

class _SheetData {
  _SheetData({required this.headerRowIndex, required this.headers});
  final int headerRowIndex;
  final List<String> headers;
}

class _TeacherExcelImportSheetState extends State<TeacherExcelImportSheet> {
  final _membersDao = MembersDao(db);
  late final MemberCreationService _memberService;

  _ImportPhase _phase = _ImportPhase.chooseFile;
  bool _pickingFile = false;
  File? _selectedFile;
  Excel? _excel;
  List<String> _headers = [];
  int _headerRowIndex = 0;

  // Column mapping states (value is the selected header name)
  String? _phoneCol;
  String? _nameCol;
  String? _roleCol;
  String? _departmentCol;
  String? _hiredDateCol;

  String? _selectedSheetKey;

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

  _SheetData _extractSheetData(Sheet sheet) {
    int headerRowIndex = 0;
    List<String> headers = [];

    for (int i = 0; i < sheet.rows.length && i < 10; i++) {
      final row = sheet.rows[i];
      final values = row.map((cell) => _cellVal(cell)).toList();
      final nonCount = values.where((v) => v.isNotEmpty).length;

      if (nonCount >= 2) {
        final hasKeywords = values.any((v) {
          final norm = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          return norm.contains('name') ||
              norm.contains('phone') ||
              norm.contains('mobile') ||
              norm.contains('contact') ||
              norm.contains('tel') ||
              norm.contains('hired') ||
              norm.contains('date') ||
              norm.contains('dept') ||
              norm.contains('department') ||
              norm.contains('role');
        });

        if (hasKeywords) {
          headerRowIndex = i;
          headers = values;
          break;
        }

        if (headers.isEmpty) {
          headerRowIndex = i;
          headers = values;
        }
      }
    }

    if (headers.isEmpty && sheet.rows.isNotEmpty) {
      headerRowIndex = 0;
      headers = sheet.rows.first.map((cell) => _cellVal(cell)).toList();
    }

    return _SheetData(headerRowIndex: headerRowIndex, headers: headers);
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

        final sheetData = _extractSheetData(sheet);
        final headers = sheetData.headers;

        setState(() {
          _selectedFile = file;
          _excel = excel;
          _selectedSheetKey = firstSheetKey;
          _headers = headers;
          _headerRowIndex = sheetData.headerRowIndex;
          _phase = _ImportPhase.mapColumns;

          // Fuzzy-match mapping defaults
          _phoneCol = _findMatchingHeader(headers, ['phone', 'mobile', 'contact', 'tel', 'phoneno', 'telephone']);
          _nameCol = _findMatchingHeader(headers, ['name', 'teachername', 'fullname', 'fname', 'lname']);
          _roleCol = _findMatchingHeader(headers, ['role', 'title', 'designation', 'job']);
          _departmentCol = _findMatchingHeader(headers, ['dept', 'department', 'faculty']);
          _hiredDateCol = _findMatchingHeader(headers, ['hired', 'hireddate', 'date', 'joindate', 'joining']);
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

  void _onSheetChanged(String? key) {
    if (key == null || _excel == null) return;
    final sheet = _excel!.tables[key];
    if (sheet == null || sheet.rows.isEmpty) return;

    final sheetData = _extractSheetData(sheet);
    setState(() {
      _selectedSheetKey = key;
      _headers = sheetData.headers;
      _headerRowIndex = sheetData.headerRowIndex;

      // Re-run matching
      _phoneCol = _findMatchingHeader(_headers, ['phone', 'mobile', 'contact', 'tel', 'phoneno', 'telephone']);
      _nameCol = _findMatchingHeader(_headers, ['name', 'teachername', 'fullname', 'fname', 'lname']);
      _roleCol = _findMatchingHeader(_headers, ['role', 'title', 'designation', 'job']);
      _departmentCol = _findMatchingHeader(_headers, ['dept', 'department', 'faculty']);
      _hiredDateCol = _findMatchingHeader(_headers, ['hired', 'hireddate', 'date', 'joindate', 'joining']);
    });
  }

  DateTime? _parseDate(String val) {
    if (val.isEmpty) return null;
    final direct = DateTime.tryParse(val);
    if (direct != null) return direct;

    // Try slash/dash DD/MM/YYYY or DD-MM-YYYY
    final regSlash = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$');
    final match = regSlash.firstMatch(val);
    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final year = int.tryParse(match.group(3) ?? '');
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    // Try Excel serial date
    final doubleVal = double.tryParse(val);
    if (doubleVal != null && doubleVal > 20000 && doubleVal < 60000) {
      final base = DateTime(1899, 12, 30);
      return base.add(Duration(days: doubleVal.toInt()));
    }

    return null;
  }

  Future<void> _startImport() async {
    if (_excel == null || _selectedFile == null) return;
    if (_phoneCol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher Phone Number mapping is required.'),
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

    final sheetKey = _selectedSheetKey ?? _excel!.tables.keys.first;
    final sheet = _excel!.tables[sheetKey]!;
    final rows = sheet.rows;

    setState(() {
      _phase = _ImportPhase.processing;
      _totalRows = rows.length - (_headerRowIndex + 1);
      _currentRow = 0;
      _successCount = 0;
      _failureCount = 0;
      _errors = [];
    });

    final phoneIdx = _headers.indexOf(_phoneCol!);
    final nameIdx = _nameCol != null ? _headers.indexOf(_nameCol!) : -1;
    final roleIdx = _roleCol != null ? _headers.indexOf(_roleCol!) : -1;
    final deptIdx = _departmentCol != null ? _headers.indexOf(_departmentCol!) : -1;
    final hiredIdx = _hiredDateCol != null ? _headers.indexOf(_hiredDateCol!) : -1;

    for (int i = _headerRowIndex + 1; i < rows.length; i++) {
      if (!mounted) break;
      final row = rows[i];
      setState(() => _currentRow = i - _headerRowIndex);

      final rawPhone = phoneIdx >= 0 && phoneIdx < row.length ? _cellVal(row[phoneIdx]) : '';
      if (rawPhone.isEmpty) {
        _failureCount++;
        _errors.add('Row ${i + 1}: Phone number is empty. Skipped.');
        continue;
      }

      final normalizedPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '').toKenyanPhone() ?? rawPhone.trim();
      if (normalizedPhone.length < 7) {
        _failureCount++;
        _errors.add('Row ${i + 1}: Invalid phone number format "$rawPhone". Skipped.');
        continue;
      }

      final teacherName = nameIdx >= 0 && nameIdx < row.length ? _cellVal(row[nameIdx]) : 'Teacher $normalizedPhone';
      final resolvedName = teacherName.isNotEmpty ? teacherName : 'Teacher $normalizedPhone';

      final roleStr = roleIdx >= 0 && roleIdx < row.length ? _cellVal(row[roleIdx]) : null;
      final resolvedRole = roleStr != null && roleStr.isNotEmpty ? roleStr : null;

      final deptStr = deptIdx >= 0 && deptIdx < row.length ? _cellVal(row[deptIdx]) : null;
      final resolvedDept = deptStr != null && deptStr.isNotEmpty ? deptStr : null;

      final hiredStr = hiredIdx >= 0 && hiredIdx < row.length ? _cellVal(row[hiredIdx]) : '';
      final DateTime? hiredDate = hiredStr.isNotEmpty ? _parseDate(hiredStr) : null;

      try {
        final result = await _memberService.createTeacher(
          schoolId: widget.schoolId,
          phone: normalizedPhone,
          name: resolvedName,
          role: resolvedRole,
          department: resolvedDept,
          hiredDate: hiredDate,
        );

        switch (result) {
          case Ok():
            _successCount++;
            break;
          case Err(:final error):
            _failureCount++;
            if (error == MemberCreationError.alreadyExists) {
              _errors.add('Row ${i + 1} ($resolvedName): Teacher already exists in this school.');
            } else {
              _errors.add('Row ${i + 1} ($resolvedName): $error');
            }
            break;
        }
      } catch (e) {
        _failureCount++;
        _errors.add('Row ${i + 1} ($resolvedName): Exception occurred: $e');
      }
    }

    if (mounted) {
      setState(() {
        _phase = _ImportPhase.completed;
      });
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
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.upload_file_outlined,
                    color: AppTheme.brandGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Teachers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFile != null
                            ? _selectedFile!.path.split('/').last
                            : 'Upload a spreadsheet to import teachers in bulk',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    'Your Excel file should contain columns for Phone Number (Required), Full Name (Optional), Role (Optional), Department (Optional), and Hired Date (Optional).',
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

                // Sheet Selector
                if (_excel != null && _excel!.tables.keys.length > 1) ...[
                  Text(
                    'Select Sheet to Import',
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
                        Icon(Icons.table_chart_outlined, size: 18, color: cs.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSheetKey ?? _excel!.tables.keys.first,
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                              items: _excel!.tables.keys.map((sheetName) {
                                return DropdownMenuItem<String>(
                                  value: sheetName,
                                  child: Text(
                                    sheetName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: _onSheetChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Fields
                _buildMappingDropdown(
                  label: 'Teacher Phone Number (Required)',
                  value: _phoneCol,
                  icon: Icons.phone_outlined,
                  onChanged: (val) => setState(() => _phoneCol = val),
                ),
                const SizedBox(height: 14),
                _buildMappingDropdown(
                  label: 'Teacher Full Name (Optional)',
                  value: _nameCol,
                  icon: Icons.person_outline_rounded,
                  onChanged: (val) => setState(() => _nameCol = val),
                  hint: 'Auto-assign as Teacher [Phone]',
                ),
                const SizedBox(height: 14),
                _buildMappingDropdown(
                  label: 'Role / Designation (Optional)',
                  value: _roleCol,
                  icon: Icons.badge_outlined,
                  onChanged: (val) => setState(() => _roleCol = val),
                  hint: 'Do not import roles',
                ),
                const SizedBox(height: 14),
                _buildMappingDropdown(
                  label: 'Department (Optional)',
                  value: _departmentCol,
                  icon: Icons.corporate_fare_outlined,
                  onChanged: (val) => setState(() => _departmentCol = val),
                  hint: 'Do not import departments',
                ),
                const SizedBox(height: 14),
                _buildMappingDropdown(
                  label: 'Hired Date (Optional)',
                  value: _hiredDateCol,
                  icon: Icons.calendar_today_outlined,
                  onChanged: (val) => setState(() => _hiredDateCol = val),
                  hint: 'Do not import hired date',
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
                      _selectedFile = null;
                      _excel = null;
                      _phase = _ImportPhase.chooseFile;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                  ),
                  child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _phoneCol == null ? null : _startImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                  ),
                  child: const Text('Start Import', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    value: _headers.contains(value) && value != null && value.isNotEmpty ? value : null,
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
                      ..._headers
                          .where((h) => h.isNotEmpty)
                          .toSet()
                          .map((h) {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                color: AppTheme.brandGreen,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Importing Teachers...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Processing row $_currentRow of $_totalRows',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandGreen),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetric(cs, 'Imported', '$_successCount', AppTheme.brandGreen),
              _buildMetric(cs, 'Failed', '$_failureCount', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(ColorScheme cs, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedPhase(ColorScheme cs, bool isDark) {
    final hasErrors = _errors.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: (_successCount > 0 ? AppTheme.brandGreen : Colors.red).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _successCount > 0 ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    color: _successCount > 0 ? AppTheme.brandGreen : Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Import Completed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We successfully imported $_successCount teachers to your school roster.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMetric(cs, 'Imported', '$_successCount', AppTheme.brandGreen),
                    const SizedBox(width: 16),
                    _buildMetric(cs, 'Failed', '$_failureCount', Colors.red),
                  ],
                ),
                if (hasErrors) ...[
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Import Error Log (${_errors.length})',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: cs.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _errors.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 12,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (context, idx) {
                        return Text(
                          _errors[idx],
                          style: TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: cs.error.withValues(alpha: 0.85),
                          ),
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
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
