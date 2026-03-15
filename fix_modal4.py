with open('lib/ui/widgets/create_exam_modal.dart', 'r') as f:
    content = f.read()

import re

# The error '!semantics.parentDataDirty' usually happens when a layout widget (like Flexible/Expanded)
# is placed incorrectly inside a widget tree that does not expect it.
# We had a SingleChildScrollView wrapping the whole Column, but we *also* have Flexible inside the Column.
# We CANNOT have Flexible inside a SingleChildScrollView > Column.

# Let's completely replace the build method of _CreateExamFormState to be structurally sound without Flexible/Expanded issues.

new_build = """  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Create Exam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: widget.onCancel),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderColor(isDark, cs)),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      color: Colors.red.withValues(alpha: 0.1),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const Text('Exam Name', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Mid Term 1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.kCardRadius)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Papers', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      TextButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Auto-fill'),
                        onPressed: _autoPopulate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_slots.isEmpty)
                     const Padding(
                       padding: EdgeInsets.symmetric(vertical: 16),
                       child: Center(child: Text('No papers added yet.')),
                     )
                  else
                    ..._slots.map((slot) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.nestedBg(isDark, cs),
                        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: slot.subjectCode,
                            isExpanded: true,
                            hint: const Text('Select Subject'),
                            items: _subjects.map((s) => DropdownMenuItem(value: s.id.toString(), child: Text(s.name))).toList(),
                            onChanged: (v) => setState(() { slot.subjectCode = v; _validateSlots(); }),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: slot.invigilatorId,
                            isExpanded: true,
                            hint: const Text('Select Invigilator'),
                            items: _teachers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                            onChanged: (v) => setState(() { slot.invigilatorId = v; _validateSlots(); }),
                          ),
                          if (slot.conflictError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                slot.conflictError!,
                                style: TextStyle(color: cs.error, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    )),
                ],
              ),
            ),

          Divider(height: 1, color: AppTheme.borderColor(isDark, cs)),
          Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: widget.isSheet ? 16 + MediaQuery.paddingOf(context).bottom : 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.kCardRadius)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Exam'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
"""

start_idx = content.find('  @override\n  Widget build(BuildContext context) {')
end_idx = content.rfind('}')

# we want to replace from start_idx to the end of the file except the last `}` of the class
if start_idx != -1:
    # Get everything before the build method
    prefix = content[:start_idx]
    
    with open('lib/ui/widgets/create_exam_modal.dart', 'w') as f:
        f.write(prefix + new_build + "}\n")

