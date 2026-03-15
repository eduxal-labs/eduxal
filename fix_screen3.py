import re

with open('lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../../widgets/create_exam_modal.dart';", "import '../../../widgets/create_exam_modal.dart';")

with open('lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart', 'w') as f:
    f.write(content)
