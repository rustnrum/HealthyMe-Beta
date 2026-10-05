from pathlib import Path
import re
import shutil

VERSION_NEW = '0.14.0+18'
SUPPORTED_OLD = {'0.11.0+15', '0.12.0+16', '0.13.0+17'}

# Preserve package/application id, signing identity, and persisted state keys for in-place upgrade.
pub = Path('pubspec.yaml')
text = pub.read_text()
match = re.search(r'^version:\s*(\S+)\s*$', text, flags=re.M)
if match is None:
    raise SystemExit('Salus brand patch: pubspec version line not found')
current = match.group(1)
if current in SUPPORTED_OLD:
    text = re.sub(r'^version:\s*\S+\s*$', f'version: {VERSION_NEW}', text, count=1, flags=re.M)
elif current != VERSION_NEW:
    raise SystemExit(
        f'Salus brand patch: unsupported source version {current}; '
        f'expected one of {sorted(SUPPORTED_OLD | {VERSION_NEW})}'
    )
text = text.replace(
    'description: Healthy Me - a personal body command center.',
    'description: Salus by Rust N Rum - a personal health journal and body command center.',
)
pub.write_text(text)

# Update only user-visible product naming/version text. Internal storage/package ids stay unchanged.
for path in Path('lib').rglob('*.dart'):
    text = path.read_text()
    text = text.replace('Healthy Me', 'Salus')
    text = re.sub(
        r'Beta 0\.(?:11|12|13)\.0\+(?:15|16|17) • Salus Source Registry',
        'Beta 0.14.0+18 • Salus Source Registry',
        text,
    )
    path.write_text(text)

manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    raise SystemExit('Salus brand patch: AndroidManifest.xml missing')
text = manifest.read_text()
text, count = re.subn(r'android:label="[^"]*"', 'android:label="Salus"', text, count=1)
if count != 1:
    raise SystemExit('Salus brand patch: Android application label not found')
manifest.write_text(text)

src_root = Path('branding/android')
res_root = Path('android/app/src/main/res')
for folder in ('mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi'):
    src = src_root / folder / 'ic_launcher.png'
    if not src.exists():
        raise SystemExit(f'Salus brand patch: missing {src}')
    dst_dir = res_root / folder
    dst_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst_dir / 'ic_launcher.png')

print('Salus v0.14 branding + launcher icon applied.')
