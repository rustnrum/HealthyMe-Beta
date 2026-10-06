from pathlib import Path
import re
import shutil

VERSION = '0.14.0+24'


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 24 visual-system patch: {message}')


pub = Path('pubspec.yaml')
if not pub.exists():
    fail('pubspec.yaml missing')
text = pub.read_text()
match = re.search(r'^version:\s*(\S+)\s*$', text, flags=re.M)
if match is None:
    fail('pubspec version line missing')
if match.group(1) != VERSION:
    fail(f'expected {VERSION}, found {match.group(1)}')

# Update the direct-device source screen without replacing its build-23 pairing,
# persistence, protocol inspection, or per-metric routing logic.
sources = Path('lib/screens/sources_screen.dart')
if sources.exists():
    s = sources.read_text()
    # The build-23 identity card displayed this constant. Build 24 replaces that
    # card, so remove the constant rather than leaving an analyzer warning.
    s = re.sub(
        r"  static const _buildLabel = 'Beta 0\.14\.0\+\d+ • Salus Source Registry';\n(?:[ \t]*\n)?",
        "",
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

    marker = "          const HmSectionHeader(title: 'Pair direct devices'),\n"
    if 'SalusDeviceTypeCard(' not in s:
        if marker not in s:
            fail('Nearby devices header anchor missing')
        strip = '''          SizedBox(
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
          const SizedBox(height: 22),
'''
        s = s.replace(marker, strip + marker, 1)

    old_copy = (
        "            'Bluetooth is used to identify devices and capabilities. A device is '\n"
        "            'not selectable as a metric source until Salus can actually read '\n"
        "            'that metric from it.',"
    )
    new_copy = (
        "            'Scan, identify and save hardware directly to Salus. A device only '\n"
        "            'becomes a metric source after its protocol reader can decode that metric.',"
    )
    s = s.replace(old_copy, new_copy, 1)
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

src_root = Path('branding/android')
res_root = Path('android/app/src/main/res')
for folder in ('mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi'):
    src = src_root / folder / 'ic_launcher.png'
    if not src.exists():
        fail(f'missing launcher source {src}')
    dst = res_root / folder
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst / 'ic_launcher.png')

print('Salus build 24 visual system + direct-device source styling applied.')
