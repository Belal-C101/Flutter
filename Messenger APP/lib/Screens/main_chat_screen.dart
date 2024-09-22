import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/Login.dart';
import 'package:intl/intl.dart';
import 'Welcome_Screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Contacts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Clone',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(backgroundColor: Colors.black),
      ),
      home: ContactsPage(),
    );
  }
}

class ContactsPage extends StatelessWidget {
  final List<Contact> contacts = [
    Contact('Mohamed Hesham', 'Tap to view the Mohamed Hesham', 'Now', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.camera_alt_outlined), onPressed: () {}),
          IconButton(icon: Icon(Icons.add, color: Colors.green), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildContactList(context)),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          _filterChip('All', isSelected: true),
          SizedBox(width: 8),
          _filterChip('Unread'),
          SizedBox(width: 8),
          _filterChip('Favorites'),
          SizedBox(width: 8),
          _filterChip('Groups'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, {bool isSelected = false}) {
    return Chip(
      label: Text(label),
      backgroundColor: isSelected ? Colors.green : Colors.grey[800],
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
    );
  }

  Widget _buildContactList(BuildContext context) {
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        return _buildContactListTile(context, contacts[index]);
      },
    );
  }

  Widget _buildContactListTile(BuildContext context, Contact contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:AssetImage('assets/img/Mohamed.jpg'),
        radius: 25,
      ),
      title: Text(contact.name),
      subtitle: Row(
        children: [
          if (contact.isVerified) Icon(Icons.check, color: Colors.blue, size: 16),
          Expanded(
            child: Text(
              contact.lastMessage,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(contact.timestamp, style: TextStyle(color: Colors.grey, fontSize: 12)),
          if (contact.unreadCount > 0)
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Text(
                contact.unreadCount.toString(),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      onTap: () {
        if (contact.name == 'Mohamed Hesham') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen(contact: contact)),
          );
        }
      },
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.update), label: 'Updates'),
        BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Communities'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      onTap: (index) {
        if (index == 4) { // Settings icon
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          );
        }
      },
    );
  }
}

class Contact {
  final String name;
  final String lastMessage;
  final String timestamp;
  final bool isVerified;
  final int unreadCount;

  Contact(this.name, this.lastMessage, this.timestamp, this.isVerified, {this.unreadCount = 0});
}

class ChatScreen extends StatelessWidget {
  final Contact contact;

  ChatScreen({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
      ),
      body: Center(
        child: Text('Chat with ${contact.name}'),
      ),
    );
  }

  Widget _buildDateBubble(BuildContext context, String date) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            date,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User data not found'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final username = userData['username'] as String? ?? 'User Name';

          return ListView(
            children: [
              _buildProfileCard(user, username),
              _buildSettingsGroup([
                _buildSettingsItem(Icons.favorite, 'Favorites'),
                _buildSettingsItem(Icons.campaign, 'Broadcast lists'),
                _buildSettingsItem(Icons.star, 'Starred messages'),
                _buildSettingsItem(Icons.computer, 'Linked devices'),
              ]),
              _buildSettingsGroup([
                _buildSettingsItem(Icons.key, 'Account'),
                _buildSettingsItem(Icons.lock, 'Privacy'),
                _buildSettingsItem(Icons.chat_bubble, 'Chats'),
                _buildSettingsItem(Icons.notifications, 'Notifications'),
                _buildSettingsItem(Icons.logout, 'Sign Out', onTap: () => _signOut(context)),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(User? user, String username) {
    return Card(
      color: Color(0xFF1F2C34),
      margin: EdgeInsets.all(8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(username, style: TextStyle(color: Colors.white)),
        subtitle: Text(user?.email ?? 'Email not available', style: TextStyle(color: Colors.grey)),
        trailing: Icon(Icons.qr_code, color: Colors.grey),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> items) {
    return Card(
      color: Color(0xFF1F2C34),
      margin: EdgeInsets.all(8),
      child: Column(children: items),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: TextStyle(color: Colors.white)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }
}