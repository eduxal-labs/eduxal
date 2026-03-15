import re

with open('lib/ui/widgets/create_exam_modal.dart', 'r') as f:
    content = f.read()

# Instead of using Expanded inside a Column that might not be in a Flex context,
# we should use a SingleChildScrollView for the entire form, or just remove Expanded/Flexible.
# In a dialog, the root should just be a Container or Column with Flexible children if constrained,
# BUT we changed it to MainAxisSize.max implicitly by removing min. 
# Let's revert that and just wrap everything in SingleChildScrollView like create_term_modal.dart.

old_col = """    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding("""

new_col = """    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding("""

content = content.replace(old_col, new_col)

# Now, because we are in a SingleChildScrollView, we CANNOT use Expanded or Flexible.
# We must just render the children directly.
# Replace the Expanded ListView with just a shrinkWrap: true ListView without Expanded.

old_list = """        Expanded(
          child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: false,
            children: ["""

new_list = """        _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: ["""

content = content.replace(old_list, new_list)

with open('lib/ui/widgets/create_exam_modal.dart', 'w') as f:
    f.write(content)
