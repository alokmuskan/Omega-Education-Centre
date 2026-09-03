import 'package:flutter/material.dart';
import '../services/sync_engine.dart';

/// Minimal non-intrusive sync status indicator widget for Omega ERP.
class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatusState>(
      valueListenable: SyncEngine.instance.statusNotifier,
      builder: (context, status, child) {
        return ValueListenableBuilder<int>(
          valueListenable: SyncEngine.instance.pendingCountNotifier,
          builder: (context, pendingCount, child) {
            Color color;
            IconData icon;
            String text;

            switch (status) {
              case SyncStatusState.synced:
                color = Colors.green;
                icon = Icons.cloud_done;
                text = 'Synced';
                break;
              case SyncStatusState.syncing:
                color = Colors.lightBlueAccent;
                icon = Icons.sync;
                text = 'Syncing...';
                break;
              case SyncStatusState.offline:
                color = Colors.grey;
                icon = Icons.cloud_off;
                text = pendingCount > 0 ? 'Offline ($pendingCount)' : 'Offline';
                break;
              case SyncStatusState.pending:
                color = Colors.amber;
                icon = Icons.cloud_queue;
                text = 'Pending ($pendingCount)';
                break;
              case SyncStatusState.error:
                color = Colors.orangeAccent;
                icon = Icons.sync_problem;
                text = 'Sync Retry';
                break;
              case SyncStatusState.authError:
                color = Colors.deepOrange;
                icon = Icons.lock_outline;
                text = 'Auth Required';
                break;
            }

            return GestureDetector(
              onTap: () => SyncEngine.instance.syncAll(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withAlpha(102)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == SyncStatusState.syncing)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      text,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
