import re

with open('lib/ui/widgets/create_exam_modal.dart', 'r') as f:
    text = f.read()

text = text.replace("AppDatabase.instance", "db")
text = text.replace("List<SubjectsData> _subjects", "List<Subject> _subjects")
text = text.replace("items: _subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList()", 
                    "items: _subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList()") # if it was null it would be s?.id, but Subject in drift is usually not nullable.
text = text.replace("value: slot.subjectCode,", "value: slot.subjectCode,") # Wait, deprecation warning says use initialValue. I'll just change to DropdownButton instead of FormField or ignore the warning since it's just an info. Or use value on DropdownButton. Let's use DropdownButton.

# Actually, the error is: The property 'id' can't be unconditionally accessed because the receiver can be 'null'
# "items: _subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList()"
# wait, s might be nullable? No, the error is probably for the first or second dropdown. Let's see.

