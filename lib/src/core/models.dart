/// Task sizes and the total time each stands for when the student gives no
/// stage times. Assumed values; tune here.
enum TaskSize {
  quick('Quick', 30),
  medium('Medium', 90),
  big('Big', 180),
  huge('Huge', 360);

  const TaskSize(this.label, this.minutes);
  final String label;
  final int minutes;
}

class Stage {
  Stage({required this.id, required this.name, required this.minutes, this.done = false});

  final String id;
  final String name;

  /// Estimated total minutes. Grows when the student reports it needs longer.
  int minutes;

  /// Finished explicitly (possibly in less than the estimate).
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'minutes': minutes, 'done': done};

  factory Stage.fromJson(Map<String, dynamic> j) =>
      Stage(id: j['id'], name: j['name'], minutes: j['minutes'], done: j['done'] ?? false);
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.dueTime,
    required this.size,
    required this.stages,
    required this.createdAt,
    this.completed = false,
  });

  final String id;
  final String title;
  final String dueDate; // YYYY-MM-DD
  final String dueTime; // HH:MM
  final TaskSize size;
  final List<Stage> stages;
  final String createdAt; // ISO timestamp, tie-breaker for ordering
  bool completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueDate': dueDate,
        'dueTime': dueTime,
        'size': size.name,
        'stages': stages.map((s) => s.toJson()).toList(),
        'createdAt': createdAt,
        'completed': completed,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'],
        dueDate: j['dueDate'],
        dueTime: j['dueTime'],
        size: TaskSize.values.byName(j['size']),
        stages: (j['stages'] as List).map((s) => Stage.fromJson(s)).toList(),
        createdAt: j['createdAt'],
        completed: j['completed'] ?? false,
      );
}

/// Work the student actually did on a stage on a given day.
class WorkLog {
  WorkLog({required this.taskId, required this.stageId, required this.date, required this.minutes});

  final String taskId;
  final String stageId;
  final String date;
  final int minutes;

  Map<String, dynamic> toJson() =>
      {'taskId': taskId, 'stageId': stageId, 'date': date, 'minutes': minutes};

  factory WorkLog.fromJson(Map<String, dynamic> j) =>
      WorkLog(taskId: j['taskId'], stageId: j['stageId'], date: j['date'], minutes: j['minutes']);
}

/// One block of work the plan puts on a day.
class PlannedItem {
  PlannedItem({
    required this.taskId,
    required this.stageId,
    required this.taskTitle,
    required this.stageName,
    required this.minutes,
  });

  final String taskId;
  final String stageId;
  final String taskTitle;
  final String stageName;
  int minutes;

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'stageId': stageId,
        'taskTitle': taskTitle,
        'stageName': stageName,
        'minutes': minutes,
      };

  factory PlannedItem.fromJson(Map<String, dynamic> j) => PlannedItem(
        taskId: j['taskId'],
        stageId: j['stageId'],
        taskTitle: j['taskTitle'],
        stageName: j['stageName'],
        minutes: j['minutes'],
      );
}
