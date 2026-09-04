import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../models/test_model.dart';
import '../repository/test_repository.dart';
import 'class_results_screen.dart';
import 'create_test_screen.dart';
import 'enter_results_screen.dart';
import '../../../shared/widgets/empty_state_widget.dart';

/// Main Tests & Results module landing screen listing all configured examinations.
class TestsMainScreen extends StatefulWidget {
  const TestsMainScreen({super.key});

  @override
  State<TestsMainScreen> createState() => _TestsMainScreenState();
}

class _TestsMainScreenState extends State<TestsMainScreen> {
  final _testRepo = TestRepository();
  final _searchController = TextEditingController();

  List<TestModel> _tests = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedTestType = 'All';
  String _selectedClass = 'All';
  String _selectedBoard = 'All';

  final List<String> _testTypeOptions = [
    'All',
    'Unit Test',
    'Monthly Test',
    'Half-Yearly',
    'Pre-Board',
    'Final Exam',
    'Weekly Test',
    'Other',
  ];

  final List<String> _boardOptions = [
    'All',
    'CBSE',
    'ICSE',
    'State Board',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTests({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await _testRepo.getTests(
        query: _searchController.text,
        testType: _selectedTestType,
        studentClass: _selectedClass,
        board: _selectedBoard,
      );

      if (mounted) {
        setState(() {
          _tests = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load tests: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreateTest([TestModel? existing]) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTestScreen(existingTest: existing),
      ),
    );

    if (refreshed == true) {
      _loadTests(silent: true);
    }
  }

  Future<void> _archiveTestConfirm(TestModel test) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Test'),
        content: Text(
          'Are you sure you want to archive "${test.title}"?\n(Historical student results will be preserved safely).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true && test.id != null) {
      await _testRepo.archiveTest(test.id!);
      _loadTests(silent: true);
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

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tests & Results'),
        centerTitle: true,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateTest(),
        icon: const Icon(Icons.add),
        label: const Text('Create Test'),
      ),

      body: Column(
        children: [
          // ── Search & Filters Bar ─────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Search TextField
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search tests by name...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadTests();
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => _loadTests(),
                  ),

                  const SizedBox(height: 10),

                  // Filter Dropdowns Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Test Type Filter
                        DropdownButton<String>(
                          value: _selectedTestType,
                          isDense: true,
                          underline: const SizedBox(),
                          hint: const Text('Type'),
                          items: _testTypeOptions
                              .map((t) => DropdownMenuItem(value: t, child: Text('Type: $t')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTestType = val);
                              _loadTests();
                            }
                          },
                        ),

                        const SizedBox(width: 14),

                        // Class Filter
                        DropdownButton<String>(
                          value: _selectedClass,
                          isDense: true,
                          underline: const SizedBox(),
                          hint: const Text('Class'),
                          items: ['All', ...AppConstants.classes]
                              .map((c) => DropdownMenuItem(value: c, child: Text('Class: $c')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedClass = val);
                              _loadTests();
                            }
                          },
                        ),

                        const SizedBox(width: 14),

                        // Board Filter
                        DropdownButton<String>(
                          value: _selectedBoard,
                          isDense: true,
                          underline: const SizedBox(),
                          hint: const Text('Board'),
                          items: _boardOptions
                              .map((b) => DropdownMenuItem(value: b, child: Text('Board: $b')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedBoard = val);
                              _loadTests();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tests List ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _tests.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: _loadTests,
                            child: ListView.builder(
                              key: const PageStorageKey<String>('tests_list_scroll_key'),
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                              itemCount: _tests.length,
                              itemBuilder: (context, index) {
                                return _buildTestCard(_tests[index], theme);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(TestModel test, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${test.studentClass} • ${test.board} • ${test.testType}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Popup Options Menu
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'enter') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EnterResultsScreen(test: test),
                        ),
                      ).then((_) => _loadTests(silent: true));
                    } else if (val == 'class_results') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassResultsScreen(test: test),
                        ),
                      );
                    } else if (val == 'edit') {
                      _openCreateTest(test);
                    } else if (val == 'archive') {
                      _archiveTestConfirm(test);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'enter',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Enter Results'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'class_results',
                      child: Row(
                        children: [
                          Icon(Icons.leaderboard, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Class Results & Ranks'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Test Setup'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Archive Test'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              'Date: ${test.testDate} • Year: ${test.academicYear} • Subjects: ${test.subjects.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 12),

            // Action Buttons Bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EnterResultsScreen(test: test),
                        ),
                      ).then((_) => _loadTests(silent: true));
                    },
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Enter Marks'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassResultsScreen(test: test),
                        ),
                      );
                    },
                    icon: const Icon(Icons.leaderboard, size: 18),
                    label: const Text('Class Results'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return EmptyStateWidget(
      icon: Icons.quiz_outlined,
      title: 'No tests found',
      subtitle: 'Create a test to start recording student results',
      actionLabel: 'Create Test',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateTestScreen()),
      ).then((_) => _loadTests()),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'An error occurred.', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadTests,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
