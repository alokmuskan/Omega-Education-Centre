import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../repository/fee_repository.dart';
import 'student_fee_details_screen.dart';

/// Role-gated Master Fee Management Dashboard for Admin / Director.
class AdminFeeDashboardScreen extends StatefulWidget {
  const AdminFeeDashboardScreen({super.key});

  @override
  State<AdminFeeDashboardScreen> createState() => _AdminFeeDashboardScreenState();
}

class _AdminFeeDashboardScreenState extends State<AdminFeeDashboardScreen> with SingleTickerProviderStateMixin {
  final _repository = FeeRepository();
  late TabController _tabController;

  List<StudentFeeRecord> _allFeeRecords = [];
  List<StudentFeeRecord> _pendingRecords = [];
  ClassFeeSummary? _classSummary;

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedClass = 'All';
  String _selectedBoard = 'All';
  final String _selectedFeeStatus = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final q = _searchController.text.trim();

      final records = await _repository.getAllStudentFeeRecords(
        searchQuery: q,
        studentClass: _selectedClass,
        board: _selectedBoard,
        feeStatus: _selectedFeeStatus,
      );

      final pending = await _repository.getAllStudentFeeRecords(
        searchQuery: q,
        studentClass: _selectedClass,
        board: _selectedBoard,
        pendingOnly: true,
      );

      ClassFeeSummary? summary;
      if (_selectedClass != 'All') {
        summary = await _repository.getClassFeeSummary(_selectedClass, board: _selectedBoard);
      }

      if (mounted) {
        setState(() {
          _allFeeRecords = records;
          _pendingRecords = pending;
          _classSummary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load fee records: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.instance.isAdmin) {
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
        title: const Text('Fee Management'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber), text: 'Pending Dues'),
            Tab(icon: Icon(Icons.insights), text: 'Class Summary'),
            Tab(icon: Icon(Icons.people), text: 'All Students'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Global Filter & Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by student name or roll number...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (_) => _loadData(),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedClass,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          border: OutlineInputBorder(),
                        ),
                        items: AppConstants.classesWithAll.map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Classes' : 'Class $c'))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedClass = val);
                            _loadData();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBoard,
                        decoration: const InputDecoration(
                          labelText: 'Board',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          border: OutlineInputBorder(),
                        ),
                        items: AppConstants.boardsWithAll.map((b) => DropdownMenuItem(value: b, child: Text(b == 'All' ? 'All Boards' : b))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBoard = val);
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Tab Views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPendingDuesTab(),
                          _buildClassSummaryTab(),
                          _buildAllStudentsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // TAB 1: PENDING DUES VIEW
  Widget _buildPendingDuesTab() {
    if (_pendingRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
            const SizedBox(height: 16),
            const Text('No Outstanding Dues Found!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('All students in this filter have fully paid their fees.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey<String>('admin_fee_pending_list_scroll_key'),
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRecords.length,
      itemBuilder: (context, index) {
        final r = _pendingRecords[index];
        return _buildFeeRecordCard(r);
      },
    );
  }

  // TAB 2: CLASS COLLECTION SUMMARY
  Widget _buildClassSummaryTab() {
    if (_selectedClass == 'All') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_outlined, size: 64, color: Colors.indigo.shade300),
            const SizedBox(height: 16),
            const Text('Select a Specific Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Select Class 9, Class 10, etc. above to view breakdown.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      );
    }

    if (_classSummary == null) {
      return const Center(child: Text('No summary data available.'));
    }

    final cs = _classSummary!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Class Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade900,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'CLASS ${cs.studentClass} (${cs.board}) COLLECTION REPORT',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricCol('Total Students', cs.totalStudents.toString()),
                    _metricCol('Paid', cs.paidCount.toString(), color: Colors.greenAccent),
                    _metricCol('Partial', cs.partiallyPaidCount.toString(), color: Colors.amberAccent),
                    _metricCol('Unpaid', cs.unpaidCount.toString(), color: Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Amounts Grid
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('Total Course Fee Payable', '₹${cs.totalPayable.toStringAsFixed(2)}', isBold: true),
                  const Divider(),
                  _summaryRow('Total Collected to Date', '₹${cs.totalCollected.toStringAsFixed(2)}', color: Colors.green.shade800, isBold: true),
                  const Divider(),
                  _summaryRow('Total Outstanding Balance', '₹${cs.totalOutstanding.toStringAsFixed(2)}', color: Colors.red.shade800, isBold: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Progress Bar
          if (cs.totalPayable > 0) ...[
            const Align(alignment: Alignment.centerLeft, child: Text('Collection Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (cs.totalCollected / cs.totalPayable).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.red.shade100,
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${((cs.totalCollected / cs.totalPayable) * 100).toStringAsFixed(1)}% Collected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricCol(String title, String val, {Color? color}) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Widget _summaryRow(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  // TAB 3: ALL STUDENTS ROSTER
  Widget _buildAllStudentsTab() {
    if (_allFeeRecords.isEmpty) {
      return const Center(child: Text('No student records match the search/filter criteria.'));
    }

    return ListView.builder(
      key: const PageStorageKey<String>('admin_fee_all_list_scroll_key'),
      padding: const EdgeInsets.all(16),
      itemCount: _allFeeRecords.length,
      itemBuilder: (context, index) {
        final r = _allFeeRecords[index];
        return _buildFeeRecordCard(r);
      },
    );
  }

  Widget _buildFeeRecordCard(StudentFeeRecord r) {
    Color statusBg = Colors.red.shade100;
    Color statusFg = Colors.red.shade900;

    if (r.feeStatus == 'Paid') {
      statusBg = Colors.green.shade100;
      statusFg = Colors.green.shade900;
    } else if (r.feeStatus == 'Partially Paid') {
      statusBg = Colors.orange.shade100;
      statusFg = Colors.orange.shade900;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentFeeDetailsScreen(studentId: r.student.id!),
            ),
          );
          _loadData(silent: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text(
                        r.student.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      r.feeStatus.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                'Class ${r.student.studentClass} (${r.student.board}) • Roll No: ${r.student.rollNo}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fee: ₹${r.totalPayable.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                  Text('Paid: ₹${r.totalPaid.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  Text('Due: ₹${r.remainingDue.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
