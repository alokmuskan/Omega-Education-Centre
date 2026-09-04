import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/book_model.dart';
import '../models/book_issue_model.dart';
import '../repository/library_repository.dart';

/// Library Management Screen
///
/// Two-tab view: Books (inventory) and Issues (tracking).
/// Supports book CRUD, issuing, returning, and overdue management.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LibraryRepository _repo = LibraryRepository();

  List<BookModel> _books = [];
  List<BookIssueModel> _issues = [];
  List<BookIssueModel> _overdueIssues = [];
  Map<String, int> _issueStats = {};
  Map<String, int> _copiesStats = {};
  String _selectedCategory = '';
  String _selectedIssueStatus = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final books = await _repo.getBooks(
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
      );
      final issues = await _repo.getIssues(
        status: _selectedIssueStatus.isEmpty ? null : _selectedIssueStatus,
      );
      final overdue = await _repo.getOverdueIssues();
      final stats = await _repo.getIssueStats();
      final copies = await _repo.getCopiesStats();

      setState(() {
        _books = books;
        _issues = issues;
        _overdueIssues = overdue;
        _issueStats = stats;
        _copiesStats = copies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading library data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.menu_book), text: 'Books'),
            Tab(icon: const Icon(Icons.book_online), text: 'Issues'),
            Tab(
              icon: Badge(
                label: Text('${_overdueIssues.length}'),
                isLabelVisible: _overdueIssues.isNotEmpty,
                child: const Icon(Icons.warning_amber),
              ),
              text: 'Overdue',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBooksTab(),
                _buildIssuesTab(),
                _buildOverdueTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBookForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // BOOKS TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildBooksTab() {
    return Column(
      children: [
        // Stats bar
        _buildStatsBar(),
        // Category filter
        _buildCategoryFilter(),
        // Book list
        Expanded(
          child: _books.isEmpty
              ? _buildEmptyState('No books in library', Icons.menu_book_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _books.length,
                  itemBuilder: (context, index) => _buildBookCard(_books[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Books', '${_copiesStats['total'] ?? 0}', Icons.menu_book),
          _buildStatItem('Available', '${_copiesStats['available'] ?? 0}', Icons.check_circle),
          _buildStatItem('Issued', '${_issueStats['Issued'] ?? 0}', Icons.book_online),
          _buildStatItem('Overdue', '${_overdueIssues.length}', Icons.warning_amber,
              color: _overdueIssues.isNotEmpty ? Colors.red : null),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return FutureBuilder<List<String>>(
      future: _repo.getCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final categories = snapshot.data!;
        return SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory.isEmpty,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = '');
                    _loadData();
                  },
                ),
              ),
              ...categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = selected ? cat : '');
                        _loadData();
                      },
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookCard(BookModel book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: book.isAvailable
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.menu_book,
            color: book.isAvailable
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ),
        title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author != null && book.author!.isNotEmpty)
              Text('by ${book.author}', style: const TextStyle(fontSize: 13)),
            Row(
              children: [
                if (book.category != null)
                  Chip(
                    label: Text(book.category!, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                const SizedBox(width: 8),
                Text(
                  '${book.availableCopies}/${book.totalCopies} available',
                  style: TextStyle(
                    fontSize: 13,
                    color: book.isAvailable ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleBookAction(value, book),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'issue', child: Text('Issue Book')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showBookDetails(book),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ISSUES TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildIssuesTab() {
    return Column(
      children: [
        // Status filter
        _buildIssueStatusFilter(),
        // Issues list
        Expanded(
          child: _issues.isEmpty
              ? _buildEmptyState('No book issues', Icons.book_online)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _issues.length,
                  itemBuilder: (context, index) => _buildIssueCard(_issues[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildIssueStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildStatusChip('All', ''),
          _buildStatusChip('Issued', 'Issued'),
          _buildStatusChip('Returned', 'Returned'),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedIssueStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedIssueStatus = selected ? value : '');
          _loadData();
        },
      ),
    );
  }

  Widget _buildIssueCard(BookIssueModel issue) {
    final isOverdue = issue.isOverdue;
    final statusColor = issue.status == 'Returned'
        ? Colors.green
        : isOverdue
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(30),
          child: Icon(
            issue.status == 'Returned'
                ? Icons.check_circle
                : isOverdue
                    ? Icons.warning_amber
                    : Icons.book_online,
            color: statusColor,
          ),
        ),
        title: Text(issue.bookTitle ?? 'Unknown Book',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${issue.studentName ?? 'Unknown'} (Roll #${issue.studentRollNo ?? '?'})'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Issued: ${_formatDate(issue.issueDate)}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.event, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Due: ${_formatDate(issue.dueDate)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (issue.returnDate != null)
              Text('Returned: ${_formatDate(issue.returnDate!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.green)),
            if (isOverdue)
              Text(
                '${issue.daysOverdue} days overdue • Fine: ₹${issue.calculatedFine.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        trailing: issue.status == 'Issued'
            ? IconButton(
                icon: const Icon(Icons.assignment_return, color: Colors.green),
                onPressed: () => _handleReturnBook(issue),
                tooltip: 'Return Book',
              )
            : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // OVERDUE TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildOverdueTab() {
    return _overdueIssues.isEmpty
        ? _buildEmptyState('No overdue books', Icons.check_circle)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _overdueIssues.length,
            itemBuilder: (context, index) => _buildOverdueCard(_overdueIssues[index]),
          );
  }

  Widget _buildOverdueCard(BookIssueModel issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.errorContainer.withAlpha(50),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withAlpha(30),
          child: const Icon(Icons.warning_amber, color: Colors.red),
        ),
        title: Text(issue.bookTitle ?? 'Unknown Book',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${issue.studentName ?? 'Unknown'} (${issue.studentClass ?? ''})'),
            Text('Due: ${_formatDate(issue.dueDate)}', style: const TextStyle(fontSize: 12)),
            Text(
              '${issue.daysOverdue} days overdue • Fine: ₹${issue.calculatedFine.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.assignment_return, color: Colors.green),
          onPressed: () => _handleReturnBook(issue),
          tooltip: 'Return & Collect Fine',
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════

  void _handleBookAction(String action, BookModel book) {
    switch (action) {
      case 'issue':
        _showIssueBookForm(book);
        break;
      case 'edit':
        _showBookForm(book: book);
        break;
      case 'delete':
        _confirmDeleteBook(book);
        break;
    }
  }

  void _showBookForm({BookModel? book}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BookFormSheet(
        book: book,
        onSave: (book) async {
          final nav = Navigator.of(context);
          if (book.id == null) {
            await _repo.insertBook(book);
          } else {
            await _repo.updateBook(book);
          }
          _loadData();
          if (mounted) nav.pop();
        },
      ),
    );
  }

  void _showIssueBookForm(BookModel book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _IssueBookFormSheet(
        book: book,
        onIssue: (issue) async {
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          await _repo.issueBook(issue);
          _loadData();
          if (mounted) nav.pop();
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Book "${book.title}" issued successfully')),
            );
          }
        },
      ),
    );
  }

  void _handleReturnBook(BookIssueModel issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Book: ${issue.bookTitle}'),
            Text('Student: ${issue.studentName}'),
            if (issue.isOverdue)
              Text(
                'Overdue: ${issue.daysOverdue} days\nFine: ₹${issue.calculatedFine.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final fine = issue.isOverdue ? issue.calculatedFine : 0.0;
              await _repo.returnBook(issue.id!, fine: fine);
              _loadData();
              if (mounted) nav.pop();
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      fine > 0
                          ? 'Book returned. Fine collected: ₹${fine.toStringAsFixed(0)}'
                          : 'Book returned successfully',
                    ),
                  ),
                );
              }
            },
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBook(BookModel book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Are you sure you want to delete "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await _repo.deleteBook(book.id!);
              _loadData();
              if (mounted) nav.pop();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBookDetails(BookModel book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(book.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (book.author != null) Text('by ${book.author}', style: const TextStyle(fontSize: 16)),
              const Divider(height: 24),
              _buildDetailRow('ISBN', book.isbn ?? 'N/A'),
              _buildDetailRow('Category', book.category ?? 'N/A'),
              _buildDetailRow('Shelf Location', book.shelfLocation ?? 'N/A'),
              _buildDetailRow('Total Copies', '${book.totalCopies}'),
              _buildDetailRow('Available', '${book.availableCopies}'),
              _buildDetailRow('Issued', '${book.issuedCopies}'),
              if (book.description != null && book.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Description:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600])),
                Text(book.description!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// BOOK FORM SHEET
// ══════════════════════════════════════════════════════════════════════════

class _BookFormSheet extends StatefulWidget {
  final BookModel? book;
  final Future<void> Function(BookModel) onSave;

  const _BookFormSheet({this.book, required this.onSave});

  @override
  State<_BookFormSheet> createState() => _BookFormSheetState();
}

class _BookFormSheetState extends State<_BookFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _isbnController;
  late TextEditingController _categoryController;
  late TextEditingController _totalCopiesController;
  late TextEditingController _shelfController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book?.title ?? '');
    _authorController = TextEditingController(text: widget.book?.author ?? '');
    _isbnController = TextEditingController(text: widget.book?.isbn ?? '');
    _categoryController = TextEditingController(text: widget.book?.category ?? '');
    _totalCopiesController = TextEditingController(text: '${widget.book?.totalCopies ?? 1}');
    _shelfController = TextEditingController(text: widget.book?.shelfLocation ?? '');
    _descriptionController = TextEditingController(text: widget.book?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _categoryController.dispose();
    _totalCopiesController.dispose();
    _shelfController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.book == null ? 'Add New Book' : 'Edit Book',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Author', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _isbnController,
                    decoration: const InputDecoration(labelText: 'ISBN', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalCopiesController,
                    decoration: const InputDecoration(labelText: 'Total Copies *', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1) return 'Must be ≥ 1';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _shelfController,
                    decoration: const InputDecoration(labelText: 'Shelf Location', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(widget.book == null ? 'Add Book' : 'Update Book'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final totalCopies = int.tryParse(_totalCopiesController.text.trim()) ?? 1;
    final now = DateTime.now().toIso8601String();

    final book = BookModel(
      id: widget.book?.id,
      title: _titleController.text.trim(),
      author: _authorController.text.trim().isEmpty ? null : _authorController.text.trim(),
      isbn: _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      totalCopies: totalCopies,
      availableCopies: widget.book == null
          ? totalCopies
          : (widget.book!.availableCopies + totalCopies - widget.book!.totalCopies).clamp(0, totalCopies),
      shelfLocation: _shelfController.text.trim().isEmpty ? null : _shelfController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      createdAt: widget.book?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.onSave(book);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ISSUE BOOK FORM SHEET
// ══════════════════════════════════════════════════════════════════════════

class _IssueBookFormSheet extends StatefulWidget {
  final BookModel book;
  final Future<void> Function(BookIssueModel) onIssue;

  const _IssueBookFormSheet({required this.book, required this.onIssue});

  @override
  State<_IssueBookFormSheet> createState() => _IssueBookFormSheetState();
}

class _IssueBookFormSheetState extends State<_IssueBookFormSheet> {
  int? _selectedStudentId;
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  double _finePerDay = 1.0;
  final _fineController = TextEditingController(text: '1.0');

  @override
  void dispose() {
    _fineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Issue "${widget.book.title}"',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Student selector (simplified — in production, use a searchable dropdown)
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: 'Select Student *',
              border: OutlineInputBorder(),
            ),
            initialValue: _selectedStudentId,
            items: const [
              DropdownMenuItem(value: 1, child: Text('Student 1')),
              DropdownMenuItem(value: 2, child: Text('Student 2')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedStudentId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateField('Issue Date', _issueDate, (date) {
                  setState(() => _issueDate = date);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField('Due Date', _dueDate, (date) {
                  setState(() => _dueDate = date);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fineController,
            decoration: const InputDecoration(
              labelText: 'Fine per Day (₹)',
              border: OutlineInputBorder(),
              prefixText: '₹ ',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _finePerDay = double.tryParse(v) ?? 1.0,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selectedStudentId == null ? null : _issueBook,
            child: const Text('Issue Book'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text('${date.day}/${date.month}/${date.year}'),
      ),
    );
  }

  Future<void> _issueBook() async {
    if (_selectedStudentId == null) return;

    final now = DateTime.now().toIso8601String();
    final issue = BookIssueModel(
      bookId: widget.book.id!,
      studentId: _selectedStudentId!,
      issueDate: _issueDate.toIso8601String(),
      dueDate: _dueDate.toIso8601String(),
      finePerDay: _finePerDay,
      createdAt: now,
    );

    await widget.onIssue(issue);
  }
}
