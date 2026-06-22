import 'package:flutter_test/flutter_test.dart';
import 'package:eduxal/services/import_file_parser.dart';

void main() {
  group('ImportFileParser Grade Normalization Tests', () {
    test('normalizes 8-4-4 grades correctly', () {
      const jsonContent = '''
      {
        "subject": "Mathematics",
        "curriculum": "844",
        "grade": 4,
        "topic": "Algebra",
        "questions": [
          {
            "body": "Solve for x",
            "marks": 5,
            "rubric": [
              {"criterion": "Correct steps", "marks": 3},
              {"criterion": "Correct answer", "marks": 2}
            ]
          }
        ]
      }
      ''';

      final result = parseImportFile('test_file.json', jsonContent);
      expect(result.validationErrors, isEmpty);
      expect(result.grade, equals(44)); // Form 4 maps to 44
      expect(result.rawGrade, equals(4));
    });

    test('normalizes CBC Grade 12 correctly', () {
      const jsonContent = '''
      {
        "subject": "Mathematics",
        "curriculum": "cbc",
        "grade": 12,
        "topic": "Calculus",
        "questions": [
          {
            "body": "Find the derivative",
            "marks": 5,
            "rubric": [
              {"criterion": "Correct steps", "marks": 3},
              {"criterion": "Correct answer", "marks": 2}
            ]
          }
        ]
      }
      ''';

      final result = parseImportFile('test_file.json', jsonContent);
      expect(result.validationErrors, isEmpty);
      expect(result.grade, equals(14)); // Grade 12 maps to 14
      expect(result.rawGrade, equals(12));
    });

    test('normalizes CBC Grade 10 correctly', () {
      const jsonContent = '''
      {
        "subject": "Mathematics",
        "curriculum": "cbc",
        "grade": 10,
        "topic": "Trigonometry",
        "questions": [
          {
            "body": "Find sin(x)",
            "marks": 5,
            "rubric": [
              {"criterion": "Correct steps", "marks": 3},
              {"criterion": "Correct answer", "marks": 2}
            ]
          }
        ]
      }
      ''';

      final result = parseImportFile('test_file.json', jsonContent);
      expect(result.validationErrors, isEmpty);
      expect(result.grade, equals(12)); // Grade 10 maps to 12
      expect(result.rawGrade, equals(10));
    });

    test('normalizes CBC Grade 1 correctly', () {
      const jsonContent = '''
      {
        "subject": "Mathematics",
        "curriculum": "cbc",
        "grade": 1,
        "topic": "Counting",
        "questions": [
          {
            "body": "Count to 10",
            "marks": 5,
            "rubric": [
              {"criterion": "Correct steps", "marks": 3},
              {"criterion": "Correct answer", "marks": 2}
            ]
          }
        ]
      }
      ''';

      final result = parseImportFile('test_file.json', jsonContent);
      expect(result.validationErrors, isEmpty);
      expect(result.grade, equals(3)); // Grade 1 maps to 3
      expect(result.rawGrade, equals(1));
    });

    test('leaves already normalized CBC grades unchanged', () {
      const jsonContent = '''
      {
        "subject": "Mathematics",
        "curriculum": "cbc",
        "grade": 14,
        "topic": "Calculus",
        "questions": [
          {
            "body": "Find the derivative",
            "marks": 5,
            "rubric": [
              {"criterion": "Correct steps", "marks": 3},
              {"criterion": "Correct answer", "marks": 2}
            ]
          }
        ]
      }
      ''';

      final result = parseImportFile('test_file.json', jsonContent);
      expect(result.validationErrors, isEmpty);
      expect(result.grade, equals(14)); // Already 14, remains 14
      expect(result.rawGrade, equals(14));
    });
  });
}
