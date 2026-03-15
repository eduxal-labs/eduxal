import re

with open('lib/ui/widgets/create_exam_modal.dart', 'r') as f:
    content = f.read()

# Instead of Flexible around ListView, we should wrap the whole Column in SingleChildScrollView 
# or give a constrained height to the list view.
# Looking at create_term_modal.dart, it wraps the entire Column inside a SingleChildScrollView!

# Let's replace the Flexible structure with a constrained one.
old_struct = """        Flexible(
          child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: ["""

new_struct = """        Expanded(
          child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: false,
            children: ["""

content = content.replace(old_struct, new_struct)

# And we should also ensure the parent of _CreateExamForm allows Expanded to work.
# Actually, the error might be because we have Expanded inside Column which has mainAxisSize: MainAxisSize.min
# Let's change MainAxisSize.min to MainAxisSize.max or remove mainAxisSize
old_main = """    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,"""

new_main = """    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,"""

content = content.replace(old_main, new_main)

with open('lib/ui/widgets/create_exam_modal.dart', 'w') as f:
    f.write(content)
