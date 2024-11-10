import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Management App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String email = '', password = '';

  void _login() async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TaskListScreen()),
      );
    } catch (e) {
      print(e); // Error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => email = value,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              onChanged: (value) => password = value,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            ElevatedButton(onPressed: _login, child: Text("Login"))
          ],
        ),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();

  void _addTask(String taskName) async {
    if (taskName.isEmpty) return;
    await _firestore.collection('tasks').add({
      'name': taskName,
      'completed': false,
      'user': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp()
    });
    _taskController.clear();
  }

  void _toggleTaskCompletion(DocumentSnapshot task) async {
    await _firestore.collection('tasks').doc(task.id).update({
      'completed': !task['completed'],
    });
  }

  void _deleteTask(DocumentSnapshot task) async {
    await _firestore.collection('tasks').doc(task.id).delete();
  }

  void _addTaskWithTime(String taskName, String day, String timeFrame) async {
    if (taskName.isEmpty) return;
    await _firestore.collection('tasks').doc(day).collection('timeframes').add({
      'name': taskName,
      'completed': false,
      'user': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Widget _buildNestedList() {
    return StreamBuilder(
      stream: _firestore.collection('tasks').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        return ListView(
          children: snapshot.data!.docs.map((dayDoc) {
            return ExpansionTile(
              title: Text(dayDoc.id),
              children: [
                StreamBuilder(
                  stream: dayDoc.reference.collection('timeframes').snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> timeSnapshot) {
                    if (!timeSnapshot.hasData) return Container();
                    return Column(
                      children: timeSnapshot.data!.docs.map((timeDoc) {
                        return ListTile(
                          title: Text(timeDoc['name']),
                          leading: Checkbox(
                            value: timeDoc['completed'],
                            onChanged: (_) => _toggleTaskCompletion(timeDoc),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteTask(timeDoc),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Task List"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(labelText: "New Task"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _addTask(_taskController.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('tasks')
                  .where('user', isEqualTo: _auth.currentUser?.uid)
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return ListView(
                  children: snapshot.data!.docs.map((task) {
                    return ListTile(
                      title: Text(task['name']),
                      leading: Checkbox(
                        value: task['completed'],
                        onChanged: (_) => _toggleTaskCompletion(task),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteTask(task),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Expanded(child: _buildNestedList()), // Display nested list of tasks
        ],
      ),
    );
  }
}
