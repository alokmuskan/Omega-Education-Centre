import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../models/student_model.dart';
import '../services/id_card_service.dart';

/// Preview screen for Student ID Card with share and print options.
class IdCardPreviewScreen extends StatefulWidget {
  final StudentModel student;
  const IdCardPreviewScreen({super.key, required this.student});

  @override
  State<IdCardPreviewScreen> createState() => _IdCardPreviewScreenState();
}

class _IdCardPreviewScreenState extends State<IdCardPreviewScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateCard();
  }

  Future<void> _generateCard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _pdfBytes = await IdCardService.instance.generateIdCard(widget.student);
    } catch (e) {
      _error = 'Failed to generate ID card: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ID Card — ${widget.student.name}'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share PDF',
              onPressed: _shareCard,
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print',
              onPressed: _printCard,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Save PDF',
              onPressed: _saveCard,
            ),
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
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _generateCard, child: const Text('Retry')),
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
                        onPressed: _shareCard,
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _printCard,
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
            backgroundColor: Colors.blue.withAlpha(30),
            child: Text(
              widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : 'S',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
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

  Future<void> _shareCard() async {
    if (_pdfBytes == null) return;
    try {
      await IdCardService.instance.shareIdCard(widget.student);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printCard() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _pdfBytes!,
        name: 'ID_Card_${widget.student.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveCard() async {
    if (_pdfBytes == null) return;
    try {
      final fileName = 'ID_Card_${widget.student.name.replaceAll(' ', '_')}_${widget.student.rollNo}.pdf';
      final path = await IdCardService.instance.savePdfToFile(_pdfBytes!, fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID card saved to: $path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
