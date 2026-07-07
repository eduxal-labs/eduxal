import 'dart:convert';
import 'dart:io';
import 'lib/models/timetable_rules.dart';
import 'lib/services/timetable_generator.dart';
import 'lib/database/daos/timetable_dao.dart';

void main() async {
  final rulesPath = "/home/abdihakim/Documents/schools/6a27f6ffd2458819b70ab6fc/timetable_rules_2026_2.json";
  final assignmentsPath = "/home/abdihakim/.gemini/antigravity-cli/brain/cb5b454f-d93d-466e-9756-762a12a8e0a3/scratch/assignments_2026_2.json";

  final rulesStr = await File(rulesPath).readAsString();
  var rules = TimetableRules.fromJsonString(rulesStr);

  final assignmentsStr = await File(assignmentsPath).readAsString();
  final List<dynamic> assignmentsJson = jsonDecode(assignmentsStr);
  final assignments = assignmentsJson.map((e) => SolverAssignment(
    school: e['school'],
    year: e['year'],
    term: e['term'],
    grade: e['grade'],
    stream: e['stream'],
    subjectId: e['subjectId'],
    subjectName: e['subjectName'],
    teacherUserId: e['teacherUserId'],
  )).toList();

  // Let's run with rules exactly as they are in the database, with verbose logging!
  print("Starting verbose TimetableGenerator...");
  final generator = TimetableGenerator(
    assignments: assignments,
    rules: rules,
    maxRestarts: 1,
  );
  
  final result = generator.generate();
  if (result is GeneratorSuccess) {
    print("SUCCESS: Found solution!");
  } else if (result is GeneratorFailure) {
    print("FAILURE: ${result.reason}");
    for (final c in result.conflicts) {
      print("  Conflict: $c");
    }
  }
}
