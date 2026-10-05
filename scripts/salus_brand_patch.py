from pathlib import Path
import re
import shutil

VERSION_NEW = '0.14.0+19'
SUPPORTED_OLD = {'0.11.0+15', '0.12.0+16', '0.13.0+17', '0.14.0+18'}


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 19 patch: {message}')


def patch_once(path_name: str, old: str, new: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists():
        fail(f'missing {path_name} while applying {label}')
    text = path.read_text()
    # For non-empty replacements, seeing the replacement means the patch
    # is already applied. For deletions, an empty string is present in every
    # file, so only the absence of the old text means the deletion is done.
    if new and new in text:
        return
    if old not in text:
        if not new:
            return
        fail(f'{path_name} no longer matches expected build-18 source for {label}')
    path.write_text(text.replace(old, new, 1))


def require(path_name: str, needle: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists() or needle not in path.read_text():
        fail(f'{label} missing from {path_name}: {needle}')


def forbid(path_name: str, needle: str, label: str) -> None:
    path = Path(path_name)
    if path.exists() and needle in path.read_text():
        fail(f'{label} still present in {path_name}: {needle}')


# --- Version / product identity -------------------------------------------------
pub = Path('pubspec.yaml')
text = pub.read_text()
match = re.search(r'^version:\s*(\S+)\s*$', text, flags=re.M)
if match is None:
    fail('pubspec version line not found')
current = match.group(1)
if current in SUPPORTED_OLD:
    text = re.sub(r'^version:\s*\S+\s*$', f'version: {VERSION_NEW}', text, count=1, flags=re.M)
elif current != VERSION_NEW:
    fail(f'unsupported source version {current}; expected one of {sorted(SUPPORTED_OLD | {VERSION_NEW})}')
text = text.replace(
    'description: Healthy Me - a personal body command center.',
    'description: Salus by Rust N Rum - a personal health journal and body command center.',
)
pub.write_text(text)

# User-visible product naming only. Internal package/storage identifiers remain unchanged.
for path in Path('lib').rglob('*.dart'):
    text = path.read_text()
    text = text.replace('Healthy Me', 'Salus')
    text = re.sub(
        r'Beta 0\.(?:11|12|13|14)\.0\+(?:15|16|17|18) • Salus Source Registry',
        'Beta 0.14.0+19 • Salus Source Registry',
        text,
    )
    path.write_text(text)

# --- Workout becomes a real top-level Salus module -----------------------------
patch_once(
    'lib/widgets/module_menu_button.dart',
    'enum HealthyMeModule { fitness, diet, health }',
    'enum HealthyMeModule { fitness, workout, diet, health }',
    'Workout module enum',
)
patch_once(
    'lib/widgets/module_menu_button.dart',
    "        _item(module: HealthyMeModule.fitness, current: current, icon: Icons.eco_rounded, color: AppTheme.mint, title: 'Main', subtitle: 'Today • Activity • Sleep • Body'),\n        const PopupMenuDivider(),\n        _item(module: HealthyMeModule.diet, current: current, icon: Icons.restaurant_rounded, color: AppTheme.amber, title: 'Diet', subtitle: 'Today • Meals • Plan • Grocery'),",
    "        _item(module: HealthyMeModule.fitness, current: current, icon: Icons.eco_rounded, color: AppTheme.mint, title: 'Main', subtitle: 'Today • Activity • Sleep • Body'),\n        const PopupMenuDivider(),\n        _item(module: HealthyMeModule.workout, current: current, icon: Icons.fitness_center_rounded, color: AppTheme.cyan, title: 'Workout', subtitle: 'Today • Schedule • Templates • History'),\n        const PopupMenuDivider(),\n        _item(module: HealthyMeModule.diet, current: current, icon: Icons.restaurant_rounded, color: AppTheme.amber, title: 'Diet', subtitle: 'Today • Meals • Plan • Grocery'),",
    'Workout module menu item',
)

patch_once(
    'lib/app.dart',
    "import 'screens/onboarding_screen.dart';",
    "import 'screens/onboarding_screen.dart';\nimport 'screens/workout_screen.dart';",
    'Workout route import',
)
patch_once(
    'lib/app.dart',
    "        '/health': (_) => const HealthShell(),\n        '/daily-state': (_) => const DailyStateScreen(),",
    "        '/health': (_) => const HealthShell(),\n        '/workout': (_) => const WorkoutScreen(),\n        '/daily-state': (_) => const DailyStateScreen(),",
    'Workout named route',
)

patch_once(
    'lib/screens/home_shell.dart',
    "        case HealthyMeModule.fitness:\n          ref.read(navigationProvider.notifier).go(0);\n          break;\n        case HealthyMeModule.diet:",
    "        case HealthyMeModule.fitness:\n          ref.read(navigationProvider.notifier).go(0);\n          break;\n        case HealthyMeModule.workout:\n          Navigator.of(context).pushNamed('/workout');\n          break;\n        case HealthyMeModule.diet:",
    'Main-shell Workout navigation',
)

patch_once(
    'lib/screens/diet/diet_shell.dart',
    "              case HealthyMeModule.fitness: Navigator.of(context).popUntil((route) => route.isFirst); break;\n              case HealthyMeModule.diet: break;",
    "              case HealthyMeModule.fitness: Navigator.of(context).popUntil((route) => route.isFirst); break;\n              case HealthyMeModule.workout: Navigator.of(context).pushReplacementNamed('/workout'); break;\n              case HealthyMeModule.diet: break;",
    'Diet-to-Workout navigation',
)
patch_once(
    'lib/screens/health/health_shell.dart',
    "            case HealthyMeModule.fitness: Navigator.of(context).popUntil((route) => route.isFirst); break;\n            case HealthyMeModule.diet: Navigator.of(context).pushReplacementNamed('/diet'); break;",
    "            case HealthyMeModule.fitness: Navigator.of(context).popUntil((route) => route.isFirst); break;\n            case HealthyMeModule.workout: Navigator.of(context).pushReplacementNamed('/workout'); break;\n            case HealthyMeModule.diet: Navigator.of(context).pushReplacementNamed('/diet'); break;",
    'Health-to-Workout navigation',
)

patch_once(
    'lib/screens/workout_screen.dart',
    "import '../widgets/design_widgets.dart';",
    "import '../widgets/design_widgets.dart';\nimport '../widgets/module_menu_button.dart';",
    'Workout module menu import',
)
patch_once(
    'lib/screens/workout_screen.dart',
    """    final library = ref.watch(workoutStateProvider);
    final health = ref.watch(appStateProvider).health;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Workouts')),""",
    """    final library = ref.watch(workoutStateProvider);
    final health = ref.watch(appStateProvider).health;

    void selectModule(HealthyMeModule module) {
      switch (module) {
        case HealthyMeModule.fitness:
          Navigator.of(context).popUntil((route) => route.isFirst);
          break;
        case HealthyMeModule.workout:
          break;
        case HealthyMeModule.diet:
          Navigator.of(context).pushReplacementNamed('/diet');
          break;
        case HealthyMeModule.health:
          Navigator.of(context).pushReplacementNamed('/health');
          break;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          HealthyMeModuleMenuButton(
            current: HealthyMeModule.workout,
            onSelected: selectModule,
          ),
          const SizedBox(width: 6),
        ],
      ),""",
    'Workout top-level module app bar',
)

# Activity links to the named module route instead of treating Workout as a detail page.
# Use an explicit deletion instead of the generic patch helper so this stale
# import can never survive into flutter analyze.
activity_path = Path('lib/screens/activity_screen.dart')
if not activity_path.exists():
    fail('missing lib/screens/activity_screen.dart while removing stale Workout import')
activity_text = activity_path.read_text()
activity_text = activity_text.replace("import 'workout_screen.dart';\n", '')
activity_path.write_text(activity_text)
forbid(
    'lib/screens/activity_screen.dart',
    "import 'workout_screen.dart';",
    'stale Activity detail-page Workout import',
)
patch_once(
    'lib/screens/activity_screen.dart',
    "          onAction: () => Navigator.of(context).push(\n            MaterialPageRoute<void>(builder: (_) => const WorkoutScreen()),\n          ),",
    "          onAction: () => Navigator.of(context).pushNamed('/workout'),",
    'Activity-to-Workout module route',
)

# --- Sleep stages get independent provider routing ------------------------------
patch_once(
    'lib/services/health_connect_service.dart',
    "    final sleepTypes = <HealthDataType>[\n      HealthDataType.SLEEP_ASLEEP,\n      HealthDataType.SLEEP_AWAKE,\n      HealthDataType.SLEEP_REM,\n      HealthDataType.SLEEP_LIGHT,\n      HealthDataType.SLEEP_DEEP,\n    ];\n\n    final sleepResolved = resolvedOrigin('Sleep', sleepTypes);\n    final sleepPoints = points.where((p) {\n      if (!sleepTypes.contains(p.type)) return false;\n      return sleepResolved != null && originKey(p) == sleepResolved;\n    }).toList();",
    "    final sleepStageTypes = <HealthDataType>[\n      HealthDataType.SLEEP_AWAKE,\n      HealthDataType.SLEEP_REM,\n      HealthDataType.SLEEP_LIGHT,\n      HealthDataType.SLEEP_DEEP,\n    ];\n    final sleepTypes = <HealthDataType>[\n      HealthDataType.SLEEP_ASLEEP,\n      ...sleepStageTypes,\n    ];\n\n    final sleepResolved = resolvedOrigin('Sleep', sleepTypes);\n    final sleepStageResolved = resolvedOrigin('Sleep Stages', sleepStageTypes);\n    final sleepPoints = points.where((p) {\n      if (!sleepTypes.contains(p.type)) return false;\n      return sleepResolved != null && originKey(p) == sleepResolved;\n    }).toList();\n    final sleepStagePoints = points.where((p) {\n      if (!sleepStageTypes.contains(p.type)) return false;\n      return sleepStageResolved != null && originKey(p) == sleepStageResolved;\n    }).toList();",
    'Independent Sleep Stages resolver',
)

# Insert an independent stage-by-day accumulator after the existing total-sleep accumulator.
patch_once(
    'lib/services/health_connect_service.dart',
    "    int totalFor(Map<String, int>? map) {\n      if (map == null) return 0;\n      final staged =\n          (map['rem'] ?? 0) + (map['light'] ?? 0) + (map['deep'] ?? 0);\n      return staged > 0 ? staged : (map['generic'] ?? 0);\n    }\n\n    final sleepKeys = sleepByDay.keys.toList()..sort();",
    "    final sleepStagesByDay = <String, Map<String, int>>{};\n    for (final p in sleepStagePoints) {\n      final key = dayKey(p.dateTo);\n      final map = sleepStagesByDay.putIfAbsent(\n        key,\n        () => {'awake': 0, 'rem': 0, 'light': 0, 'deep': 0},\n      );\n      final minutes = max(0, p.dateTo.difference(p.dateFrom).inMinutes);\n      switch (p.type) {\n        case HealthDataType.SLEEP_AWAKE:\n          map['awake'] = (map['awake'] ?? 0) + minutes;\n          break;\n        case HealthDataType.SLEEP_REM:\n          map['rem'] = (map['rem'] ?? 0) + minutes;\n          break;\n        case HealthDataType.SLEEP_LIGHT:\n          map['light'] = (map['light'] ?? 0) + minutes;\n          break;\n        case HealthDataType.SLEEP_DEEP:\n          map['deep'] = (map['deep'] ?? 0) + minutes;\n          break;\n        default:\n          break;\n      }\n    }\n\n    int totalFor(Map<String, int>? map) {\n      if (map == null) return 0;\n      final staged =\n          (map['rem'] ?? 0) + (map['light'] ?? 0) + (map['deep'] ?? 0);\n      return staged > 0 ? staged : (map['generic'] ?? 0);\n    }\n\n    final sleepKeys = sleepByDay.keys.toList()..sort();",
    'Independent Sleep Stages daily accumulator',
)
patch_once(
    'lib/services/health_connect_service.dart',
    "    final latestSleep = latestSleepKey == null\n        ? null\n        : sleepByDay[latestSleepKey];\n\n    final sleepMinutes7 = <int>[];",
    "    final latestSleep = latestSleepKey == null\n        ? null\n        : sleepByDay[latestSleepKey];\n    final sleepStageKeys = sleepStagesByDay.keys.toList()..sort();\n    final latestSleepStageKey = sleepStageKeys.isEmpty ? null : sleepStageKeys.last;\n    final latestSleepStages = latestSleepStageKey == null\n        ? null\n        : sleepStagesByDay[latestSleepStageKey];\n\n    final sleepMinutes7 = <int>[];",
    'Latest Sleep Stages snapshot',
)
patch_once(
    'lib/services/health_connect_service.dart',
    "    addFresh('Sleep', sleepPoints);\n    addFresh('Heart rate', heart);",
    "    addFresh('Sleep', sleepPoints);\n    addFresh('Sleep Stages', sleepStagePoints);\n    addFresh('Heart rate', heart);",
    'Sleep Stages freshness',
)
patch_once(
    'lib/services/health_connect_service.dart',
    "      'Sleep': recordCountsFor('Sleep', sleepTypes),\n      'Heart rate': recordCountsFor('Heart rate', [HealthDataType.HEART_RATE]),",
    "      'Sleep': recordCountsFor('Sleep', sleepTypes),\n      'Sleep Stages': recordCountsFor('Sleep Stages', sleepStageTypes),\n      'Heart rate': recordCountsFor('Heart rate', [HealthDataType.HEART_RATE]),",
    'Sleep Stages source registry',
)
patch_once(
    'lib/services/health_connect_service.dart',
    "      sleepAwakeMinutes: latestSleep?['awake'] ?? 0,\n      sleepRemMinutes: latestSleep?['rem'] ?? 0,\n      sleepLightMinutes: latestSleep?['light'] ?? 0,\n      sleepDeepMinutes: latestSleep?['deep'] ?? 0,",
    "      sleepAwakeMinutes: latestSleepStages?['awake'] ?? 0,\n      sleepRemMinutes: latestSleepStages?['rem'] ?? 0,\n      sleepLightMinutes: latestSleepStages?['light'] ?? 0,\n      sleepDeepMinutes: latestSleepStages?['deep'] ?? 0,",
    'Sleep Stages values from stage provider',
)

patch_once(
    'lib/screens/sleep_screen.dart',
    "    final stageSourceKey =\n        h.resolvedSources['Sleep Stages'] ?? h.resolvedSources['Sleep'];\n    final stageSourceLabel = stageSourceKey == null\n        ? 'No connected source'",
    "    final stageSourceKey = h.resolvedSources['Sleep Stages'];\n    final stageSourceLabel = stageSourceKey == null\n        ? 'No stage data source'",
    'Truthful Sleep Stages source label',
)
patch_once(
    'lib/screens/sources_screen.dart',
    "    'Sleep',\n    'Heart rate',",
    "    'Sleep',\n    'Sleep Stages',\n    'Heart rate',",
    'Sleep Stages source selector',
)

# Provider labels must remain readable instead of silently truncating the source name.
patch_once(
    'lib/screens/activity_screen.dart',
    "                          'Source: $stepSourceLabel',\n                          maxLines: 1,\n                          overflow: TextOverflow.ellipsis,",
    "                          'Source: $stepSourceLabel',\n                          maxLines: 2,\n                          softWrap: true,",
    'Activity source label wrapping',
)
patch_once(
    'lib/screens/sleep_screen.dart',
    "                      'Source: $sleepSourceLabel',\n                      maxLines: 1,\n                      overflow: TextOverflow.ellipsis,",
    "                      'Source: $sleepSourceLabel',\n                      maxLines: 2,\n                      softWrap: true,",
    'Sleep source label wrapping',
)
patch_once(
    'lib/screens/sleep_screen.dart',
    "                  'Stages from: $stageSourceLabel',\n                  maxLines: 1,\n                  overflow: TextOverflow.ellipsis,",
    "                  'Stages from: $stageSourceLabel',\n                  maxLines: 2,\n                  softWrap: true,",
    'Sleep Stages source label wrapping',
)

# --- Screenshot-specific text overflow fixes ------------------------------------
# The Salus header tagline is two intentional lines. Scale the pair down as a unit
# on narrow phones instead of allowing the second line to be clipped.
patch_once(
    'lib/screens/home_shell.dart',
    """                Text(\n                  'A HEALTHIER TOMORROW\\nLIVES IN A MORE AWARE TODAY.',\n                  maxLines: 2,\n                  style: TextStyle(""",
    """                FittedBox(\n                  fit: BoxFit.scaleDown,\n                  alignment: Alignment.centerLeft,\n                  child: Text(\n                    'A HEALTHIER TOMORROW\\nLIVES IN A MORE AWARE TODAY.',\n                    maxLines: 2,\n                    style: TextStyle(""",
    'Header tagline scale-down start',
)
patch_once(
    'lib/screens/home_shell.dart',
    """                    letterSpacing: 1.55,\n                    height: 1.35,\n                  ),\n                ),\n              ],""",
    """                      letterSpacing: 1.55,\n                      height: 1.35,\n                    ),\n                  ),\n                ),\n              ],""",
    'Header tagline scale-down close',
)

# Home provider names such as Garmin Connect / Samsung Health must be fully visible.
patch_once(
    'lib/widgets/salus_widgets.dart',
    """          label,\n          maxLines: 1,\n          overflow: TextOverflow.ellipsis,\n          textAlign: TextAlign.center,""",
    """          label,\n          maxLines: 2,\n          softWrap: true,\n          textAlign: TextAlign.center,""",
    'Home provider-name wrapping',
)

# The detailed Sources screen should follow the same rule instead of truncating
# the currently selected provider or its metric list.
patch_once(
    'lib/screens/sources_screen.dart',
    """                  current,\n                  maxLines: 2,\n                  overflow: TextOverflow.ellipsis,""",
    """                  current,\n                  maxLines: 3,\n                  softWrap: true,""",
    'Sources current-provider wrapping',
)
patch_once(
    'lib/screens/sources_screen.dart',
    """                  metrics,\n                  maxLines: 3,\n                  overflow: TextOverflow.ellipsis,""",
    """                  metrics,\n                  maxLines: 5,\n                  softWrap: true,""",
    'Sources provider-metrics wrapping',
)

# Give Sleep Stages its own visual identity in the source selector.
patch_once(
    'lib/screens/sources_screen.dart',
    """        'Sleep' => Icons.bedtime_rounded,\n        'Heart rate' => Icons.favorite_rounded,""",
    """        'Sleep' => Icons.bedtime_rounded,\n        'Sleep Stages' => Icons.bedtime_off_rounded,\n        'Heart rate' => Icons.favorite_rounded,""",
    'Sleep Stages source icon',
)
patch_once(
    'lib/screens/sources_screen.dart',
    """        'Sleep' => AppTheme.purple,\n        'Heart rate' => AppTheme.rose,""",
    """        'Sleep' => AppTheme.purple,\n        'Sleep Stages' => AppTheme.purple,\n        'Heart rate' => AppTheme.rose,""",
    'Sleep Stages source color',
)

# --- Activity axis visibility + text-overrun protection -------------------------
patch_once(
    'lib/widgets/step_bar_chart.dart',
    '                reservedSize: 46,',
    '                reservedSize: 58,',
    'Step axis reserved width',
)
patch_once(
    'lib/widgets/step_bar_chart.dart',
    '                        color: AppTheme.textMuted,',
    '                        color: AppTheme.textSecondary,',
    'High-contrast Step axis labels',
)
patch_once(
    'lib/widgets/step_bar_chart.dart',
    '                        fontSize: 10.5,',
    '                        fontSize: 12.5,',
    'Readable Step axis labels',
)

# Shared card text should wrap/scale instead of being silently clipped with ellipses.
patch_once(
    'lib/widgets/design_widgets.dart',
    "          Text(\n            label,\n            maxLines: 2,\n            overflow: TextOverflow.ellipsis,",
    "          Text(\n            label,\n            maxLines: 3,\n            softWrap: true,",
    'Metric-card label wrapping',
)
patch_once(
    'lib/widgets/design_widgets.dart',
    "          Text(\n            value,\n            maxLines: 1,\n            overflow: TextOverflow.ellipsis,",
    "          FittedBox(\n            fit: BoxFit.scaleDown,\n            alignment: Alignment.centerLeft,\n            child: Text(\n              value,\n              maxLines: 1,",
    'Metric-card value scale-down start',
)
# Close the FittedBox introduced above. Target only the value Text style block.
patch_once(
    'lib/widgets/design_widgets.dart',
    "              fontSize: 18,\n              fontWeight: FontWeight.w900,\n            ),\n          ),\n          if (detail != null)",
    "                fontSize: 18,\n                fontWeight: FontWeight.w900,\n              ),\n            ),\n          ),\n          if (detail != null)",
    'Metric-card value scale-down close',
)
patch_once(
    'lib/widgets/design_widgets.dart',
    "              detail!,\n              maxLines: 2,\n              overflow: TextOverflow.ellipsis,",
    "              detail!,\n              maxLines: 3,\n              softWrap: true,",
    'Metric-card detail wrapping',
)
# Tabs keep the full label visible on narrow phones without changing the tab layout.
patch_once(
    'lib/widgets/design_widgets.dart',
    "                  child: Text(\n                    label,\n                    textAlign: TextAlign.center,\n                    style: TextStyle(",
    "                  child: FittedBox(\n                    fit: BoxFit.scaleDown,\n                    child: Text(\n                      label,\n                      maxLines: 1,\n                      textAlign: TextAlign.center,\n                      style: TextStyle(",
    'Tab label scale-down start',
)
patch_once(
    'lib/widgets/design_widgets.dart',
    "                      fontSize: 13,\n                      fontWeight: FontWeight.w800,\n                    ),\n                  ),\n                ),",
    "                        fontSize: 13,\n                        fontWeight: FontWeight.w800,\n                      ),\n                    ),\n                  ),\n                ),",
    'Tab label scale-down close',
)

# --- Versioned source label -----------------------------------------------------
# The generic branding pass above normally handles this. Assert it explicitly.
require('lib/screens/sources_screen.dart', 'Beta 0.14.0+19 • Salus Source Registry', 'build 19 source-registry label')

# --- Build-19 contract assertions ----------------------------------------------
for path_name, needle, label in [
    ('lib/widgets/module_menu_button.dart', 'HealthyMeModule.workout', 'Workout is a top-level module'),
    ('lib/app.dart', "'/workout': (_) => const WorkoutScreen()", 'Workout named route'),
    ('lib/screens/home_shell.dart', "pushNamed('/workout')", 'Main module can open Workout'),
    ('lib/screens/workout_screen.dart', 'current: HealthyMeModule.workout', 'Workout identifies itself as a module'),
    ('lib/services/health_connect_service.dart', "resolvedOrigin('Sleep Stages', sleepStageTypes)", 'Sleep Stages resolves its own provider'),
    ('lib/services/health_connect_service.dart', "'Sleep Stages': recordCountsFor('Sleep Stages', sleepStageTypes)", 'Sleep Stages has source choices'),
    ('lib/screens/sleep_screen.dart', "h.resolvedSources['Sleep Stages']", 'Sleep UI reads stage provenance'),
    ('lib/screens/sources_screen.dart', "'Sleep Stages'", 'Sources screen exposes Sleep Stages'),
    ('lib/widgets/step_bar_chart.dart', 'reservedSize: 58', 'Activity Y-axis has visible label space'),
    ('lib/widgets/step_bar_chart.dart', 'fontSize: 12.5', 'Activity Y-axis meets readability floor'),
    ('lib/widgets/step_bar_chart.dart', 'color: AppTheme.textSecondary', 'Activity Y-axis uses visible text contrast'),
    ('lib/widgets/design_widgets.dart', 'fit: BoxFit.scaleDown', 'Narrow labels scale without clipping'),
    ('lib/screens/activity_screen.dart', "'Source: $stepSourceLabel',\n                          maxLines: 2,\n                          softWrap: true,", 'Activity source wraps'),
    ('lib/screens/sleep_screen.dart', "'Source: $sleepSourceLabel',\n                      maxLines: 2,\n                      softWrap: true,", 'Sleep source wraps'),
    ('lib/screens/sleep_screen.dart', "'Stages from: $stageSourceLabel',\n                  maxLines: 2,\n                  softWrap: true,", 'Sleep Stages source wraps'),
    ('lib/screens/home_shell.dart', 'fit: BoxFit.scaleDown', 'Header tagline scales instead of clipping'),
    ('lib/widgets/salus_widgets.dart', "label,\n          maxLines: 2,\n          softWrap: true,", 'Home provider names wrap'),
    ('lib/screens/sources_screen.dart', "current,\n                  maxLines: 3,\n                  softWrap: true,", 'Sources current provider wraps'),
]:
    require(path_name, needle, label)

for path_name, needle, label in [
    ('lib/screens/sleep_screen.dart', "h.resolvedSources['Sleep Stages'] ?? h.resolvedSources['Sleep']", 'Sleep Stages must not borrow generic Sleep provenance'),
    ('lib/screens/activity_screen.dart', 'MaterialPageRoute<void>(builder: (_) => const WorkoutScreen())', 'Workout must not be a detail-page-only route'),
    ('lib/screens/activity_screen.dart', "import 'workout_screen.dart';", 'Activity obsolete Workout import'),
    ('lib/widgets/step_bar_chart.dart', 'fontSize: 10.5', 'Step-axis labels below 12sp'),
    ('lib/screens/activity_screen.dart', "'Source: $stepSourceLabel',\n                          maxLines: 1,\n                          overflow: TextOverflow.ellipsis,", 'Activity source truncation'),
    ('lib/screens/sleep_screen.dart', "'Stages from: $stageSourceLabel',\n                  maxLines: 1,\n                  overflow: TextOverflow.ellipsis,", 'Sleep Stages source truncation'),
    ('lib/widgets/salus_widgets.dart', "label,\n          maxLines: 1,\n          overflow: TextOverflow.ellipsis,", 'Home provider-name truncation'),
    ('lib/screens/sources_screen.dart', "current,\n                  maxLines: 2,\n                  overflow: TextOverflow.ellipsis,", 'Sources provider truncation'),
]:
    forbid(path_name, needle, label)

# Preserve package/application id, signing identity, and launcher behavior.
manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    fail('AndroidManifest.xml missing')
text = manifest.read_text()
text, count = re.subn(r'android:label="[^"]*"', 'android:label="Salus"', text, count=1)
if count != 1:
    fail('Android application label not found')
manifest.write_text(text)

src_root = Path('branding/android')
res_root = Path('android/app/src/main/res')
for folder in ('mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi'):
    src = src_root / folder / 'ic_launcher.png'
    if not src.exists():
        fail(f'missing {src}')
    dst_dir = res_root / folder
    dst_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst_dir / 'ic_launcher.png')

print('Salus build 19 (v0.14.0+19) functional patch + guards applied.')
