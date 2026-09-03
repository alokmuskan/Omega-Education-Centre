import 'package:flutter/material.dart';

/// Search bar widget for filtering teachers.
class TeacherSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const TeacherSearchBar({
    super.key,
    required this.onChanged,
  });

  @override
  State<TeacherSearchBar> createState() => _TeacherSearchBarState();
}

class _TeacherSearchBarState extends State<TeacherSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: "Search teacher by name or mobile...",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
      ),
    );
  }
}
