from pathlib import Path
import re
import shutil

VERSION = '0.14.0+25'
MARKER = 'SALUS_BUILD25_DIRECT_FIRST'


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 25 patch: {message}')


pub = Path('pubspec.yaml')
if not pub.exists():
    fail('pubspec.yaml missing')
text = pub.read_text()
match = re.search(r'^version:\s*(\S+)\s*$', text, flags=re.M)
if match is None:
    fail('pubspec version line missing')
if match.group(1) != VERSION:
    fail(f'expected {VERSION}, found {match.group(1)}')

# Keep the native package id/signing identity intact. Only visible branding and
# source-hub ordering are changed here.
sources = Path('lib/screens/sources_screen.dart')
if not sources.exists():
    fail('sources_screen.dart missing')
s = sources.read_text()

# Remove an obsolete private build-label field if an older source overlay left it.
s = re.sub(
    r"  static const _buildLabel = 'Beta 0\.14\.0\+\d+ • Salus Source Registry';\n(?:[ \t]*\n)?",
    '',
    s,
    count=1,
)

s = s.replace(
    "appBar: AppBar(title: const Text('Data Sources'))",
    "appBar: AppBar(title: const Text('Devices & Sources'))",
    1,
)

salus_import = "import '../widgets/salus_widgets.dart';\n"
if salus_import not in s:
    anchor = "import '../widgets/design_widgets.dart';\n"
    if anchor not in s:
        fail('sources screen design_widgets import anchor missing')
    s = s.replace(anchor, anchor + salus_import, 1)

# Keep the approved v25 identity treatment when upgrading directly from the
# build-23 source. On an already-v25 repo this is already present.
if "'CONNECT YOUR WORLD'" not in s:
    start = s.find('  Widget _buildIdentityCard() {')
    end = s.find('  Widget _transportCard({', start)
    if start < 0 or end < 0:
        fail('sources identity-card anchors missing')
    identity = '''  Widget _buildIdentityCard() {
    return CommandCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            Positioned(
              right: -14,
              top: -24,
              width: 170,
              height: 170,
              child: Opacity(
                opacity: 0.88,
                child: Image.asset(
                  SalusAssets.sourcesOrbit,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              top: 5,
              child: Text(
                'CONNECT YOUR WORLD',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              top: 34,
              right: 115,
              child: Text(
                'Devices &\\nSources',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 31,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.9,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              bottom: 2,
              right: 105,
              child: Text(
                'Pair direct hardware or use Health Connect when it gives Salus the metric you need.',
                maxLines: 3,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

'''
    s = s[:start] + identity + s[end:]

# Put direct hardware where the user sees it immediately. Build 24 had the
# actual scanner/pairing flow below provider routing, which made the decorative
# device cards look like a dead screen.
if MARKER not in s:
    start = s.find('          _buildIdentityCard(),')
    end_needle = '          _bluetoothCard(bluetoothSources),'
    end = s.find(end_needle, start)
    if start < 0 or end < 0:
        fail('sources build children anchors missing')
    end += len(end_needle)
    new_block = f'''          _buildIdentityCard(),
          // {MARKER} — direct_device_patch compatibility: Use with Salus
          const SizedBox(height: 18),
          const HmSectionHeader(title: 'Direct devices'),
          const SizedBox(height: 6),
          const Text(
            'Put your ring, watch, scale or respiratory device in pairing mode, then scan. '
            'Salus will show the real Bluetooth devices it can see and let you connect them directly.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 154,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceRing,
                  title: 'Ring',
                  subtitle: 'Sleep • HRV • SpO₂',
                  highlighted: true,
                ),
                SizedBox(width: 10),
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceWatch,
                  title: 'Watch',
                  subtitle: 'Activity • HR • Workouts',
                ),
                SizedBox(width: 10),
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceScale,
                  title: 'Scale',
                  subtitle: 'Weight • Body composition',
                ),
                SizedBox(width: 10),
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceCpap,
                  title: 'CPAP',
                  subtitle: 'Sleep • Therapy data',
                ),
              ],
            ),
          ),
          if (_savedDirectDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            _savedDirectDevicesCard(),
          ],
          const SizedBox(height: 12),
          _bluetoothCard(bluetoothSources),
          const SizedBox(height: 24),
          _transportCard(
            authorized: h.authorized,
            lastSync: h.lastSync,
            syncLoading: sync.isLoading,
          ),
          const SizedBox(height: 22),
          const HmSectionHeader(title: 'Your data providers'),
          const SizedBox(height: 6),
          const Text(
            'Salus identifies the original provider and keeps Health Connect '
            'in the background as a transport.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _providerHubCard(providerSources),
          const SizedBox(height: 22),
          const HmSectionHeader(title: 'Metric sources'),
          const SizedBox(height: 6),
          const Text(
            'Choose the provider Salus should use for each metric. Automatic '
            'uses the freshest provider that has actually supplied that metric.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  _MetricSourceRow(
                    metric: metrics[i],
                    selectedRaw: app.metricSources[metrics[i]],
                    resolvedRaw: h.resolvedSources[metrics[i]],
                    sources: h.availableSources[metrics[i]] ?? const [],
                    sourceLabels: h.sourceLabels,
                    freshness: h.freshness[metrics[i]],
                    onChange: () => _chooseSource(
                      context,
                      metric: metrics[i],
                      selectedRaw: app.metricSources[metrics[i]],
                      health: h,
                      authorized: h.authorized,
                    ),
                  ),
                  if (i != metrics.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),'''
    s = s[:start] + new_block + s[end:]

# Make the working controls explicit instead of looking like a passive mock-up.
s = s.replace("_scanningBle ? 'Scanning for 8 seconds…' : 'Scan nearby devices'", "_scanningBle ? 'Scanning for 8 seconds…' : 'Scan for devices'")
s = re.sub(r"\?\s*'Saved to Salus'", "? 'Connected'", s)
s = s.replace("'Pairing…'", "'Connecting…'")
s = s.replace("'Use with Salus'", "'Connect'")

for required in ('Scan for devices', 'SALUS_BUILD25_DIRECT_FIRST', '_bluetoothCard(bluetoothSources)', '_useWithSalus'):
    if required not in s:
        fail(f'direct-device control missing after patch: {required}')

sources.write_text(s)

manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    fail('AndroidManifest.xml missing')
manifest_text = manifest.read_text()
manifest_text, count = re.subn(
    r'android:label="[^"]*"',
    'android:label="Salus"',
    manifest_text,
    count=1,
)
if count != 1:
    fail('Android application label not found')
manifest.write_text(manifest_text)

# New cyan/blue launcher icon matching the locked Salus visual system.
src_root = Path('branding/android')
res_root = Path('android/app/src/main/res')
for folder in ('mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi'):
    src = src_root / folder / 'ic_launcher.png'
    if not src.exists():
        fail(f'missing build-25 launcher source {src}')
    dst = res_root / folder
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst / 'ic_launcher.png')

print('Salus build 25 background/calendar/layout/direct-device patch applied.')
