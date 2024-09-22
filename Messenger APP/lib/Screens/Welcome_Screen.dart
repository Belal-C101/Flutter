import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  late User _signedInUser;
  String _username = '';
  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String _recordingPath = '';
  Timer? _timer;
  int _recordDuration = 0;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _signedInUser = user;
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_signedInUser.uid).get();
        setState(() {
          _username = userDoc.get('username') ?? 'User';
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _requestMicrophonePermission() async {
    PermissionStatus status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Microphone permission is required to record audio.')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        Directory tempDir = await getTemporaryDirectory();
        _recordingPath =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(RecordConfig(), path: _recordingPath);
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _startTimer();
      } else {
        _requestMicrophonePermission();
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingPath = path ?? '';
    });
    if (path != null) {
      _uploadVoiceMessage();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  String _formatDuration(int duration) {
    final minutes = (duration / 60).floor().toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _uploadVoiceMessage() async {
    try {
      final ref = _storage
          .ref()
          .child('audio/${DateTime.now().millisecondsSinceEpoch}.m4a');
      await ref.putFile(File(_recordingPath));
      final url = await ref.getDownloadURL();

      await _firestore.collection('messages').add({
        'audio_url': url,
        'sender': _username,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error uploading voice message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send voice message. Please try again.')),
      );
    }
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo),
                title: Text('Photos'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.location_on),
                title: Text('Location'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLocation();
                },
              ),
              ListTile(
                leading: Icon(Icons.contact_phone),
                title: Text('Contact'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement contact sharing logic
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text('Document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
              ListTile(
                leading: Icon(Icons.poll),
                title: Text('Poll'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement poll creation logic
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final permission =
        source == ImageSource.camera ? Permission.camera : Permission.photos;

    if (await permission.request().isGranted) {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        _uploadFile(File(pickedFile.path), 'images');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission denied')),
      );
    }
  }

  Future<void> _pickDocument() async {
    if (await Permission.storage.request().isGranted) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        _uploadFile(file, 'documents');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission denied')),
      );
    }
  }

  Future<void> _shareLocation() async {
    if (await Permission.location.request().isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition();
        _firestore.collection('messages').add({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'sender': _username,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission denied')),
      );
    }
  }

  Future<void> _uploadFile(File file, String folderName) async {
    try {
      final ref = _storage.ref().child(
          '$folderName/${DateTime.now().millisecondsSinceEpoch}${file.path.split('.').last}');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _firestore.collection('messages').add({
        'file_url': url,
        'file_type': folderName,
        'file_name': file.path.split('/').last,
        'sender': _username,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF1F2C34),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: AssetImage('assets/img/Mohamed.jpg'),
              radius: 20,
            ),
            SizedBox(width: 8),
            Flexible(
                child: Text('Mohamed Hesham',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white))),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam, color: Colors.grey),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.phone, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/img/Gojo.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child:  StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('messages')
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs.reversed;
                  List<Widget> messageBubbles = [];
                  for (var message in messages) {
                    final messageData = message.data() as Map<String, dynamic>;
                    final messageSender =
                        messageData['sender'] as String? ?? 'Unknown';
                    final currentUser = _username;
                    final timestamp =
                        (messageData['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now();

                    Widget messageContent;
                    if (messageData.containsKey('text')) {
                      messageContent = Text(
                        messageData['text'] as String? ?? '',
                        style: TextStyle(color: Colors.white, fontSize: 15.0),
                      );
                    } else if (messageData.containsKey('audio_url')) {
                      messageContent = AudioPlayerWidget(
                        audioUrl: messageData['audio_url'] as String? ?? '',
                        timestamp: timestamp,
                      );
                    } else if (messageData.containsKey('file_url')) {
                      messageContent = DocumentMessageWidget(
                        fileUrl: messageData['file_url'] as String? ?? '',
                        fileName: messageData['file_name'] as String? ??
                            'Unnamed File',
                        fileType: messageData['file_type'] as String? ??
                            'Unknown Type',
                      );
                    } else if (messageData.containsKey('latitude') &&
                        messageData.containsKey('longitude')) {
                      messageContent = Text(
                        'Location: ${messageData['latitude']}, ${messageData['longitude']}',
                        style: TextStyle(color: Colors.white, fontSize: 15.0),
                      );
                    } else {
                      continue; // Skip if message type is not recognized
                    }

                    final messageBubble = MessageBubble(
                      sender: messageSender,
                      content: messageContent,
                      isMe: currentUser == messageSender,
                    );

                    messageBubbles.add(messageBubble);
                  }

                  return ListView(
                    reverse: true,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                    children: messageBubbles,
                  );
                },
              ),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Color(0xFF1F2C34),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.grey),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF2A3942),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () {},
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
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Color(0xFF00A884),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white),
                onPressed: () {},
              ),
            ),
          ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                _formatDuration(_recordDuration),
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      try {
        _firestore.collection('messages').add({
          'text': _messageController.text,
          'sender': _username,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _messageController.clear();
      } catch (e) {
        print('Error sending message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    }
  }
}

class MessageBubble extends StatelessWidget {
  final String sender;
  final Widget content;
  final bool isMe;

  MessageBubble({
    required this.sender,
    required this.content,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            sender,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          Material(
            borderRadius: isMe
                ? BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  )
                : BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
            elevation: 5.0,
            color: isMe ? Colors.lightBlueAccent : Colors.grey[800],
            child:Padding(
              padding: content is Text
                  ? EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0)
                  : EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final DateTime timestamp;

  AudioPlayerWidget({required this.audioUrl, required this.timestamp});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFF075E54),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Color.fromARGB(255, 196, 196, 196),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Color(0xFF075E54),
              ),
              onPressed: () async {
                if (isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play(UrlSource(widget.audioUrl));
                }
              },
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 3,
                  child: LinearProgressIndicator(
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds / _duration.inSeconds
                        : 0.0,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      DateFormat('h:mm a').format(widget.timestamp),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentMessageWidget extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final String fileType;

  DocumentMessageWidget({
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
  });

  Future<void> _openDocument() async {
    final Uri url = Uri.parse(fileUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print('Could not launch $url');
    }
  }

  Future<void> _previewFile(BuildContext context) async {
    if (fileType.toLowerCase().contains('image')) {
      _showImagePreview(context);
    } else if (fileType.toLowerCase().contains('pdf')) {
      await _showPdfPreview(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview not available for this file type')),
      );
    }
  }

  void _showImagePreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: CachedNetworkImage(
            imageUrl: fileUrl,
            placeholder: (context, url) => CircularProgressIndicator(),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
        );
      },
    );
  }

  Future<void> _showPdfPreview(BuildContext context) async {
    try {
      final url = Uri.parse(fileUrl);
      final response = await http.get(url);
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final tempDocumentPath = '${tempDir.path}/$fileName';
      final file = File(tempDocumentPath);
      await file.writeAsBytes(bytes);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('PDF Preview')),
            body: PDFView(
              filePath: tempDocumentPath,
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error previewing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to preview PDF. Please try again.')),
      );
    }
  }

  IconData _getFileTypeIcon() {
    if (fileType.toLowerCase().contains('image')) {
      return Icons.image;
    } else if (fileType.toLowerCase().contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (fileType.toLowerCase().contains('document')) {
      return Icons.description;
    } else {
      return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isImage = fileType.toLowerCase().contains('image');
    
    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: fileUrl,
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => Icon(Icons.error),
                fit: BoxFit.cover,
                height: 150,
                width: double.infinity,
              ),
            ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(_getFileTypeIcon(), color: Colors.white, size: 40),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      fileType,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!isImage)
                IconButton(
                  icon: Icon(Icons.remove_red_eye, color: Colors.white),
                  onPressed: () => _previewFile(context),
                ),
              IconButton(
                icon: Icon(Icons.download, color: Colors.white),
                onPressed: _openDocument,
              ),
            ],
          ),
        ],
      ),
    );
  }
}