import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../../features/library/models/book_model.dart';

/// Riverpod Demo Screen
///
/// Demonstrates how to use Riverpod providers for state management.
/// This screen shows the pattern for new features.
class RiverpodDemoScreen extends ConsumerWidget {
  const RiverpodDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the books provider
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riverpod Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(booksProvider.notifier).loadBooks(),
          ),
        ],
      ),
      body: booksAsync.when(
        data: (books) => _buildBooksList(context, ref, books),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorWidget(error),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBookDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBooksList(BuildContext context, WidgetRef ref, List<BookModel> books) {
    if (books.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No books yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: book.isAvailable ? Colors.green.shade100 : Colors.red.shade100,
              child: Icon(
                Icons.menu_book,
                color: book.isAvailable ? Colors.green : Colors.red,
              ),
            ),
            title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${book.author ?? "Unknown"} • ${book.availableCopies}/${book.totalCopies} available',
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (value) => _handleAction(context, ref, value, book),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error', style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action, BookModel book) {
    switch (action) {
      case 'edit':
        // TODO: Show edit dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edit ${book.title}')),
        );
        break;
      case 'delete':
        _confirmDelete(context, ref, book);
        break;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BookModel book) {
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
            onPressed: () {
              ref.read(booksProvider.notifier).deleteBook(book.id!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${book.title}"')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddBookDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final authorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: 'Author',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final now = DateTime.now().toIso8601String();
                final book = BookModel(
                  title: titleController.text.trim(),
                  author: authorController.text.trim().isEmpty ? null : authorController.text.trim(),
                  createdAt: now,
                );
                ref.read(booksProvider.notifier).addBook(book);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Book added successfully')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
