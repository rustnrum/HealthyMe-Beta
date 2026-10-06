from pathlib import Path
import re
import shutil

VERSION_NEW = '0.14.0+20'
SUPPORTED_OLD = {
    '0.11.0+15',
    '0.12.0+16',
    '0.13.0+17',
    '0.14.0+18',
    '0.14.0+19',
}


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 20 asset patch: {message}')


def patch_once(path_name: str, old: str, new: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists():
        fail(f'missing {path_name} while applying {label}')
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        fail(f'{path_name} no longer matches expected build-19 source for {label}')
    path.write_text(text.replace(old, new, 1))


def require(path_name: str, needle: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists() or needle not in path.read_text():
        fail(f'{label} missing from {path_name}: {needle}')


def forbid(path_name: str, needle: str, label: str) -> None:
    path = Path(path_name)
    if path.exists() and needle in path.read_text():
        fail(f'{label} still present in {path_name}: {needle}')


# Preserve package/application id, signing identity, and persisted state keys.
pub = Path('pubspec.yaml')
text = pub.read_text()
match = re.search(r'^version:\s*(\S+)\s*$', text, flags=re.M)
if match is None:
    fail('pubspec version line not found')
current = match.group(1)
if current in SUPPORTED_OLD:
    text = re.sub(r'^version:\s*\S+\s*$', f'version: {VERSION_NEW}', text, count=1, flags=re.M)
elif current != VERSION_NEW:
    fail(
        f'unsupported source version {current}; '
        f'expected one of {sorted(SUPPORTED_OLD | {VERSION_NEW})}'
    )
text = text.replace(
    'description: Healthy Me - a personal body command center.',
    'description: Salus by Rust N Rum - a personal health journal and body command center.',
)
pub.write_text(text)

# User-visible naming/build label only. Internal package/storage ids stay unchanged.
for path in Path('lib').rglob('*.dart'):
    text = path.read_text()
    text = text.replace('Healthy Me', 'Salus')
    text = re.sub(
        r'Beta 0\.(?:11|12|13|14)\.0\+(?:15|16|17|18|19) • Salus Source Registry',
        'Beta 0.14.0+20 • Salus Source Registry',
        text,
    )
    path.write_text(text)

# Add clean, isolated source-device assets. The overlay supplies the PNG files.
patch_once(
    'lib/widgets/salus_widgets.dart',
    "  static const String sourceScale = '$root/source_scale.png';\n  static const String sourceLabs = '$root/source_labs.png';",
    "  static const String sourceScale = '$root/source_scale.png';\n  static const String sourcePhone = '$root/source_phone.png';\n  static const String sourceHealth = '$root/source_health.png';\n  static const String sourceLabs = '$root/source_labs.png';",
    'new source-device asset constants',
)

# Metric PNGs contain their own shape/background. Do not circular-crop the source file.
patch_once(
    'lib/widgets/salus_widgets.dart',
    """        if (asset != null)
          ClipOval(
            child: Image.asset(asset!, width: 52, height: 52, fit: BoxFit.cover),
          )
        else""",
    """        if (asset != null)
          SizedBox(
            width: 52,
            height: 52,
            child: Image.asset(
              asset!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          )
        else""",
    'uncropped metric artwork',
)

# Preserve the tile art exactly; contain instead of cover prevents edge loss.
patch_once(
    'lib/widgets/salus_widgets.dart',
    "child: Image.asset(tileAsset!, width: 58, height: 58, fit: BoxFit.cover),",
    "child: Image.asset(tileAsset!, width: 58, height: 58, fit: BoxFit.contain, filterQuality: FilterQuality.high),",
    'module tile containment',
)

# The decorative sketches were being deliberately faded and undersized.
patch_once(
    'lib/widgets/salus_widgets.dart',
    """                Opacity(
                  opacity: 0.78,
                  child: Image.asset(artAsset!, width: 92, height: 64, fit: BoxFit.contain),
                ),""",
    """                Opacity(
                  opacity: 0.94,
                  child: Image.asset(
                    artAsset!,
                    width: 92,
                    height: 64,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),""",
    'stronger decorative artwork',
)

# Provider icons need enough pixels to read, but remain secondary to the provider name.
patch_once(
    'lib/widgets/salus_widgets.dart',
    "SizedBox(width: 34, height: 34, child: Image.asset(asset, fit: BoxFit.contain)),",
    "SizedBox(width: 34, height: 34, child: Image.asset(asset, fit: BoxFit.contain, filterQuality: FilterQuality.high)),",
    'high-quality source icon rendering',
)

# Route friendly provider labels to distinct generic device artwork. This is display-only;
# metric routing continues to use the stable Health Connect DataOrigin/provider ids.
patch_once(
    'lib/screens/home_screen.dart',
    """  String _sourceAsset(String label) {
    final value = label.toLowerCase();
    if (value.contains('ring') || value.contains('qring')) return SalusAssets.sourceRing;
    if (value.contains('scale') || value.contains('imoni')) return SalusAssets.sourceScale;
    return SalusAssets.sourceWatch;
  }""",
    """  String _sourceAsset(String label) {
    final value = label.toLowerCase();
    if (value.contains('ring') || value.contains('qring')) {
      return SalusAssets.sourceRing;
    }
    if (value.contains('scale') || value.contains('imoni')) {
      return SalusAssets.sourceScale;
    }
    if (value.contains('lab')) return SalusAssets.sourceLabs;
    if (value.contains('samsung') || value.contains('health')) {
      return SalusAssets.sourceHealth;
    }
    if (value.contains('phone') || value.contains('android')) {
      return SalusAssets.sourcePhone;
    }
    return SalusAssets.sourceWatch;
  }""",
    'distinct provider/device artwork',
)

# Android user-visible label and launcher stay Salus; package id/signing remain untouched.
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

# Hard checks so a stale/corrupt asset treatment never reaches flutter analyze.
for asset in (
    'lib/assets/salus/metric_recovery.png',
    'lib/assets/salus/source_watch.png',
    'lib/assets/salus/source_ring.png',
    'lib/assets/salus/source_scale.png',
    'lib/assets/salus/source_phone.png',
    'lib/assets/salus/source_health.png',
    'lib/assets/salus/source_labs.png',
):
    path = Path(asset)
    if not path.exists() or path.stat().st_size < 1000:
        fail(f'clean Salus asset missing or too small: {asset}')

require('lib/widgets/salus_widgets.dart', 'sourcePhone', 'phone source asset')
require('lib/widgets/salus_widgets.dart', 'sourceHealth', 'health-app source asset')
require('lib/widgets/salus_widgets.dart', 'filterQuality: FilterQuality.high', 'high-quality asset rendering')
require('lib/widgets/salus_widgets.dart', 'opacity: 0.94', 'decorative art visibility')
forbid('lib/widgets/salus_widgets.dart', 'ClipOval(', 'metric artwork crop')
require('lib/screens/home_screen.dart', "value.contains('samsung')", 'Samsung Health display artwork mapping')
require('lib/screens/home_screen.dart', "value.contains('phone')", 'phone display artwork mapping')

print('Salus build 20 clean asset treatment applied.')
