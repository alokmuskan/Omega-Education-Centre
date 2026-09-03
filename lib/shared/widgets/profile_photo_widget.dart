import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/profile_photo_helper.dart';

class ProfilePhotoWidget extends StatefulWidget {
  final String? relativePath;
  final File? previewFile;
  final double radius;
  final String fallbackLetter;
  final bool isEditable;
  final Function(File)? onPhotoSelected;
  final VoidCallback? onPhotoRemoved;

  const ProfilePhotoWidget({
    super.key,
    this.relativePath,
    this.previewFile,
    this.radius = 28,
    required this.fallbackLetter,
    this.isEditable = false,
    this.onPhotoSelected,
    this.onPhotoRemoved,
  });

  @override
  State<ProfilePhotoWidget> createState() => _ProfilePhotoWidgetState();
}

class _ProfilePhotoWidgetState extends State<ProfilePhotoWidget> {
  File? _cachedFile;
  bool _loading = true;
  bool _exists = false;

  @override
  void initState() {
    super.initState();
    _checkFile();
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath || oldWidget.previewFile != widget.previewFile) {
      _checkFile();
    }
  }

  Future<void> _checkFile() async {
    if (widget.previewFile != null) {
      if (mounted) {
        setState(() {
          _cachedFile = widget.previewFile;
          _exists = true;
          _loading = false;
        });
      }
      return;
    }

    if (widget.relativePath != null && widget.relativePath!.isNotEmpty) {
      try {
        final File file = await ProfilePhotoHelper.getAbsoluteFile(widget.relativePath!);
        final bool exists = await file.exists();
        if (mounted) {
          setState(() {
            _cachedFile = file;
            _exists = exists;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _cachedFile = null;
            _exists = false;
            _loading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _cachedFile = null;
          _exists = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _showPickerMenu() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.blue),
                title: const Text('Take Photo using Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Select from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_exists || widget.previewFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final File? file = await ProfilePhotoHelper.pickImage(source);
      if (file != null && widget.onPhotoSelected != null) {
        widget.onPhotoSelected!(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage() {
    if (widget.onPhotoRemoved != null) {
      widget.onPhotoRemoved!();
    }
  }

  Widget _buildAvatar() {
    if (widget.previewFile != null) {
      return Image.file(
        widget.previewFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }
    if (_loading) {
      return _buildFallback();
    }
    if (_exists && _cachedFile != null) {
      return Image.file(
        _cachedFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    final String initial = widget.fallbackLetter.trim().isNotEmpty
        ? widget.fallbackLetter.substring(0, 1)
        : '?';
    return Center(
      child: Text(
        initial.toUpperCase(),
        style: TextStyle(
          fontSize: widget.radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.radius * 2;
    Widget avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.blue.shade100,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: _buildAvatar(),
        ),
      ),
    );

    if (widget.isEditable) {
      return Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showPickerMenu,
              child: CircleAvatar(
                radius: widget.radius * 0.3,
                backgroundColor: Colors.blue.shade700,
                child: Icon(
                  Icons.camera_alt,
                  size: widget.radius * 0.35,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}
