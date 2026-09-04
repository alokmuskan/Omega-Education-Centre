import 'package:flutter/material.dart';

import '../../../shared/screens/notification_center_screen.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/utils/app_session.dart';
import '../../../shared/widgets/sync_status_widget.dart';
import '../../authentication/login/login_screen.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppSession.instance.clearSession();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = AppSession.instance.currentUsername.isNotEmpty
        ? AppSession.instance.currentUsername
        : "Avinash Kumar";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF0D47A1),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    "Omega Education Centre",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 8),

                const SyncStatusWidget(),

                const SizedBox(width: 4),

                // Notification Bell
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 30), (_) => NotificationService.instance.unreadCount),
                  initialData: NotificationService.instance.unreadCount,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return IconButton(
                      icon: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications, color: Colors.white, size: 20),
                          ),
                          if (count > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      tooltip: 'Notifications',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                      ),
                    );
                  },
                ),

                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  tooltip: 'Logout',
                  onPressed: () => _logout(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 34,
                      color: Color(0xFF0D47A1),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome Back 👋",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Administrator / Director",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}