class DataSource {
  final String id;
  final String name;
  final Set<String> metrics;
  final bool available;

  const DataSource({
    required this.id,
    required this.name,
    required this.metrics,
    this.available = true,
  });
}
