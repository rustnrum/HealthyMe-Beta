from pathlib import Path
import re
import shutil
import struct

VERSION_NEW = '0.14.0+23'
SUPPORTED_OLD = {'0.14.0+20', '0.14.0+21', '0.14.0+22'}


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 23 direct-device hub patch: {message}')


def require(path_name: str, needle: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists() or needle not in path.read_text():
        fail(f'{label} missing from {path_name}: {needle}')


def forbid(path_name: str, needle: str, label: str) -> None:
    path = Path(path_name)
    if path.exists() and needle in path.read_text():
        fail(f'{label} still present in {path_name}: {needle}')


def replace_once(path_name: str, old: str, new: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists():
        fail(f'missing {path_name} while applying {label}')
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        fail(f'{path_name} no longer matches expected source for {label}')
    path.write_text(text.replace(old, new, 1))


def replace_segment(path_name: str, start_marker: str, end_marker: str, replacement: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists():
        fail(f'missing {path_name} while applying {label}')
    text = path.read_text()
    if replacement in text:
        return
    start = text.find(start_marker)
    if start < 0:
        fail(f'{path_name} missing start marker for {label}')
    end = text.find(end_marker, start)
    if end < 0:
        fail(f'{path_name} missing end marker for {label}')
    path.write_text(text[:start] + replacement + text[end:])


# --- Version / build label ------------------------------------------------------
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
pub.write_text(text)

for path in Path('lib').rglob('*.dart'):
    text = path.read_text()
    text = re.sub(
        r'Beta 0\.14\.0\+(?:20|21|22|23) • Salus Source Registry',
        'Beta 0.14.0+23 • Salus Source Registry',
        text,
    )
    path.write_text(text)


# --- Home: compact date strip from build 21 ------------------------------------
home = Path('lib/screens/home_screen.dart')
home_text = home.read_text()
if 'SalusAssets.calloutSameMe' in home_text:
    old = """      child: ListView(\n        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),\n        children: [\n          Row(\n            crossAxisAlignment: CrossAxisAlignment.end,\n            children: [\n              Expanded(\n                child: Text(\n                  _date(),\n                  style: const TextStyle(\n                    color: AppTheme.textPrimary,\n                    fontSize: 14,\n                    fontWeight: FontWeight.w700,\n                    letterSpacing: 2.0,\n                  ),\n                ),\n              ),\n              Opacity(\n                opacity: 0.76,\n                child: Image.asset(SalusAssets.calloutSameMe, width: 142, height: 54, fit: BoxFit.contain),\n              ),\n            ],\n          ),\n          const Divider(height: 8, thickness: 0.8),\n          const SizedBox(height: 8),"""
    new = """      child: ListView(\n        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),\n        children: [\n          Text(\n            _date(),\n            style: const TextStyle(\n              color: AppTheme.textPrimary,\n              fontSize: 14,\n              fontWeight: FontWeight.w700,\n              letterSpacing: 2.0,\n            ),\n          ),\n          const SizedBox(height: 2),\n          const Divider(height: 4, thickness: 0.8),\n          const SizedBox(height: 4),"""
    if old not in home_text:
        fail('build-20 date strip no longer matches expected source')
    home_text = home_text.replace(old, new, 1)
    home.write_text(home_text)
else:
    require('lib/screens/home_screen.dart', 'EdgeInsets.fromLTRB(12, 8, 12, 24)', 'compact Home top padding')


# --- Home: remove source-summary helper and redundant state ---------------------
home_text = home.read_text()
if '  String _sourceAsset(String label) {' in home_text:
    start = home_text.find('  String _sourceAsset(String label) {')
    end = home_text.find('  Future<void> _sync(WidgetRef ref) async {', start)
    if end < 0:
        fail('could not locate end of _sourceAsset helper')
    home_text = home_text[:start] + home_text[end:]
    home.write_text(home_text)

home_text = home.read_text()
old_state = """    final bodyLine = h.bodyFatPercent == null\n        ? 'Body fat — awaiting scale'\n        : 'Body fat ${h.bodyFatPercent!.toStringAsFixed(1)}%';\n    final sleepSourceKey = h.resolvedSources['Sleep'];\n    final sleepSource = sleepSourceKey == null ? null : (h.sourceLabels[sleepSourceKey] ?? sleepSourceKey);\n    final detected = h.detectedSources.take(3).toList();\n    final latestState = app.dailyStates.isEmpty ? null : app.dailyStates.last;\n"""
if old_state in home_text:
    home_text = home_text.replace(old_state, '', 1)
    home.write_text(home_text)


# --- Home: add dynamic overnight-signals widget import --------------------------
home_text = home.read_text()
import_line = "import '../widgets/overnight_signals_card.dart';\n"
if import_line not in home_text:
    anchor = "import '../widgets/salus_widgets.dart';\n"
    if anchor not in home_text:
        fail('home Salus widget import anchor missing')
    home_text = home_text.replace(anchor, anchor + import_line, 1)
    home.write_text(home_text)


# --- Today metrics become shortcuts to their detail pages -----------------------
def add_metric_on_tap(asset_name: str, callback: str, label: str) -> None:
    path = Path('lib/screens/home_screen.dart')
    text = path.read_text()
    marker = f"asset: SalusAssets.{asset_name},"
    pos = text.find(marker)
    if pos < 0:
        fail(f'Home missing {label} metric asset: {asset_name}')
    block_start = text.rfind('SalusMetric(', 0, pos)
    if block_start < 0:
        fail(f'Home missing SalusMetric start for {label}')
    open_paren = text.find('(', block_start)
    depth = 0
    close_paren = -1
    for index in range(open_paren, len(text)):
        char = text[index]
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                close_paren = index
                break
    if close_paren < 0:
        fail(f'Home missing SalusMetric end for {label}')
    block = text[block_start:close_paren]
    if 'onTap:' in block:
        return
    before = text[:close_paren]
    last_nonspace = len(before.rstrip()) - 1
    if last_nonspace < 0:
        fail(f'Home malformed SalusMetric for {label}')
    if before[last_nonspace] == ',':
        line_start = text.rfind('\n', 0, close_paren) + 1
        closing_indent = re.match(r'\s*', text[line_start:close_paren]).group(0)
        arg_indent = closing_indent + '  '
        insertion = f"\n{arg_indent}onTap: {callback},"
    else:
        insertion = f", onTap: {callback}"
    text = text[:close_paren] + insertion + text[close_paren:]
    path.write_text(text)


add_metric_on_tap(
    'metricWeight',
    '() => ref.read(navigationProvider.notifier).go(3)',
    'Weight',
)
add_metric_on_tap(
    'metricSleep',
    '() => ref.read(navigationProvider.notifier).go(2)',
    'Sleep',
)
add_metric_on_tap(
    'metricSteps',
    '() => ref.read(navigationProvider.notifier).go(1)',
    'Steps',
)
add_metric_on_tap(
    'metricRecovery',
    "() => Navigator.of(context).pushNamed('/recovery')",
    'Recovery',
)


# --- Home: replace redundant Body/Sleep/Activity/Check-in/Sources stack ---------
start_marker = """          const SizedBox(height: 11),\n          SalusModuleRow(\n            tileAsset: SalusAssets.tileBody,"""
end_marker = """          const SizedBox(height: 11),\n          Row(\n            children: [\n              SalusQuickAction("""
new_segment = """          const SizedBox(height: 11),\n          OvernightSignalsCard(\n            report: recovery,\n            onSignalTap: (name) {\n              if (name == 'Sleep') {\n                ref.read(navigationProvider.notifier).go(2);\n              } else {\n                Navigator.of(context).pushNamed('/trends');\n              }\n            },\n            onViewTrends: () => Navigator.of(context).pushNamed('/trends'),\n          ),\n"""
replace_segment(
    'lib/screens/home_screen.dart',
    start_marker,
    end_marker,
    new_segment,
    'replace redundant Home modules and Sources with overnight signals',
)

# Trends quick action must open a real Trends screen, not the More tab.
home_text = Path('lib/screens/home_screen.dart').read_text()
patched_trends = r"onTap:\s*\(\)\s*=>\s*Navigator\.of\(context\)\.pushNamed\('/trends'\)"
if re.search(patched_trends, home_text) is None:
    pattern = r"onTap:\s*\(\)\s*=>\s*ref\.read\(navigationProvider\.notifier\)\.go\(4\)"
    home_text, count = re.subn(
        pattern,
        "onTap: () => Navigator.of(context).pushNamed('/trends')",
        home_text,
        count=1,
    )
    if count != 1:
        fail('Home no longer matches expected Trends quick action route')
    Path('lib/screens/home_screen.dart').write_text(home_text)


# --- SalusMetric becomes tappable without changing visual styling ---------------
widgets = Path('lib/widgets/salus_widgets.dart')
widgets_text = widgets.read_text()
metric_start = widgets_text.find('class SalusMetric extends StatelessWidget {')
metric_end = widgets_text.find('class SalusModuleRow extends StatelessWidget {', metric_start)
if metric_start < 0 or metric_end < 0:
    fail('SalusMetric class markers missing')
new_metric_class = """class SalusMetric extends StatelessWidget {
  final IconData? icon;
  final String? asset;
  final String value;
  final String label;
  final Color tint;
  final VoidCallback? onTap;
  const SalusMetric({
    super.key,
    this.icon,
    this.asset,
    required this.value,
    required this.label,
    this.tint = AppTheme.mint,
    this.onTap,
  }) : assert(icon != null || asset != null);

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asset != null)
            SizedBox(
              width: 52,
              height: 52,
              child: Image.asset(
                asset!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: 0.16)),
              child: Icon(icon, color: tint, size: 25),
            ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.45,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: 'Open $label details',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      ),
    );
  }
}

"""
# Only replace if the build-22 version is not already there.
if 'final VoidCallback? onTap;' not in widgets_text[metric_start:metric_end]:
    widgets_text = widgets_text[:metric_start] + new_metric_class + widgets_text[metric_end:]
    widgets.write_text(widgets_text)


# --- Named routes for Recovery and real Trends page -----------------------------
app = Path('lib/app.dart')
app_text = app.read_text()
anchor = "import 'screens/onboarding_screen.dart';\n"
if anchor not in app_text:
    fail('app import anchor missing')
if "import 'screens/recovery_detail_screen.dart';" not in app_text:
    app_text = app_text.replace(anchor, anchor + "import 'screens/recovery_detail_screen.dart';\n", 1)
if "import 'screens/trends_screen.dart';" not in app_text:
    app_text = app_text.replace(anchor, anchor + "import 'screens/trends_screen.dart';\n", 1)
if "'/trends': (_) => const TrendsScreen()," not in app_text:
    anchor = "        '/workout': (_) => const WorkoutScreen(),\n"
    if anchor not in app_text:
        fail('app route anchor missing')
    app_text = app_text.replace(
        anchor,
        anchor + "        '/trends': (_) => const TrendsScreen(),\n        '/recovery': (_) => const RecoveryDetailScreen(),\n",
        1,
    )
app.write_text(app_text)


# --- Validate clean Sleep/Steps PNGs supplied by overlay ------------------------
for asset in (
    'lib/assets/salus/metric_sleep.png',
    'lib/assets/salus/metric_steps.png',
):
    path = Path(asset)
    if not path.exists() or path.stat().st_size < 1000:
        fail(f'clean metric asset missing or too small: {asset}')
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        fail(f'not a PNG: {asset}')
    width, height = struct.unpack('>II', data[16:24])
    if (width, height) != (512, 512):
        fail(f'{asset} must be 512x512, found {width}x{height}')


# --- Hard structural checks before Flutter analyze ------------------------------
forbid('lib/screens/home_screen.dart', 'SalusAssets.calloutSameMe', 'date-strip handwritten callout')
forbid('lib/screens/home_screen.dart', 'Connected to a clearer you', 'Home Sources section')
forbid('lib/screens/home_screen.dart', 'SalusModuleRow(', 'redundant Home module rows')
require('lib/screens/home_screen.dart', 'OvernightSignalsCard(', 'overnight signals card')
require('lib/screens/home_screen.dart', "pushNamed('/trends')", 'real Trends navigation')
require('lib/screens/home_screen.dart', "pushNamed('/recovery')", 'Recovery detail navigation')
require('lib/widgets/salus_widgets.dart', 'final VoidCallback? onTap;', 'clickable Today metrics')
require('lib/app.dart', "'/trends': (_) => const TrendsScreen()", 'Trends route')
require('lib/app.dart', "'/recovery': (_) => const RecoveryDetailScreen()", 'Recovery route')
require('lib/screens/trends_screen.dart', 'class TrendsScreen', 'Trends screen')
require('lib/widgets/overnight_signals_card.dart', 'class OvernightSignalsCard', 'overnight signals widget')


# Android visible identity remains Salus; package id/signing are intentionally untouched.
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

print('Salus build 23 direct-device hub base UI applied.')
