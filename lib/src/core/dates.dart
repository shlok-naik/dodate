// Calendar days are plain 'YYYY-MM-DD' strings. Arithmetic is done in UTC so
// daylight-saving changes never shift a day.

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime _parse(String date) {
  final p = date.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String addDays(String date, int n) => _fmt(_parse(date).add(Duration(days: n)));

/// Days from [a] to [b] (positive when [b] is later).
int diffDays(String a, String b) => _parse(b).difference(_parse(a)).inDays;

String mondayOf(String date) => addDays(date, -(_parse(date).weekday - 1));

String dayLabel(String date) => '${_dayNames[_parse(date).weekday - 1]} $date';

String dateOf(DateTime d) => _fmt(d);

String timeOf(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatMinutes(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h${m.toString().padLeft(2, '0')}';
}
