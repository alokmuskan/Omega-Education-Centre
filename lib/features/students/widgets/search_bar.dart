import 'package:flutter/material.dart';

class StudentSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const StudentSearchBar({
    super.key,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,

      decoration: InputDecoration(
        hintText: "Search Student",
        prefixIcon: const Icon(Icons.search),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}