import 'package:flutter/material.dart';

import '../../../shared/widgets/profile_photo_widget.dart';
import '../models/student_model.dart';

class StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;

  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPaid = student.feeStatus == "Paid";

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Row(
            children: [

              //---------------- Avatar ----------------

              ProfilePhotoWidget(
                relativePath: student.profilePhotoPath,
                fallbackLetter: student.name.isNotEmpty ? student.name[0] : 'S',
                radius: 28,
              ),

              const SizedBox(width: 16),

              //---------------- Student Info ----------------

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "${student.board} • Class ${student.studentClass}",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "Roll No : ${student.rollNo}",
                    ),

                    const SizedBox(height: 4),

                    Text(
                      student.mobile,
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.shade100
                            : Colors.red.shade100,

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        student.feeStatus,
                        style: TextStyle(
                          color: isPaid
                              ? Colors.green.shade800
                              : Colors.red.shade800,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              //---------------- Arrow ----------------

              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}