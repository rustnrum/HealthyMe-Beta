String compactNumber(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    final digits = value >= 10000 ? 0 : 1;
    return '${(value / 1000).toStringAsFixed(digits)}K';
  }
  return value.round().toString();
}

String minutesLabel(int total) {
  if (total <= 0) return '—';
  final hours = total ~/ 60;
  final minutes = total % 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String shortDate(DateTime date) =>
    '${date.month}/${date.day}/${date.year}';

String relativeAge(DateTime? date) {
  if (date == null) return 'No data';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 2) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days';
}
