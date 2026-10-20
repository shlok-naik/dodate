// The Dodate planner: turns tasks (due date + size + ordered stages) into a
// per-day plan. Pure Dart, no Flutter, so it can be unit tested.
//
// The plan is never stored as the source of truth. It is rebuilt from the
// current state (remaining work per stage, work logged today, blocked days)
// every time, starting from today. That is what makes rebalancing automatic:
// unfinished work from a missed day is still "remaining", so it is spread
// over the days left; a stage that needs longer just has a bigger estimate.
//
// Algorithm:
// 1. Tasks are handled earliest deadline first (EDF), which is the order that
//    gives every deadline the best chance of fitting.
// 2. A task's work window runs from today to its last work day (the due day
//    itself only counts, at half capacity, if the task is due at or after
//    12:00, i.e. there's a morning to work in).
// 3. Each stage's remaining time is cut into sessions of at most
//    [maxSessionMinutes] (or the daily limit, if lower). Sessions keep stage
//    order.
// 4. Sessions are assigned to days in order (never earlier than the previous
//    session) by an exact dynamic program that minimises the sum of squared
//    daily loads (balance), with a heavy penalty for going over the daily
//    limit, a heavier one for blocked days, and a slight preference for
//    earlier days (to discourage cramming).
// 5. If the task can't fit under the daily limit, it gets a warning as soon as
//    it is added, not on the night before.

import 'dart:math' as math;

import 'dates.dart';
import 'models.dart';

const int defaultDailyLimit = 180;
const int maxSessionMinutes = 120;
const int minStageMinutes = 15;

enum WarningType { notEnoughTime, overdue }

class PlanWarning {
  PlanWarning(this.taskId, this.type, this.headline, this.message, {this.shortfall = 0});
  final String taskId;
  final WarningType type;

  /// Short title, e.g. 'History essay needs more time'.
  final String headline;

  /// What is wrong and what the student can do about it.
  final String message;
  final int shortfall;
}

class Plan {
  Plan(this.days, this.warnings);

  /// date -> work planned that day (only today and later).
  final Map<String, List<PlannedItem>> days;
  final List<PlanWarning> warnings;

  List<PlannedItem> itemsOn(String date) => days[date] ?? const [];
  int plannedMinutesOn(String date) => itemsOn(date).fold(0, (a, i) => a + i.minutes);
}

/// Splits [total] into [n] near-equal parts, in 5-minute steps when possible.
List<int> splitEven(int total, int n) {
  final step = total % 5 == 0 ? 5 : 1;
  final units = total ~/ step, base = units ~/ n, extra = units % n;
  return [for (var i = 0; i < n; i++) (base + (i < extra ? 1 : 0)) * step];
}

/// Resolves per-stage minutes. [given] has one entry per stage: the minutes the
/// student entered, or null. Unspecified stages share what is left of the
/// size's total equally (at least [minStageMinutes] each).
List<int> splitStageMinutes(int total, List<int?> given) {
  if (given.isEmpty) return [total];
  final missing = given.where((g) => g == null).length;
  if (missing == 0) return given.cast<int>();
  final specified = given.whereType<int>().fold(0, (a, b) => a + b);
  var pool = math.max(total - specified, minStageMinutes * missing);
  pool = ((pool + 4) ~/ 5) * 5;
  final shares = splitEven(pool, missing);
  var next = 0;
  return [for (final g in given) g ?? shares[next++]];
}

int loggedMinutes(String stageId, List<WorkLog> logs) =>
    logs.where((l) => l.stageId == stageId).fold(0, (a, l) => a + l.minutes);

int remainingMinutes(Stage stage, List<WorkLog> logs) =>
    stage.done ? 0 : math.max(0, stage.minutes - loggedMinutes(stage.id, logs));

int remainingForTask(Task task, List<WorkLog> logs) =>
    task.stages.fold(0, (a, s) => a + remainingMinutes(s, logs));

/// The last day work can be scheduled for [task].
String lastWorkDay(Task task) =>
    task.dueTime.compareTo('12:00') >= 0 ? task.dueDate : addDays(task.dueDate, -1);

bool isOverdue(Task task, String today, String nowTime) =>
    task.dueDate.compareTo(today) < 0 ||
    (task.dueDate == today && task.dueTime.compareTo(nowTime) <= 0);

class _Session {
  _Session(this.stage, this.minutes);
  final Stage stage;
  final int minutes;
}

class _Day {
  _Day(this.date, this.load, this.cap, this.blocked);
  final String date;
  final int load;
  final int cap;
  final bool blocked;
}

Plan buildPlan({
  required List<Task> tasks,
  required List<WorkLog> logs,
  required String today,
  String nowTime = '00:00',
  int dailyLimit = defaultDailyLimit,
  Set<String> blockedDates = const {},
}) {
  final days = <String, List<PlannedItem>>{};
  final loads = <String, int>{};
  final warnings = <PlanWarning>[];

  // Work already done today counts toward today's load.
  for (final l in logs.where((l) => l.date == today)) {
    loads[today] = (loads[today] ?? 0) + l.minutes;
  }

  final active = tasks.where((t) => !t.completed && remainingForTask(t, logs) > 0).toList()
    ..sort((a, b) {
      final c = '${a.dueDate}T${a.dueTime}'.compareTo('${b.dueDate}T${b.dueTime}');
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });

  for (final task in active) {
    final remaining = remainingForTask(task, logs);
    final overdue = isOverdue(task, today, nowTime);

    final window = <_Day>[];
    if (overdue) {
      window.add(_Day(today, loads[today] ?? 0, dailyLimit, false));
    } else {
      final last = lastWorkDay(task);
      final n = math.max(0, diffDays(today, last)) + 1;
      for (var i = 0; i < n; i++) {
        final d = addDays(today, i);
        final blocked = blockedDates.contains(d);
        final cap = blocked ? 0 : (d == task.dueDate ? dailyLimit ~/ 2 : dailyLimit);
        window.add(_Day(d, loads[d] ?? 0, cap, blocked));
      }
    }

    final sessionCap = math.min(maxSessionMinutes, dailyLimit);
    final sessions = <_Session>[
      for (final s in task.stages)
        if (remainingMinutes(s, logs) > 0)
          for (final m in splitEven(remainingMinutes(s, logs),
              (remainingMinutes(s, logs) / sessionCap).ceil()))
            _Session(s, m),
    ];

    final assignment = _placeSessions(sessions, window);
    var overflow = 0;
    final added = <String, int>{};
    for (var i = 0; i < sessions.length; i++) {
      final day = window[assignment[i]];
      final s = sessions[i];
      final list = days.putIfAbsent(day.date, () => []);
      // Consecutive sessions of the same stage on one day become one block.
      if (list.isNotEmpty && list.last.stageId == s.stage.id) {
        list.last.minutes += s.minutes;
      } else {
        list.add(PlannedItem(
          taskId: task.id,
          stageId: s.stage.id,
          taskTitle: task.title,
          stageName: s.stage.name,
          minutes: s.minutes,
        ));
      }
      added[day.date] = (added[day.date] ?? 0) + s.minutes;
    }
    for (final day in window) {
      final add = added[day.date] ?? 0;
      if (add == 0) continue;
      overflow += math.max(0, day.load + add - day.cap) - math.max(0, day.load - day.cap);
      loads[day.date] = day.load + add;
    }

    if (overdue) {
      warnings.add(PlanWarning(task.id, WarningType.overdue, '${task.title} is past its deadline',
          '${formatMinutes(remaining)} is left. It\'s on today\'s list. Mark it complete if you\'ve handed it in.',
          shortfall: remaining));
    } else if (overflow > 0) {
      final free = window.fold(0, (a, d) => a + math.max(0, d.cap - d.load));
      final shortfall = math.max(overflow, remaining - free);
      // remaining <= free happens when the time fits in total but the
      // sessions can't be split finely enough to stay under the limit.
      final detail = remaining > free
          ? 'It has ${formatMinutes(remaining)} of work but only ${formatMinutes(free)} fits under your '
              '${formatMinutes(dailyLimit)}-a-day limit before it\'s due, so some days go over.'
          : 'Its ${formatMinutes(remaining)} of work only just fits before it\'s due, so some days go '
              'over your ${formatMinutes(dailyLimit)}-a-day limit.';
      warnings.add(PlanWarning(task.id, WarningType.notEnoughTime, '${task.title} needs more time',
          '$detail Start today, trim a stage, or ask for an extension.',
          shortfall: shortfall));
    }
  }

  return Plan(days, warnings);
}

double _blockCost(_Day day, int index, int minutes) {
  final before = day.load, after = day.load + minutes;
  var cost = (after * after - before * before).toDouble();
  cost += 1e6 * (math.max(0, after - day.cap) - math.max(0, before - day.cap));
  if (day.blocked) cost += 1e9 * minutes;
  cost += 0.1 * index * minutes; // slight preference for earlier days
  return cost;
}

/// Exact DP: assigns ordered sessions to days with non-decreasing day index.
/// best[i][j] = min cost of placing sessions [0, i) on days [0, j].
/// Returns the day index for each session.
List<int> _placeSessions(List<_Session> sessions, List<_Day> days) {
  final k = sessions.length, n = days.length;
  if (k == 0) return const [];
  final prefix = [0];
  for (final s in sessions) {
    prefix.add(prefix.last + s.minutes);
  }
  const inf = double.infinity;
  final best = List.generate(k + 1, (_) => List.filled(n, inf));
  // from[i][j] = -1: day j unused (same as best[i][j-1]); otherwise the
  // first session index placed on day j.
  final from = List.generate(k + 1, (_) => List.filled(n, -1));

  for (var j = 0; j < n; j++) {
    for (var i = 0; i <= k; i++) {
      double prev(int a) => j > 0 ? best[a][j - 1] : (a == 0 ? 0 : inf);
      var b = prev(i);
      var choice = -1;
      for (var a = 0; a < i; a++) {
        final p = prev(a);
        if (p == inf) continue;
        final c = p + _blockCost(days[j], j, prefix[i] - prefix[a]);
        if (c < b) {
          b = c;
          choice = a;
        }
      }
      best[i][j] = b;
      from[i][j] = choice;
    }
  }

  final result = List.filled(k, 0);
  var i = k;
  for (var j = n - 1; j >= 0 && i > 0; j--) {
    final a = from[i][j];
    if (a == -1) continue;
    for (var s = a; s < i; s++) {
      result[s] = j;
    }
    i = a;
  }
  return result;
}
