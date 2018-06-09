import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arya_fitness/model/user_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

final auth = FirebaseAuth.instance;
final googleSignIn = new GoogleSignIn();
final ref = Firestore.instance.collection('Users');
final refNotifications = Firestore.instance.collection('Notifications');

User currentUserModel;
String pushToken = '';
bool admin = false;

Future<Null> _ensureLoggedIn(BuildContext context) async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    user = await googleSignIn.signInSilently();
  }
  if (user == null) {
    await googleSignIn.signIn().then((_) {
      tryCreateUserRecord(context);
    });
  }

  await getUserRecord(context);

  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(
        idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}

Future<Null> _silentLogin(BuildContext context) async {
  GoogleSignInAccount user = googleSignIn.currentUser;

  if (user == null) {
    user = await googleSignIn.signInSilently().then((_) {
      tryCreateUserRecord(context);
    });
  }

  await getUserRecord(context);

  if (await auth.currentUser() == null && user != null) {
    GoogleSignInAuthentication credentials =
        await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(
        idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}

tryCreateUserRecord(BuildContext context) async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    return null;
  }
  DocumentSnapshot userRecord = await ref.document(user.id).get();
  if (userRecord.data == null) {
    // no user record exists, time to create

    ref.document(user.id).setData({
      "id": user.id,
      "photoUrl": user.photoUrl,
      "email": user.email,
      "displayName": user.displayName,
      "pushToken": pushToken,
      "admin": false,
    });
//    }
  }

  currentUserModel = new User.fromDocument(userRecord);
}

getUserRecord(BuildContext context) async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    return null;
  }
  DocumentSnapshot userRecord = await ref.document(user.id).get();
  if (userRecord.data != null) {
    admin = userRecord.data['admin'];
  }
  return;
}

class AryaFitness extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Arya Fitness',
      theme: new ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        accentColor: Colors.cyan[600],
      ),
      home: new HomePage(title: 'Arya Fitness'),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _HomePageState createState() => new _HomePageState();
}

//PageController pageController;

class _HomePageState extends State<HomePage> {
//  int _page = 0;
  bool triedSilentLogin = false;
  FirebaseMessaging _firebaseMessaging = new FirebaseMessaging();
  final titleController = new TextEditingController();
  final messageController = new TextEditingController();

  Future<Null> sendNotification() async {
    final DocumentReference document = refNotifications.document();
    document.setData(<String, dynamic>{
      'title': titleController.text,
      'message': messageController.text,
      'time': new DateTime.now().millisecondsSinceEpoch,
    });
    messageController.clear();
    titleController.clear();
  }

  @override
  void dispose() {
    // Clean up the controller when the Widget is disposed
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) {
        print('on message $message');
      },
      onResume: (Map<String, dynamic> message) {
        print('on resume $message');
      },
      onLaunch: (Map<String, dynamic> message) {
        print('on launch $message');
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.getToken().then((token) {
      print(token);
      pushToken = token;
    });
  }

  Scaffold buildLoginPage() {
    return new Scaffold(
      body: new Center(
        child: new Padding(
          padding: const EdgeInsets.only(top: 100.0),
          child: new Column(
            children: <Widget>[
              new Image.asset(
                'assets/images/aryaoriginallogo.png',
                width: 350.0,
                fit: BoxFit.cover,
              ),
              new Padding(padding: const EdgeInsets.only(bottom: 60.0)),
              new GestureDetector(
                onTap: login,
                child: new Image.asset(
                  "assets/images/google_signin_button.png",
                  width: 225.0,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (triedSilentLogin == false) {
      silentLogin(context);
    }
    return googleSignIn.currentUser == null
        ? buildLoginPage()
        : new Scaffold(
            // Appbar
            appBar: new AppBar(
                // Title
                title: Text("Hello ${googleSignIn.currentUser.displayName}")),
            floatingActionButton: admin == false ? null : new FloatingActionButton.extended(
              key: new ValueKey<Key>(new Key('1')),
              tooltip: 'Show explanation',
              backgroundColor: Colors.blue,
              icon: new Icon(Icons.message), //page.fabIcon,
              label: Text('Send Notification'),
              onPressed: _showDialog,
            ),

            // Body
            body: new StreamBuilder(
                stream: Firestore.instance
                    .collection('Notifications')
                    .limit(5)
                    .orderBy('time')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text('Loading...');
                  return new ListView.builder(
                    itemCount: snapshot.data.documents.length,
                    padding: const EdgeInsets.all(15.0),
                    itemExtent: 120.0,
                    itemBuilder: (context, index) =>
                        _buildListItem(context, snapshot.data.documents[index]),
                  );
                }));
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot document) {
    return new Column(children: <Widget>[
      new Container(
          decoration: new BoxDecoration(
            color: Colors.black54,
            border: new Border.all(color: const Color(0x80000000)),
            borderRadius: new BorderRadius.circular(16.0),
          ),
          padding: const EdgeInsets.all(15.0),
          child: new ListTile(
            leading: new Icon(Icons.message),
            key: new ValueKey(document.documentID),
            title: new Text(document['title'],
                style: new TextStyle(color: Colors.white)),
            subtitle: new Text(document['message'],
                style: new TextStyle(color: Colors.white)),
            onTap: () => null,
          )),
      const Divider(
        height: 5.0,
      ),
    ]);
  }

  _showDialog() async {
    await showDialog<String>(
      context: context,
      child: new AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        content: new Column(
          children: <Widget>[
            new Expanded(
                child: new TextField(
              controller: titleController,
              maxLines: 1,
              autofocus: true,
              decoration: new InputDecoration(
                icon: new Icon(Icons.title),
              ),
            )),
            new Expanded(
                child: new TextField(
              controller: messageController,
              maxLines: 3,
              autofocus: true,
              decoration: new InputDecoration(
                icon: new Icon(Icons.message),
              ),
            ))
          ],
        ),
        actions: <Widget>[
          new FlatButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.pop(context);
              }),
          new FlatButton(
              child: const Text('SEND'),
              onPressed: () {
                sendNotification();
                Navigator.pop(context);
              })
        ],
      ),
    );
  }

  void login() async {
    await _ensureLoggedIn(context);
    setState(() {
      triedSilentLogin = true;
    });
  }

  void silentLogin(BuildContext context) async {
    await _silentLogin(context);
    setState(() {triedSilentLogin = true;});
  }
}

void main() => runApp(new AryaFitness());
