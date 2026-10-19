# Dodate

A minimalist weekly planner for students (GCSE, A-Level, university) that turns
assignment **due dates** into **do dates**: small, balanced pieces of work spread
over the days before each deadline.

Design direction: calm, warm minimalism. A sage-tinted paper background, one
spruce accent, amber (never red) for "needs more time", and a soft colour per
assignment. Bricolage Grotesque for headings and Figtree for text, both bundled
under the OFL. Light and dark themes come from one token set in
`lib/src/ui/theme.dart`.

## Run it

Requires the Flutter SDK with Dart 3.12 or newer (developed on Flutter 3.47 / Dart 3.13).

```sh
flutter pub get
flutter test              # scheduler, state/persistence and end-to-end widget tests
flutter run               # on a connected Android/iOS device or emulator
flutter run -d chrome     # or in a browser
```

## What it does

1. **Add an assignment**: title, due date and time (*Add* button).
2. **Choose its size**: Quick (30m), Medium (1h30), Big (3h), Huge (6h).
3. **Optional stages** (e.g. Research / Plan / Write / Edit) with optional minutes.
   Stages without minutes share the size's time equally.
4. **Automatic plan**: stages are spread across the days before the deadline,
   balancing each day's total workload across all assignments.
5. **Weekly view**: Monday to Sunday, what to do each day; Previous/Next weeks.
6. **Rebalancing**:
   - tap a planned item and choose **Done**, **Log time worked today**,
     **Needs more time**, or **Stage finished**;
   - a day that passes with planned work not done shows it as *missed* and
     the work is automatically moved to the remaining days;
   - **Can't work** marks a day as unavailable and replans around it.
7. **Early warning**: as soon as an assignment can't fit before its deadline
   (at the daily limit, given other deadlines), a dialog and a warning on the
   week view say so. Overdue work is flagged and put on today.

The one setting is the **daily limit** (default 3h) in *Assignments*.

## Code layout

```
lib/src/core/scheduler.dart   the planner (pure Dart, no Flutter): splitting, placement, warnings
lib/src/core/models.dart      Task, Stage, WorkLog, PlannedItem, TaskSize
lib/src/core/dates.dart       'YYYY-MM-DD' date helpers
lib/src/app_state.dart        app state + persistence (shared_preferences, JSON)
lib/src/ui/                   theme tokens, week view, add-assignment sheet, assignments list, stage actions
test/scheduler_test.dart      planner tests
test/app_test.dart            state/persistence tests and end-to-end widget tests
```

### How planning works

The plan is never the source of truth. It is rebuilt from the current state
(remaining minutes per stage, work logged today, blocked days, daily limit)
every time something changes or the app resumes, starting from today. A missed
day or an overrunning stage therefore rebalances automatically.

- Tasks are planned earliest deadline first.
- A task's window is today through its last work day. The due day counts, at
  half the daily limit, only when the task is due at or after 12:00.
- Each stage's remaining time is cut into sessions of at most 2h (or the daily
  limit, if lower). Stage order is always kept.
- An exact dynamic program assigns sessions to days. It minimises the sum of
  squared daily loads (balance), heavily penalises going over the daily limit
  and using blocked days, and slightly prefers earlier days (anti-cramming).
- If the task still goes over the limit somewhere, it gets a
  *not enough time* warning with the shortfall.
- The last plan for each day is kept, so past days can show what was missed.

## Research summary

- **Mobbin** (Fabric, Tiimo, Saturn): a task is created with a title, then a due
  date is added through quick picks or a calendar. Duration is chosen from
  preset chips, the same idea as Dodate's sizes. Work appears in a day or week
  list with a checkbox, and checklists hold sub-steps (stages).
- **Week Plan** (a Tweek-style planner): unfinished tasks roll over to the next
  day automatically. Dodate goes further and rebalances the remaining days
  rather than piling work onto tomorrow.
- **MyStudyLife**: subtasks and a revision planner that spreads study across the
  days before an exam. University "assignment calculators" turn a due date into
  a stage timeline. Neither balances across assignments, which is Dodate's gap.

## Assumptions

- Size totals: Quick 30m, Medium 1h30, Big 3h, Huge 6h.
- Default daily limit is 3h. It is the only setting.
- Partial stage times: unspecified stages share what's left of the size total,
  at least 15m each. If every stage has minutes, their sum is the total.
- No stages means one stage called "Work".
- The due day is usable only for work due at/after 12:00, at half capacity
  (the morning). The default due time is 09:00 and the default due date is a
  week from today.
- Today is always plannable, regardless of the time of day.
- Weeks start on Monday (UK school week).
- "Done" logs the planned minutes against today. Work can be done ahead of plan.
- Editing an assignment isn't supported: delete and re-add.
- Data is stored on the device only (no accounts or sync).

## Not built (intentionally or yet)

Priorities, hourly time-blocking, notifications, editing assignments, accounts
and sync, recurring tasks, app icon and splash screen.
