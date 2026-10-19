import 'package:dodate/main.dart';
import 'package:dodate/src/app_state.dart';
import 'package:dodate/src/core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Tuesday 2026-10-20, 08:00.
  late DateTime clock;
  DateTime now() => clock;

  setUp(() {
    clock = DateTime(2026, 10, 20, 8);
    SharedPreferences.setMockInitialValues({});
  });

  group('AppState', () {
    test('adds a task with equally split stages and plans it', () async {
      final state = AppState(clock: now);
      await state.load();
      final t = await state.addTask(
        title: 'History essay',
        dueDate: '2026-10-23',
        dueTime: '14:00',
        size: TaskSize.big,
        stages: [('Research', null), ('Plan', null), ('Write', null), ('Edit', null)],
      );
      expect(t.stages.map((s) => s.minutes), [45, 45, 45, 45]);
      expect(state.plan.itemsOn('2026-10-20').single.stageName, 'Research');
    });

    test('no stages gives one "Work" stage of the size total', () async {
      final state = AppState(clock: now);
      await state.load();
      final t = await state.addTask(
          title: 'Quiz prep', dueDate: '2026-10-22', dueTime: '09:00', size: TaskSize.quick);
      expect(t.stages.single.name, 'Work');
      expect(t.stages.single.minutes, 30);
    });

    test('persists and reloads, and shows a missed day the next day', () async {
      final state = AppState(clock: now);
      await state.load();
      await state.addTask(
        title: 'History essay',
        dueDate: '2026-10-23',
        dueTime: '14:00',
        size: TaskSize.big,
        stages: [('Research', 45), ('Plan', 30), ('Write', 90), ('Edit', 30)],
      );

      // Next day, fresh app start: nothing was done on Tuesday.
      clock = DateTime(2026, 10, 21, 8);
      final reloaded = AppState(clock: now);
      await reloaded.load();
      expect(reloaded.tasks.single.title, 'History essay');
      final tuesday = reloaded.entriesFor('2026-10-20');
      expect(tuesday.single.status, EntryStatus.missed);
      expect(tuesday.single.item.stageName, 'Research');
      // Research has moved forward to today.
      expect(reloaded.plan.itemsOn('2026-10-21').first.stageName, 'Research');
    });

    test('logging, needing more time, finishing and completing', () async {
      final state = AppState(clock: now);
      await state.load();
      final t = await state.addTask(
        title: 'Essay',
        dueDate: '2026-10-23',
        dueTime: '14:00',
        size: TaskSize.big,
        stages: [('Research', 45), ('Write', 90)],
      );
      await state.logWork(t.id, t.stages[0].id, 45);
      expect(state.entriesFor('2026-10-20').first.status, EntryStatus.done);
      expect(state.plan.days.values.expand((i) => i).every((i) => i.stageName == 'Write'), isTrue);

      await state.addTime(t.id, t.stages[1].id, 30);
      expect(state.plan.days.values.expand((i) => i).fold(0, (a, i) => a + i.minutes), 120);

      await state.finishStage(t.id, t.stages[1].id);
      expect(state.plan.days, isEmpty);

      await state.completeTask(t.id);
      await state.deleteTask(t.id);
      expect(state.tasks, isEmpty);
    });

    test('blocking a day rebalances around it', () async {
      final state = AppState(clock: now);
      await state.load();
      await state.addTask(
          title: 'Essay', dueDate: '2026-10-23', dueTime: '14:00', size: TaskSize.big);
      await state.toggleBlocked('2026-10-20');
      expect(state.plan.itemsOn('2026-10-20'), isEmpty);
      await state.toggleBlocked('2026-10-20');
      expect(state.plan.itemsOn('2026-10-20'), isNotEmpty);
    });
  });

  group('UI end to end', () {
    Future<AppState> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = AppState(clock: now);
      await state.load();
      await tester.pumpWidget(DodateApp(state: state));
      return state;
    }

    Future<void> addEssay(WidgetTester tester, {String due = '2026-10-23', String time = '14:00'}) async {
      await tester.tap(find.byKey(const Key('add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('title-field')), 'History essay');
      await tester.enterText(find.byKey(const Key('due-date-field')), due);
      await tester.enterText(find.byKey(const Key('due-time-field')), time);
      await tester.tap(find.byKey(const Key('size-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Big (about 3h)').last);
      await tester.pumpAndSettle();
      const stages = ['Research', 'Plan', 'Write', 'Edit'];
      const minutes = ['45', '30', '90', '30'];
      for (var i = 0; i < stages.length; i++) {
        await tester.tap(find.byKey(const Key('add-stage')));
        await tester.pump();
        await tester.enterText(find.byKey(Key('stage-name-$i')), stages[i]);
        await tester.enterText(find.byKey(Key('stage-minutes-$i')), minutes[i]);
      }
      await tester.tap(find.byKey(const Key('save-task')));
      await tester.pumpAndSettle();
    }

    testWidgets('add an assignment and see it spread over the week', (tester) async {
      await pumpApp(tester);
      expect(find.text('Tue 2026-10-20 (today)'), findsOneWidget);
      await addEssay(tester);

      expect(find.text('History essay: Research'), findsOneWidget);
      expect(find.text('History essay: Plan'), findsOneWidget);
      expect(find.text('History essay: Write'), findsOneWidget);
      expect(find.text('History essay: Edit'), findsOneWidget);
      expect(find.textContaining('Warning'), findsNothing);
    });

    testWidgets('mark a session done, then miss a day and see it move forward', (tester) async {
      final state = await pumpApp(tester);
      await addEssay(tester);

      await tester.tap(find.text('History essay: Research'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action-done')));
      await tester.pumpAndSettle();
      expect(find.text('Done 45m'), findsOneWidget);

      // Wednesday passes with nothing done; it is now Thursday.
      clock = DateTime(2026, 10, 22, 8);
      await state.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Missed 30m, moved to later days'), findsOneWidget);
      expect(find.text('Thu 2026-10-22 (today)'), findsOneWidget);
      // Plan, Write and Edit are all still planned (Thu and Fri).
      expect(find.text('History essay: Plan'), findsNWidgets(2)); // missed Wed + planned
      expect(find.text('History essay: Write'), findsOneWidget);
      expect(find.text('History essay: Edit'), findsOneWidget);
    });

    testWidgets('warns straight away when there is not enough time', (tester) async {
      await pumpApp(tester);
      await addEssay(tester, due: '2026-10-21', time: '09:00');
      expect(find.text('Warning'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Warning: Not enough time for "History essay"'), findsOneWidget);
    });

    testWidgets('needs more time from the assignments screen', (tester) async {
      final state = await pumpApp(tester);
      await addEssay(tester);
      await tester.tap(find.byKey(const Key('open-tasks')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action-more')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('minutes-field')), '60');
      await tester.tap(find.byKey(const Key('minutes-ok')));
      await tester.pumpAndSettle();
      expect(state.tasks.single.stages[2].minutes, 150);
      expect(find.textContaining('of 2h30'), findsOneWidget);
    });
  });
}
