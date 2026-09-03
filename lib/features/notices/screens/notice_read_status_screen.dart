import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notice_model.dart';
import '../repository/notice_repository.dart';
import '../../../shared/utils/app_session.dart';

/// Admin analytics screen showing real SQLite notice read status.
class NoticeReadStatusScreen extends StatefulWidget {
  final NoticeModel notice;

  const NoticeReadStatusScreen({super.key, required this.notice});

  @override
  State<NoticeReadStatusScreen> createState() => _NoticeReadStatusScreenState();
}

class _NoticeReadStatusScreenState extends State<NoticeReadStatusScreen> with SingleTickerProviderStateMixin {
  final NoticeRepository _repository = NoticeRepository();
  NoticeReadAnalytics? _analytics;
  bool _isLoading = true;
  late TabController _tabController;

  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (!AppSession.instance.isAdmin) {
      _accessDenied = true;
      _isLoading = false;
      return;
    }
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    if (widget.notice.id == null) return;
    setState(() => _isLoading = true);
    final data = await _repository.getNoticeReadAnalytics(widget.notice.id!);
    if (!mounted) return;
    setState(() {
      _analytics = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Administrator privileges required.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Read Analytics'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('Unable to load read analytics.'))
              : Column(
                  children: [
                    // Summary Header Card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.notice.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricTile('Targeted', '${_analytics!.totalTargeted}', Colors.black87),
                              _buildMetricTile('Read', '${_analytics!.readCount}', Colors.green.shade800),
                              _buildMetricTile('Unread', '${_analytics!.unreadCount}', Colors.orange.shade800),
                              _buildMetricTile('Rate', '${_analytics!.readPercentage.toStringAsFixed(1)}%', Colors.indigo.shade800),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _analytics!.totalTargeted > 0 ? (_analytics!.readCount / _analytics!.totalTargeted) : 0,
                            backgroundColor: Colors.indigo.shade100,
                            color: Colors.indigo,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    ),

                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.indigo,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.indigo,
                      tabs: [
                        Tab(text: 'Read (${_analytics!.readCount})'),
                        Tab(text: 'Unread (${_analytics!.unreadCount})'),
                      ],
                    ),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Read Users List
                          _analytics!.readUsers.isEmpty
                              ? const Center(child: Text('No users have read this notice yet.'))
                              : ListView.builder(
                                  itemCount: _analytics!.readUsers.length,
                                  itemBuilder: (ctx, idx) {
                                    final u = _analytics!.readUsers[idx];
                                    String readTimeStr = u['readAt'] ?? '';
                                    try {
                                      final dt = DateTime.parse(readTimeStr);
                                      readTimeStr = DateFormat('dd MMM, hh:mm a').format(dt);
                                    } catch (_) {}

                                    return ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.green,
                                        child: Icon(Icons.check, color: Colors.white, size: 18),
                                      ),
                                      title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Read at: $readTimeStr', style: const TextStyle(fontSize: 12)),
                                    );
                                  },
                                ),

                          // Unread Users List
                          _analytics!.unreadUsers.isEmpty
                              ? const Center(child: Text('All targeted users have read this notice!'))
                              : ListView.builder(
                                  itemCount: _analytics!.unreadUsers.length,
                                  itemBuilder: (ctx, idx) {
                                    final u = _analytics!.unreadUsers[idx];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.orange.shade100,
                                        child: Icon(Icons.mark_email_unread, color: Colors.orange.shade800, size: 18),
                                      ),
                                      title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: const Text('Has not opened notice yet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMetricTile(String label, String val, Color valColor) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valColor)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
