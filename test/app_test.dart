import 'package:dodate/main.dart';
import 'package:dodate/src/app_state.dart';
import 'package:dodate/src/core/models.dart';
import 'package:dodate/src/ui/widgets.dart';
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
      // Reduced motion: the mascot holds still, so pumpAndSettle can settle.
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final state = AppState(clock: now);
      await state.load();
      await tester.pumpWidget(DodateApp(state: state));
      return state;
    }

    Future<void> tapVisible(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    Future<void> addEssay(WidgetTester tester, {String due = '2026-10-23', String time = '17:00'}) async {
      await tester.tap(find.byKey(const Key('add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('title-field')), 'History essay');
      await tapVisible(tester, find.byKey(Key('due-$due')));
      await tapVisible(tester, find.byKey(Key('time-$time')));
      await tapVisible(tester, find.byKey(const Key('size-big')));
      await tapVisible(tester, find.byKey(const Key('stage-template')));
      const minutes = ['45', '30', '90', '30'];
      for (var i = 0; i < minutes.length; i++) {
        await tester.enterText(find.byKey(Key('stage-minutes-$i')), minutes[i]);
      }
      await tapVisible(tester, find.byKey(const Key('save-task')));
    }

    testWidgets('add an assignment and see it spread over the week', (tester) async {
      final state = await pumpApp(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Turn due dates into do dates.'), findsOneWidget);
      await addEssay(tester);

      final task = state.tasks.single;
      expect(task.stages.map((s) => s.name), ['Research', 'Plan', 'Write', 'Edit']);
      expect(task.dueTime, '17:00');
      expect(find.byType(WarningCard), findsNothing);
      expect(find.textContaining('History essay added'), findsOneWidget);

      // Each day of the strip shows its own stage.
      expect(find.text('Research'), findsOneWidget);
      for (final (day, stage) in [('2026-10-21', 'Plan'), ('2026-10-22', 'Write'), ('2026-10-23', 'Edit')]) {
        await tester.tap(find.byKey(Key('day-$day')));
        await tester.pumpAndSettle();
        expect(find.text(stage), findsOneWidget, reason: day);
      }
    });

    testWidgets('tick a session off, then miss a day and see it move forward', (tester) async {
      final state = await pumpApp(tester);
      await addEssay(tester);
      final research = state.tasks.single.stages[0].id;

      await tester.tap(find.byKey(Key('check-$research-planned')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('check-$research-done')), findsOneWidget);
      expect(find.text('All done today!'), findsOneWidget);

      // Wednesday passes with nothing done; it is now Thursday.
      clock = DateTime(2026, 10, 22, 8);
      await state.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget);

      await tester.tap(find.byKey(const Key('day-2026-10-21')));
      await tester.pumpAndSettle();
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Moved forward'), findsOneWidget);
    });

    testWidgets('undo puts a ticked-off piece back', (tester) async {
      final state = await pumpApp(tester);
      await addEssay(tester);
      final research = state.tasks.single.stages[0].id;
      await tester.tap(find.byKey(Key('check-$research-planned')));
      await tester.pumpAndSettle();
      expect(state.logs, hasLength(1));
      await tester.tap(find.byKey(const Key('toast-undo')));
      await tester.pumpAndSettle();
      expect(state.logs, isEmpty);
      expect(find.byKey(Key('check-$research-planned')), findsOneWidget);
    });

    testWidgets('warns straight away when there is not enough time', (tester) async {
      final state = await pumpApp(tester);
      await addEssay(tester, due: '2026-10-21', time: '09:00');
      expect(find.text('History essay needs more time'), findsWidgets);
      expect(find.byKey(const Key('wontfit-raise')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wontfit-keep')));
      await tester.pumpAndSettle();
      expect(find.byType(WarningCard), findsOneWidget);
      expect(state.dailyLimit, 180);
    });

    testWidgets('marking a day off moves its work elsewhere', (tester) async {
      await pumpApp(tester);
      await addEssay(tester);
      await tester.tap(find.byKey(const Key('block-2026-10-20')));
      await tester.pumpAndSettle();
      expect(find.text('Research'), findsNothing);
      expect(find.textContaining('Day off'), findsWidgets);
    });

    testWidgets('needs more time from an assignment, then change the limit', (tester) async {
      final state = await pumpApp(tester);
      await addEssay(tester);
      await tester.tap(find.byKey(const Key('tab-deadlines')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('deadline-${state.tasks.single.id}')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Write').first);
      await tester.tap(find.byKey(const Key('action-more')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('minutes-field')), '60');
      await tester.tap(find.byKey(const Key('minutes-ok')));
      await tester.pumpAndSettle();
      expect(state.tasks.single.stages[2].minutes, 150);
      expect(find.text('0m of 2h30'), findsOneWidget);

      await tester.tap(find.byKey(const Key('detail-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('limit-120')));
      await tester.pumpAndSettle();
      expect(state.dailyLimit, 120);
      await tester.tap(find.byKey(const Key('theme-dark')));
      await tester.pumpAndSettle();
      expect(state.theme, 'dark');
    });

    testWidgets('hand an assignment in, then reopen it', (tester) async {
      final state = await pumpApp(tester);
      await addEssay(tester);
      await tester.tap(find.byKey(const Key('tab-deadlines')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('deadline-${state.tasks.single.id}')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('hand-in')));
      await tester.pumpAndSettle();
      expect(state.tasks.single.completed, isTrue);
      expect(find.text('Handed in'.toUpperCase()), findsOneWidget);
      await tester.tap(find.byKey(Key('reopen-${state.tasks.single.id}')));
      await tester.pumpAndSettle();
      expect(state.tasks.single.completed, isFalse);
    });
  });
}
