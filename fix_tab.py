import re

with open('lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart', 'r') as f:
    content = f.read()

# Add import
if 'create_exam_modal.dart' not in content:
    content = content.replace("import '../../../../widgets/empty_state.dart';", "import '../../../../widgets/empty_state.dart';\nimport '../../../../widgets/create_exam_modal.dart';")

# replace _showCreateExam
old_func = """  Future<void> _showCreateExam(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamCreationPage(
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          config: _config,
          entry: widget.schoolContext.currentEntry.value,
          preselectedGrade: widget.grade,
          preselectedStream: widget.streamCode,
        ),
      ),
    );
  }"""

new_func = """  Future<void> _showCreateExam(BuildContext context) async {
    await showCreateExamModal(
      context: context,
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
    );
  }"""

content = content.replace(old_func, new_func)

with open('lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart', 'w') as f:
    f.write(content)
