import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/dates.dart';
import 'core/models.dart';
import 'core/scheduler.dart';

const _storageKey = 'dodate.v1';

/// What one day shows in the week view.
class DayEntry {
  DayEntry.planned(this.item) : status = EntryStatus.planned, loggedMinutes = 0;
  DayEntry.done(this.item, this.loggedMinutes) : status = EntryStatus.done;
  DayEntry.missed(this.item) : status = EntryStatus.missed, loggedMinutes = 0;

  final PlannedItem item;
  final EntryStatus status;
  final int loggedMinutes;
}

enum EntryStatus { planned, done, missed }

/// All app data plus the derived plan. Persists to shared_preferences as JSON.
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  SharedPreferences? _prefs;

  List<Task> tasks = [];
  List<WorkLog> logs = [];
  Set<String> blockedDates = {};
  int dailyLimit = defaultDailyLimit;

  /// The last plan seen for each day. Past days keep theirs, so work that was
  /// planned but never logged can be shown as missed (it has already been
  /// moved forward by the planner).
  Map<String, List<PlannedItem>> snapshots = {};

  Plan? _plan;
  String? _planDay;
  int _idCounter = 0;

  String get today => dateOf(_clock());
  String get nowTime => timeOf(_clock());

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      tasks = (j['tasks'] as List).map((t) => Task.fromJson(t)).toList();
      logs = (j['logs'] as List).map((l) => WorkLog.fromJson(l)).toList();
      blockedDates = Set<String>.from(j['blockedDates'] ?? const []);
      dailyLimit = j['dailyLimit'] ?? defaultDailyLimit;
      snapshots = (j['snapshots'] as Map<String, dynamic>? ?? {}).map((d, items) =>
          MapEntry(d, (items as List).map((i) => PlannedItem.fromJson(i)).toList()));
    }
    await _changed();
  }

  /// Re-plans from the current time (e.g. when the app returns on a new day).
  Future<void> refresh() => _changed();

  Plan get plan {
    if (_plan == null || _planDay != today) _recompute();
    return _plan!;
  }

  void _recompute() {
    final t = today;
    _plan = buildPlan(
      tasks: tasks,
      logs: logs,
      today: t,
      nowTime: nowTime,
      dailyLimit: dailyLimit,
      blockedDates: blockedDates,
    );
    _planDay = t;
    // Overwrite snapshots from today on; keep the past; drop very old ones.
    snapshots.removeWhere((d, _) => d.compareTo(t) >= 0 || diffDays(d, t) > 60);
    snapshots.addAll(_plan!.days);
  }

  Future<void> _changed() async {
    _recompute();
    notifyListeners();
    await _prefs?.setString(
      _storageKey,
      jsonEncode({
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'logs': logs.map((l) => l.toJson()).toList(),
        'blockedDates': blockedDates.toList(),
        'dailyLimit': dailyLimit,
        'snapshots': snapshots.map((d, items) => MapEntry(d, items.map((i) => i.toJson()).toList())),
      }),
    );
  }

  String _newId() => '${_clock().microsecondsSinceEpoch}-${_idCounter++}-${math.Random().nextInt(1 << 30)}';

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Stage? stageById(String taskId, String stageId) {
    for (final s in taskById(taskId)?.stages ?? const <Stage>[]) {
      if (s.id == stageId) return s;
    }
    return null;
  }

  /// [stages]: (name, minutes or null). Empty means one stage covering the task.
  Future<Task> addTask({
    required String title,
    required String dueDate,
    required String dueTime,
    required TaskSize size,
    List<(String, int?)> stages = const [],
  }) async {
    final named = stages.where((s) => s.$1.trim().isNotEmpty).toList();
    final minutes = splitStageMinutes(size.minutes, [for (final s in named) s.$2]);
    final names = named.isEmpty ? ['Work'] : [for (final s in named) s.$1.trim()];
    final task = Task(
      id: _newId(),
      title: title.trim(),
      dueDate: dueDate,
      dueTime: dueTime,
      size: size,
      stages: [
        for (var i = 0; i < names.length; i++)
          Stage(id: _newId(), name: names[i], minutes: minutes[i]),
      ],
      createdAt: _clock().toIso8601String(),
    );
    tasks.add(task);
    await _changed();
    return task;
  }

  /// Records [minutes] of work on a stage, today.
  Future<void> logWork(String taskId, String stageId, int minutes) async {
    if (minutes <= 0) return;
    logs.add(WorkLog(taskId: taskId, stageId: stageId, date: today, minutes: minutes));
    await _changed();
  }

  /// The stage is finished, even if it took less than estimated.
  Future<void> finishStage(String taskId, String stageId) async {
    stageById(taskId, stageId)?.done = true;
    await _changed();
  }

  /// The stage is taking longer: grow its estimate so the rest is replanned.
  Future<void> addTime(String taskId, String stageId, int minutes) async {
    final stage = stageById(taskId, stageId);
    if (stage == null || minutes <= 0) return;
    stage.minutes += minutes;
    stage.done = false;
    await _changed();
  }

  Future<void> completeTask(String taskId) async {
    taskById(taskId)?.completed = true;
    await _changed();
  }

  Future<void> deleteTask(String taskId) async {
    tasks.removeWhere((t) => t.id == taskId);
    logs.removeWhere((l) => l.taskId == taskId);
    for (final items in snapshots.values) {
      items.removeWhere((i) => i.taskId == taskId);
    }
    await _changed();
  }

  /// Marks a day as one the student can't work on (or undoes that).
  Future<void> toggleBlocked(String date) async {
    if (!blockedDates.remove(date)) blockedDates.add(date);
    await _changed();
  }

  Future<void> setDailyLimit(int minutes) async {
    if (minutes <= 0) return;
    dailyLimit = minutes;
    await _changed();
  }

  int loggedFor(String stageId) => loggedMinutes(stageId, logs);

  /// Entries for one day. Past days: logged work plus planned work that was
  /// never done (missed, already moved forward). Today: work logged today
  /// plus the plan. Future days: the plan.
  List<DayEntry> entriesFor(String date) {
    final t = today;
    final entries = <DayEntry>[];
    if (date.compareTo(t) <= 0) {
      final logged = <String, int>{};
      for (final l in logs.where((l) => l.date == date)) {
        logged[l.stageId] = (logged[l.stageId] ?? 0) + l.minutes;
      }
      for (final e in logged.entries) {
        final stage = _findStage(e.key);
        if (stage == null) continue;
        entries.add(DayEntry.done(
          PlannedItem(
            taskId: stage.$1.id,
            stageId: e.key,
            taskTitle: stage.$1.title,
            stageName: stage.$2.name,
            minutes: e.value,
          ),
          e.value,
        ));
      }
      if (date.compareTo(t) < 0) {
        for (final item in snapshots[date] ?? const <PlannedItem>[]) {
          if (!logged.containsKey(item.stageId)) entries.add(DayEntry.missed(item));
        }
        return entries;
      }
    }
    entries.addAll(plan.itemsOn(date).map(DayEntry.planned));
    return entries;
  }

  (Task, Stage)? _findStage(String stageId) {
    for (final t in tasks) {
      for (final s in t.stages) {
        if (s.id == stageId) return (t, s);
      }
    }
    return null;
  }
}
