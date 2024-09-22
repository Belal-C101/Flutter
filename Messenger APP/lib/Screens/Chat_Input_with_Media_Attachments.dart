import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class EnhancedInputBar extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(String) onSendAudio;
  final Function(String) onSendImage;
  final Function(String) onSendDocument;

  EnhancedInputBar({
    required this.onSendMessage,
    required this.onSendAudio,
    required this.onSendImage,
    required this.onSendDocument,
  });

  @override
  _EnhancedInputBarState createState() => _EnhancedInputBarState();
}

class _EnhancedInputBarState extends State<EnhancedInputBar> {
  final TextEditingController _messageController = TextEditingController();
  bool _showAttachmentOptions = false;

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    if (status.isGranted) {
      print('Permission granted');
    } else {
      print('Permission denied');
      // Show a dialog explaining why the permission is needed
      _showPermissionDeniedDialog(permission);
    }
  }

  void _showPermissionDeniedDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text('This feature requires ${permission.toString()} permission to function properly.'),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    await _requestPermission(Permission.camera);
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      final String? url = await _uploadFile(File(image.path), 'images');
      if (url != null) {
        widget.onSendImage(url);
      }
    }
  }

  Future<void> _pickDocument() async {
    await _requestPermission(Permission.storage);
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      final String? url = await _uploadFile(file, 'documents');
      if (url != null) {
        widget.onSendDocument(url);
      }
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('$folder/${DateTime.now().millisecondsSinceEpoch}${file.path.split('/').last}');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showAttachmentOptions)
          Container(
            color: Color(0xFF2A3942),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachmentOption(Icons.photo, 'Photos', () => _pickImage(ImageSource.gallery)),
                _attachmentOption(Icons.camera_alt, 'Camera', () => _pickImage(ImageSource.camera)),
                _attachmentOption(Icons.location_on, 'Location', () {}),
                _attachmentOption(Icons.person, 'Contact', () {}),
                _attachmentOption(Icons.insert_drive_file, 'Document', _pickDocument),
                _attachmentOption(Icons.poll, 'Poll', () {}),
              ],
            ),
          ),
        Container(
          color: Color(0xFF1F2C34),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.add, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _showAttachmentOptions = !_showAttachmentOptions;
                  });
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: Colors.grey),
                onPressed: () {
                  if (_messageController.text.isNotEmpty) {
                    widget.onSendMessage(_messageController.text);
                    _messageController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attachmentOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}