import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduxal/models/timetable_rules.dart';
import 'package:eduxal/services/timetable_generator.dart';
import 'package:eduxal/database/daos/timetable_dao.dart';

void main() {
  test('timetable generator performance regression benchmark', () async {
    final rulesPath = "/home/abdihakim/Documents/schools/6a27f6ffd2458819b70ab6fc/timetable_rules_2026_2.json";
    final assignmentsPath = "/home/abdihakim/.gemini/antigravity-cli/brain/cb5b454f-d93d-466e-9756-762a12a8e0a3/scratch/assignments_2026_2.json";

    print("Loading rules from $rulesPath");
    final rulesStr = await File(rulesPath).readAsString();
    var rules = TimetableRules.fromJsonString(rulesStr);

    print("Loading assignments from $assignmentsPath");
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

    // programmatically override rules:
    // 1. Remove subject constraints
    // 2. Remove teacher constraints
    // 3. Set class daily cap to 10
    // 4. Set teacher daily cap to 10
    rules = rules.copyWith(
      subjectConstraints: [],
      teacherConstraints: [],
      maxLessonsPerDayTeacher: 10,
      maxLessonsPerDayClass: 10,
      allowDoubles: true,
    );

    print("Starting TimetableGenerator with ${assignments.length} assignments...");
    final stopwatch = Stopwatch()..start();
    final generator = TimetableGenerator(
      assignments: assignments,
      rules: rules,
      maxRestarts: 20,
    );
    
    final result = generator.generate();
    stopwatch.stop();

    if (result is GeneratorSuccess) {
      print("SUCCESS: Found solution in ${stopwatch.elapsedMilliseconds}ms!");
      print("Slots scheduled: ${result.slots.length}");
      print("Iterations: ${result.iterations}");
    } else if (result is GeneratorFailure) {
      print("FAILURE: ${result.reason}");
    }
  });
}
