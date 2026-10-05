from pathlib import Path

HEALTH_MARKER = '// HEALTHY_ME_SOURCE_HUB_V010'
SYNC_MARKER = '// HEALTHY_ME_SOURCE_HUB_ROUTE_SANITIZER_V010'


def patch_health_service() -> None:
    path = Path('lib/services/health_connect_service.dart')
    text = path.read_text()
    if HEALTH_MARKER in text:
        print('Health Connect provider-routing patch already present.')
        return

    text = text.replace(
        "import 'source_name_service.dart';\n\nclass HealthConnectService {",
        "import 'source_name_service.dart';\n\n"
        f"{HEALTH_MARKER}\n"
        "// Health Connect is an import transport. Healthy Me routes metrics by the\n"
        "// original record provider exposed by Health Connect DataOrigin metadata.\n"
        "class HealthConnectService {",
        1,
    )
    if HEALTH_MARKER not in text:
        raise SystemExit('source hub patch: could not insert Health Connect marker')

    old_sources = '''    final sources = sourceLabels.keys.toList()\n      ..sort((a, b) => (sourceLabels[a] ?? a).compareTo(sourceLabels[b] ?? b));\n'''
    new_sources = '''    final sources = sourceLabels.keys\n        .where((source) => !SourceNameService.isTransportOnly(source))\n        .toList()\n      ..sort((a, b) => (sourceLabels[a] ?? a).compareTo(sourceLabels[b] ?? b));\n'''
    if old_sources not in text:
        raise SystemExit('source hub patch: provider source list not found')
    text = text.replace(old_sources, new_sources, 1)

    old_latest = '''    String? latestOriginForTypes(Iterable<HealthDataType> types) {\n      final allowed = types.toSet();\n      HealthDataPoint? latest;\n      for (final point in points) {\n        if (!allowed.contains(point.type) || originKey(point).isEmpty) continue;\n        if (latest == null || point.dateTo.isAfter(latest.dateTo)) {\n          latest = point;\n        }\n      }\n      return latest == null ? null : originKey(latest);\n    }\n'''
    new_latest = '''    String? latestOriginForTypes(Iterable<HealthDataType> types) {\n      final allowed = types.toSet();\n      HealthDataPoint? latest;\n      for (final point in points) {\n        final origin = originKey(point);\n        if (!allowed.contains(point.type) ||\n            origin.isEmpty ||\n            SourceNameService.isTransportOnly(origin)) {\n          continue;\n        }\n        if (latest == null || point.dateTo.isAfter(latest.dateTo)) {\n          latest = point;\n        }\n      }\n      return latest == null ? null : originKey(latest);\n    }\n'''
    if old_latest not in text:
        raise SystemExit('source hub patch: latestOriginForTypes block not found')
    text = text.replace(old_latest, new_latest, 1)

    old_resolved = '''    String? resolvedOrigin(\n      String metric,\n      Iterable<HealthDataType> types,\n    ) {\n      final selected = metricSources[metric];\n      if (selected != null && selected != 'Auto') {\n        final matching = points\n            .where((p) => types.contains(p.type) && sourceMatches(p, selected))\n            .toList()\n          ..sort((a, b) => a.dateTo.compareTo(b.dateTo));\n        if (matching.isNotEmpty) {\n          final key = originKey(matching.last);\n          if (key.isNotEmpty) {\n            resolvedSources[metric] = key;\n            return key;\n          }\n        }\n      }\n\n      final auto = latestOriginForTypes(types);\n      if (auto != null) resolvedSources[metric] = auto;\n      return auto;\n    }\n'''
    new_resolved = '''    String? resolvedOrigin(\n      String metric,\n      Iterable<HealthDataType> types,\n    ) {\n      final selected = metricSources[metric];\n      if (selected != null && selected != 'Auto') {\n        final matching = points\n            .where((p) => types.contains(p.type) && sourceMatches(p, selected))\n            .toList()\n          ..sort((a, b) => a.dateTo.compareTo(b.dateTo));\n        if (matching.isNotEmpty) {\n          final key = originKey(matching.last);\n          if (key.isNotEmpty && !SourceNameService.isTransportOnly(key)) {\n            resolvedSources[metric] = key;\n            return key;\n          }\n        }\n\n        // A manual source choice is authoritative. Never silently fall back to\n        // another provider when the selected provider has no records.\n        return null;\n      }\n\n      final auto = latestOriginForTypes(types);\n      if (auto != null) {\n        resolvedSources[metric] = auto;\n        return auto;\n      }\n      return null;\n    }\n'''
    if old_resolved not in text:
        raise SystemExit('source hub patch: resolvedOrigin block not found')
    text = text.replace(old_resolved, new_resolved, 1)

    start = text.find("    final selectedStepSource = metricSources['Steps'];")
    end = text.find("    final stepsToday = await stepTotal(today, now);", start)
    if start < 0 or end < 0:
        raise SystemExit('source hub patch: step routing block not found')
    new_steps = '''    final selectedStepSource = metricSources['Steps'];\n    final resolvedStepSource = resolvedOrigin(\n      'Steps',\n      [HealthDataType.STEPS],\n    );\n    final rawSteps = points\n        .where(\n          (p) => p.type == HealthDataType.STEPS &&\n              resolvedStepSource != null &&\n              originKey(p) == resolvedStepSource,\n        )\n        .toList()\n      ..sort((a, b) => a.dateTo.compareTo(b.dateTo));\n\n    int rawStepTotal(DateTime start, DateTime end) {\n      var total = 0.0;\n      for (final p in rawSteps) {\n        if (p.dateTo.isBefore(start) || !p.dateFrom.isBefore(end)) continue;\n        final value = number(p);\n        if (value == null || value <= 0) continue;\n\n        final overlapStart = p.dateFrom.isAfter(start) ? p.dateFrom : start;\n        final overlapEnd = p.dateTo.isBefore(end) ? p.dateTo : end;\n        if (!overlapEnd.isAfter(overlapStart)) continue;\n\n        final recordMs = p.dateTo.difference(p.dateFrom).inMilliseconds;\n        if (recordMs <= 0) {\n          total += value;\n          continue;\n        }\n        final overlapMs = overlapEnd.difference(overlapStart).inMilliseconds;\n        final ratio = (overlapMs / recordMs).clamp(0.0, 1.0).toDouble();\n        total += value * ratio;\n      }\n      return total.round();\n    }\n\n    Future<int> stepTotal(DateTime start, DateTime end) async {\n      // Healthy Me deliberately totals one provider at a time so the value and\n      // attribution stay aligned. Health Connect remains transport only.\n      return rawStepTotal(start, end);\n    }\n\n'''
    text = text[:start] + new_steps + text[end:]

    old_motion_comment = '''    // Motion metrics can be written by several apps at once. For Auto steps,\n    // Health Connect's aggregate API resolves step duplication. Distance and\n    // active calories do not have the same aggregate helper in this plugin, so\n    // anchor them to one actual motion origin rather than summing Samsung +\n    // Garmin + phone records together.\n'''
    new_motion_comment = '''    // Motion metrics can be written by several apps at once. Anchor activity\n    // values to the same provider Healthy Me resolved for Steps so provenance\n    // and totals do not mix multiple apps together.\n'''
    if old_motion_comment not in text:
        raise SystemExit('source hub patch: motion comment not found')
    text = text.replace(old_motion_comment, new_motion_comment, 1)

    old_motion = '''    final resolvedMotionSource =\n        selectedStepSource != null && selectedStepSource != 'Auto'\n            ? resolvedSources['Steps']\n            : latestOriginForTypes([\n                HealthDataType.STEPS,\n                HealthDataType.DISTANCE_DELTA,\n              ]);\n'''
    new_motion = '''    final resolvedMotionSource =\n        selectedStepSource != null && selectedStepSource != 'Auto'\n            ? selectedStepSource\n            : resolvedSources['Steps'] ??\n                latestOriginForTypes([\n                  HealthDataType.STEPS,\n                  HealthDataType.DISTANCE_DELTA,\n                ]);\n'''
    if old_motion not in text:
        raise SystemExit('source hub patch: resolvedMotionSource block not found')
    text = text.replace(old_motion, new_motion, 1)

    old_origins = '''      final values = points\n          .where((point) => allowed.contains(point.type))\n          .map(originKey)\n          .where((source) => source.isNotEmpty)\n          .toSet()\n          .toList();\n'''
    new_origins = '''      final values = points\n          .where((point) => allowed.contains(point.type))\n          .map(originKey)\n          .where(\n            (source) =>\n                source.isNotEmpty && !SourceNameService.isTransportOnly(source),\n          )\n          .toSet()\n          .toList();\n'''
    if old_origins not in text:
        raise SystemExit('source hub patch: originsFor block not found')
    text = text.replace(old_origins, new_origins, 1)

    if 'Health Connect aggregate' in text:
        raise SystemExit('source hub patch: aggregate source label still present')
    if 'getTotalStepsInInterval' in text:
        raise SystemExit('source hub patch: aggregate step helper still present')

    path.write_text(text)
    print('Healthy Me v0.10 Health Connect provider routing applied.')


def patch_sync_provider() -> None:
    path = Path('lib/state/health_sync_provider.dart')
    text = path.read_text()
    if SYNC_MARKER in text:
        print('Metric-route sanitizer already present.')
        return

    import_line = "import '../services/health_connect_service.dart';\n"
    replacement = (
        import_line
        + "import '../services/source_name_service.dart';\n"
    )
    if import_line not in text:
        raise SystemExit('source hub patch: health sync import anchor not found')
    text = text.replace(import_line, replacement, 1)

    old = '''  Future<void> _sync({bool? historyOverride}) async {\n    final app = ref.read(appStateProvider);\n    final snapshot = await _service.sync(\n      historicalAccess:\n          historyOverride ?? app.health.historicalAccess,\n      metricSources: app.metricSources,\n    );\n'''
    new = f'''  Future<void> _sync({{bool? historyOverride}}) async {{\n    final app = ref.read(appStateProvider);\n    {SYNC_MARKER}\n    // Old betas allowed transport pseudo-sources to be saved as metric routes.\n    // Convert those back to Automatic before querying provider-specific data.\n    final routedSources = Map<String, String>.from(app.metricSources);\n    final obsoleteRoutes = routedSources.entries\n        .where((entry) => SourceNameService.isTransportOnly(entry.value))\n        .map((entry) => entry.key)\n        .toList();\n    for (final metric in obsoleteRoutes) {{\n      routedSources.remove(metric);\n      ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');\n    }}\n\n    final snapshot = await _service.sync(\n      historicalAccess:\n          historyOverride ?? app.health.historicalAccess,\n      metricSources: routedSources,\n    );\n'''
    if old not in text:
        raise SystemExit('source hub patch: health sync block not found')
    text = text.replace(old, new, 1)
    path.write_text(text)
    print('Healthy Me v0.10 saved-route sanitizer applied.')


patch_health_service()
patch_sync_provider()
