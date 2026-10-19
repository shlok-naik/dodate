import 'package:dodate/src/core/dates.dart';
import 'package:dodate/src/core/models.dart';
import 'package:dodate/src/core/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-19 is a Monday.
const mon = '2026-10-19', tue = '2026-10-20', wed = '2026-10-21', thu = '2026-10-22', fri = '2026-10-23';

int _ids = 0;

Task task(String title, String dueDate, String dueTime, List<(String, int)> stages,
    {TaskSize size = TaskSize.big}) {
  return Task(
    id: 't${_ids++}',
    title: title,
    dueDate: dueDate,
    dueTime: dueTime,
    size: size,
    stages: [for (final s in stages) Stage(id: 's${_ids++}', name: s.$1, minutes: s.$2)],
    createdAt: '2026-10-01T00:00:${(_ids % 60).toString().padLeft(2, '0')}',
  );
}

Task essay() => task('History essay', fri, '14:00',
    [('Research', 45), ('Plan', 30), ('Write', 90), ('Edit', 30)]);

/// stageName -> date, for one task.
Map<String, String> placement(Plan plan, Task t) => {
      for (final e in plan.days.entries)
        for (final i in e.value.where((i) => i.taskId == t.id)) i.stageName: e.key,
    };

int totalFor(Plan plan, Task t) => plan.days.values
    .expand((items) => items)
    .where((i) => i.taskId == t.id)
    .fold(0, (a, i) => a + i.minutes);

void main() {
  group('equal stage-time splitting', () {
    test('splits a size equally when no stage times are given', () {
      expect(splitStageMinutes(180, [null, null, null, null]), [45, 45, 45, 45]);
    });

    test('keeps 5-minute steps and the exact total when it does not divide evenly', () {
      final parts = splitStageMinutes(90, [null, null, null, null]);
      expect(parts, [25, 25, 20, 20]);
      expect(parts.reduce((a, b) => a + b), 90);
    });

    test('given times are kept and the rest of the size is shared', () {
      expect(splitStageMinutes(180, [60, null, null]), [60, 60, 60]);
    });

    test('unspecified stages still get a minimum when given times use up the size', () {
      expect(splitStageMinutes(30, [40, null]), [40, 15]);
    });

    test('all times given: used as is; no stages: one stage for the whole size', () {
      expect(splitStageMinutes(180, [10, 20]), [10, 20]);
      expect(splitStageMinutes(360, []), [360]);
    });

    test('splitEven', () {
      expect(splitEven(360, 3), [120, 120, 120]);
      expect(splitEven(7, 2), [4, 3]);
    });
  });

  group('spreading across days', () {
    test('the essay example: one stage a day, Tuesday to Friday morning', () {
      final t = essay();
      final plan = buildPlan(tasks: [t], logs: [], today: tue);
      expect(placement(plan, t), {'Research': tue, 'Plan': wed, 'Write': thu, 'Edit': fri});
      expect(plan.warnings, isEmpty);
    });

    test('equal-split stages are spread one per day', () {
      final t = task('Essay', fri, '14:00', [('A', 45), ('B', 45), ('C', 45), ('D', 45)]);
      final plan = buildPlan(tasks: [t], logs: [], today: tue);
      for (final d in [tue, wed, thu, fri]) {
        expect(plan.plannedMinutesOn(d), 45, reason: d);
      }
    });

    test('stage order is respected', () {
      final t = task('Project', fri, '23:00',
          [('A', 100), ('B', 20), ('C', 150), ('D', 10), ('E', 60)]);
      final plan = buildPlan(tasks: [t], logs: [], today: mon);
      final order = ['A', 'B', 'C', 'D', 'E'];
      final p = placement(plan, t);
      for (var i = 1; i < order.length; i++) {
        expect(p[order[i - 1]]!.compareTo(p[order[i]]!) <= 0, isTrue, reason: '$p');
      }
    });

    test('no work is placed on the due day if it is due before noon', () {
      final t = task('Lab report', thu, '09:00', [('Write', 60), ('Check', 30)]);
      final plan = buildPlan(tasks: [t], logs: [], today: mon);
      expect(plan.itemsOn(thu), isEmpty);
      expect(totalFor(plan, t), 90);
    });

    test('long stages are split into sessions of at most two hours', () {
      final t = task('Dissertation chapter', addDays(mon, 10), '17:00', [('Work', 360)],
          size: TaskSize.huge);
      final plan = buildPlan(tasks: [t], logs: [], today: mon);
      final items = plan.days.values.expand((i) => i).toList();
      expect(items.length, 3);
      expect(items.every((i) => i.minutes <= maxSessionMinutes), isTrue);
      expect(totalFor(plan, t), 360);
    });

    test('balances the daily load across several tasks', () {
      final a = task('Maths sheet', wed, '09:00', [('Q1-5', 45), ('Q6-10', 45)], size: TaskSize.medium);
      final b = essay();
      final c = task('Chemistry revision', fri, '17:00', [('Notes', 60), ('Past paper', 60)]);
      final plan = buildPlan(tasks: [a, b, c], logs: [], today: mon);
      final loads = [for (final d in [mon, tue, wed, thu, fri]) plan.plannedMinutesOn(d)];
      expect(loads.reduce((x, y) => x + y), 90 + 195 + 120);
      expect(loads.every((l) => l <= defaultDailyLimit), isTrue, reason: '$loads');
      // No day is more than an hour and a half heavier than the lightest day.
      final sorted = [...loads]..sort();
      expect(sorted.last - sorted.first <= 90, isTrue, reason: '$loads');
      expect(plan.warnings, isEmpty);
    });

    test('blocked days get no work', () {
      final t = essay();
      final plan = buildPlan(tasks: [t], logs: [], today: tue, blockedDates: {wed});
      expect(plan.itemsOn(wed), isEmpty);
      expect(totalFor(plan, t), 195);
    });

    test('work logged today counts toward today\'s load', () {
      final other = task('Done earlier', fri, '14:00', [('X', 180)]);
      final t = essay();
      final logs = [WorkLog(taskId: other.id, stageId: other.stages[0].id, date: tue, minutes: 180)];
      other.completed = true;
      final plan = buildPlan(tasks: [other, t], logs: logs, today: tue);
      expect(plan.itemsOn(tue), isEmpty);
      expect(totalFor(plan, t), 195);
    });
  });

  group('rebalancing', () {
    test('a missed day moves its work forward and rebalances the rest of the week', () {
      final t = essay();
      // Tuesday's plan had Research. The student did nothing and it is now Wednesday.
      final plan = buildPlan(tasks: [t], logs: [], today: wed);
      expect(plan.itemsOn(tue), isEmpty);
      expect(totalFor(plan, t), 195);
      expect(placement(plan, t)['Research'], wed);
      expect(placement(plan, t)['Edit'], fri);
      expect(plan.warnings, isEmpty);
    });

    test('logged work is not planned again', () {
      final t = essay();
      final logs = [WorkLog(taskId: t.id, stageId: t.stages[0].id, date: tue, minutes: 45)];
      final plan = buildPlan(tasks: [t], logs: logs, today: wed);
      expect(placement(plan, t).containsKey('Research'), isFalse);
      expect(totalFor(plan, t), 150);
      expect(placement(plan, t)['Plan'], wed);
    });

    test('partially done stage keeps only its remainder', () {
      final t = essay();
      final logs = [WorkLog(taskId: t.id, stageId: t.stages[0].id, date: tue, minutes: 20)];
      final plan = buildPlan(tasks: [t], logs: logs, today: wed);
      expect(plan.itemsOn(wed).first.stageName, 'Research');
      expect(plan.itemsOn(wed).first.minutes, 25);
    });

    test('a stage that takes longer grows the plan and is rebalanced', () {
      final t = essay();
      t.stages[2].minutes += 60; // Write needs an extra hour
      final plan = buildPlan(tasks: [t], logs: [], today: tue);
      expect(totalFor(plan, t), 255);
      expect(plan.days.values.every((items) => items.fold(0, (a, i) => a + i.minutes) <= defaultDailyLimit),
          isTrue);
    });

    test('a stage finished early drops out of the plan', () {
      final t = essay();
      t.stages[0].done = true;
      final plan = buildPlan(tasks: [t], logs: [], today: tue);
      expect(totalFor(plan, t), 150);
    });
  });

  group('not-enough-time warning', () {
    test('warns when a task cannot fit before its deadline', () {
      final t = task('Coursework', tue, '09:00', [('Work', 360)], size: TaskSize.huge);
      final plan = buildPlan(tasks: [t], logs: [], today: mon);
      expect(plan.warnings, hasLength(1));
      expect(plan.warnings.single.type, WarningType.notEnoughTime);
      expect(plan.warnings.single.shortfall, 180);
      // The work is still planned (over the limit) rather than dropped.
      expect(totalFor(plan, t), 360);
    });

    test('no warning when there is enough time', () {
      final t = task('Coursework', addDays(mon, 7), '09:00', [('Work', 360)], size: TaskSize.huge);
      expect(buildPlan(tasks: [t], logs: [], today: mon).warnings, isEmpty);
    });

    test('takes earlier deadlines into account', () {
      // Mon + Tue + half of Wed = 450 minutes free.
      final a = task('A', wed, '23:00', [('Work', 180)]);
      final b = task('B', wed, '23:00', [('Work', 180)]);
      expect(buildPlan(tasks: [a, b], logs: [], today: mon).warnings, isEmpty);
      final c = task('C', wed, '23:00', [('Work', 180)]);
      final plan = buildPlan(tasks: [a, b, c], logs: [], today: mon);
      expect(plan.warnings.map((w) => w.taskId), [c.id]);
    });

    test('respects a lower daily limit', () {
      final t = essay();
      expect(buildPlan(tasks: [t], logs: [], today: thu).warnings, isEmpty);
      final plan = buildPlan(tasks: [t], logs: [], today: thu, dailyLimit: 60);
      expect(plan.warnings.single.type, WarningType.notEnoughTime);
    });

    test('a missed day can trigger the warning', () {
      final t = essay();
      expect(buildPlan(tasks: [t], logs: [], today: tue, dailyLimit: 75).warnings, isEmpty);
      expect(buildPlan(tasks: [t], logs: [], today: thu, dailyLimit: 75).warnings, isNotEmpty);
    });

    test('overdue tasks are flagged and put on today', () {
      final t = essay();
      final plan = buildPlan(tasks: [t], logs: [], today: fri, nowTime: '15:00');
      expect(plan.warnings.single.type, WarningType.overdue);
      expect(plan.plannedMinutesOn(fri), 195);
    });
  });
}
