import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/student_model.dart';
import '../services/tc_service.dart';

/// Preview screen for Transfer Certificate with share and print options.
class TcPreviewScreen extends StatefulWidget {
  final StudentModel student;
  const TcPreviewScreen({super.key, required this.student});

  @override
  State<TcPreviewScreen> createState() => _TcPreviewScreenState();
}

class _TcPreviewScreenState extends State<TcPreviewScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _error;

  // TC form data
  final _reasonController = TextEditingController();
  final _conductController = TextEditingController(text: 'Good');
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateTc();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _conductController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _generateTc() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _pdfBytes = await TcService.instance.generateTc(
        student: widget.student,
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
        conduct: _conductController.text.isEmpty ? null : _conductController.text,
        remarks: _remarksController.text.isEmpty ? null : _remarksController.text,
      );
    } catch (e) {
      _error = 'Failed to generate TC: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TC — ${widget.student.name}'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(icon: const Icon(Icons.share), tooltip: 'Share', onPressed: _shareTc),
            IconButton(icon: const Icon(Icons.print), tooltip: 'Print', onPressed: _printTc),
            IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit Details', onPressed: _showEditSheet),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _generateTc, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Student info header
                    _buildStudentHeader(),
                    // PDF preview
                    Expanded(
                      child: PdfPreview(
                        build: (format) => _pdfBytes!,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        allowPrinting: false,
                        allowSharing: false,
                        useActions: false,
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _pdfBytes != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareTc,
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _printTc,
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStudentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.teal.withAlpha(30),
            child: Text(
              widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : 'S',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  'Class ${widget.student.studentClass} • Roll #${widget.student.rollNo} • ${widget.student.board}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TC Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Leaving',
                  hintText: 'e.g. Transfer, Personal reasons',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _conductController,
                decoration: const InputDecoration(
                  labelText: 'Conduct',
                  hintText: 'e.g. Good, Excellent',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Additional Remarks',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _generateTc();
                  },
                  child: const Text('Regenerate TC'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareTc() async {
    if (_pdfBytes == null) return;
    try {
      await TcService.instance.shareTc(
        widget.student,
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
        conduct: _conductController.text.isEmpty ? null : _conductController.text,
        remarks: _remarksController.text.isEmpty ? null : _remarksController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printTc() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _pdfBytes!,
        name: 'TC_${widget.student.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
