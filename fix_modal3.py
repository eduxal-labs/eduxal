import re

with open('lib/ui/widgets/create_exam_modal.dart', 'r') as f:
    content = f.read()

# I removed an Expanded but maybe missed a parenthesis.
# Let's just fix the parenthesis error.
# We had:
#        _loading
#            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
#            : ListView(
#            physics: const NeverScrollableScrollPhysics(),
#            padding: const EdgeInsets.all(16),
#            shrinkWrap: true,
#            children: [

# If it was previously Expanded(child: ...), the closing bracket of the Column had an extra ) for the Expanded.
# Let's fix the syntax error at line 422.

# Actually, replacing Expanded(child: X) with X leaves a trailing ) at the end of X.
content = content.replace("), // End Expanded?", "")
# Let's just do a regex replace or string replace for the end of the listview.
# It used to end with:
#                 )),
#             ],
#           ),
#         ),

old_end = """                )),
            ],
          ),
        ),"""

new_end = """                )),
            ],
          ),"""

content = content.replace(old_end, new_end)

with open('lib/ui/widgets/create_exam_modal.dart', 'w') as f:
    f.write(content)
