import 'package:flutter/material.dart';

class TodayClasses extends StatelessWidget {
  const TodayClasses({super.key});

  @override
  Widget build(BuildContext context) {
    final classes = [
      {
        "time": "09:00 AM",
        "subject": "Class 10 Science",
      },
      {
        "time": "10:00 AM",
        "subject": "Class 9 Mathematics",
      },
      {
        "time": "11:30 AM",
        "subject": "Class 12 Physics",
      },
      {
        "time": "01:00 PM",
        "subject": "Foundation Batch",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Classes",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 15),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListView.builder(
            itemCount: classes.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = classes[index];

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.schedule),
                ),
                title: Text(
                  item["subject"]!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Text(
                  item["time"]!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}