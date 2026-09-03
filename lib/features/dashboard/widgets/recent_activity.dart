import 'package:flutter/material.dart';

class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      {
        "title": "Rahul Kumar paid ₹1,200",
        "subtitle": "10 minutes ago",
        "icon": Icons.payments,
        "color": Colors.green,
      },
      {
        "title": "Class 10 Attendance Completed",
        "subtitle": "25 minutes ago",
        "icon": Icons.check_circle,
        "color": Colors.orange,
      },
      {
        "title": "New Student Added",
        "subtitle": "Today",
        "icon": Icons.person_add,
        "color": Colors.blue,
      },
      {
        "title": "Teacher Salary Paid",
        "subtitle": "Today",
        "icon": Icons.account_balance_wallet,
        "color": Colors.purple,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recent Activities",
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
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, a) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = activities[index];

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      (item["color"] as Color).withAlpha(30),
                  child: Icon(
                    item["icon"] as IconData,
                    color: item["color"] as Color,
                  ),
                ),
                title: Text(
                  item["title"] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(item["subtitle"] as String),
              );
            },
          ),
        ),
      ],
    );
  }
}