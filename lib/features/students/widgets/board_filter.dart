import 'package:flutter/material.dart';

class BoardFilter extends StatelessWidget {
  final List<String> boards;
  final String selectedBoard;
  final Function(String) onSelected;

  const BoardFilter({
    super.key,
    required this.boards,
    required this.selectedBoard,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Board",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 15),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: boards.map((board) {
            return ChoiceChip(
              label: Text(board),
              selected: selectedBoard == board,
              showCheckmark: true,
              onSelected: (_) => onSelected(board),

              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,

              labelStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selectedBoard == board
                    ? Colors.deepPurple
                    : Colors.black87,
              ),

              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}