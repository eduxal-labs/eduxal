import re

with open('lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart', 'r') as f:
    content = f.read()

old_func2 = """  Future<void> _showCreateExam(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamCreationPage(
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          config: widget.config,
          entry: widget.entry,
        ),
      ),
    );
  }"""

new_func2 = """  Future<void> _showCreateExam(BuildContext context) async {
    await showCreateExamModal(
      context: context,
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
    );
  }"""

content = content.replace(old_func2, new_func2)

with open('lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart', 'w') as f:
    f.write(content)
