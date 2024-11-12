import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase
import 'firebase_options.dart'; // Firebase initialization options


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/home', // Start directly with TaskListScreen
      routes: {
        '/home': (context) => const TaskListScreen(title: 'Task Manager'), // Home/Tasks page route
      },
    );
  }
}

// Task model class
class Task {
  String id;
  String name;
  bool completed;
  List<Map<String, String>> subtasks; // List of subtasks with time and task description

  Task({
    required this.id,
    required this.name,
    this.completed = false,
    this.subtasks = const [],
  });

  // Convert Task to Map for Firebase storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'completed': completed,
      'subtasks': subtasks,
    };
  }

  // Create Task from Firebase document
  static Task fromDocument(DocumentSnapshot doc) {
    return Task(
      id: doc.id,
      name: doc['name'],
      completed: doc['completed'],
      subtasks: List<Map<String, String>>.from(doc['subtasks'] ?? []),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, required this.title});

  final String title;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController taskController = TextEditingController();
  final CollectionReference tasksCollection = FirebaseFirestore.instance.collection('tasks');

  // Function to add a task to Firebase
  Future<void> _addTask() async {
    if (taskController.text.isNotEmpty) {
      final newTask = Task(id: '', name: taskController.text);
      await tasksCollection.add(newTask.toMap());
      taskController.clear();
    }
  }

  // Function to delete a task from Firebase
  Future<void> _deleteTask(String taskId) async {
    await tasksCollection.doc(taskId).delete();
  }

  // Function to toggle task completion in Firebase
  Future<void> _toggleTaskCompletion(Task task) async {
    await tasksCollection.doc(task.id).update({'completed': !task.completed});
  }

  // Function to add a subtask to Firebase
  Future<void> _addSubtask(String taskId, String timeFrame, String subtask) async {
    final taskDoc = tasksCollection.doc(taskId);
    final taskSnapshot = await taskDoc.get();
    final currentSubtasks = List<Map<String, String>>.from(taskSnapshot['subtasks'] ?? []);
    currentSubtasks.add({'timeFrame': timeFrame, 'task': subtask});
    await taskDoc.update({'subtasks': currentSubtasks});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: taskController,
              decoration: const InputDecoration(
                labelText: 'Enter main task',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Add Task'),
            ),
            const SizedBox(height: 20),
            Expanded(
              // Use StreamBuilder to listen to real-time updates from Firebase
              child: StreamBuilder<QuerySnapshot>(
                stream: tasksCollection.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  final tasks = snapshot.data!.docs.map((doc) => Task.fromDocument(doc)).toList();

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: task.completed,
                                        onChanged: (bool? value) {
                                          _toggleTaskCompletion(task);
                                        },
                                      ),
                                      Text(
                                        task.name,
                                        style: TextStyle(
                                          decoration: task.completed
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteTask(task.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Subtasks',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: task.subtasks.length,
                                itemBuilder: (context, subIndex) {
                                  final subtask = task.subtasks[subIndex];
                                  return ListTile(
                                    title: Text("${subtask['timeFrame']}: ${subtask['task']}"),
                                  );
                                },
                              ),
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Enter subtask and time (e.g., 9-10 am - Do HW)',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (value) {
                                  final parts = value.split(' - ');
                                  if (parts.length == 2) {
                                    _addSubtask(task.id, parts[0].trim(), parts[1].trim());
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
