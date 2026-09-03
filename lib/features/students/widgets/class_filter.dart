import 'package:flutter/material.dart';

class ClassFilter extends StatelessWidget {
  final List<String> classes;
  final String selectedClass;
  final Function(String) onSelected;

  const ClassFilter({
    super.key,
    required this.classes,
    required this.selectedClass,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: classes.length,
        separatorBuilder: (_, a) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = classes[index];

          return ChoiceChip(
            label: Text(item),
            selected: selectedClass == item,
            onSelected: (_) => onSelected(item),
          );
        },
      ),
    );
  }
}