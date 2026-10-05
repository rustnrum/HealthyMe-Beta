from pathlib import Path
import re, shutil

VERSION_OLD = '0.11.0+15'
VERSION_NEW = '0.12.0+16'

# Preserve package/application id and persisted state keys for in-place upgrade.
pub = Path('pubspec.yaml')
text = pub.read_text()
text = text.replace("description: Healthy Me - a personal body command center.", "description: Salus by Rust N Rum - a personal health journal and body command center.")
text = text.replace(f'version: {VERSION_OLD}', f'version: {VERSION_NEW}')
pub.write_text(text)

# Update user-visible product naming without renaming internal classes/storage ids.
for path in Path('lib').rglob('*.dart'):
    text = path.read_text()
    text = text.replace('Healthy Me', 'Salus')
    text = text.replace('Beta 0.11.0+15 • Salus Source Registry', 'Beta 0.12.0+16 • Salus Source Registry')
    path.write_text(text)

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text()
text, count = re.subn(r'android:label="[^"]*"', 'android:label="Salus"', text, count=1)
if count != 1:
    raise SystemExit('Salus brand patch: Android application label not found')
manifest.write_text(text)

src_root = Path('branding/android')
res_root = Path('android/app/src/main/res')
for folder in ('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi'):
    src = src_root / folder / 'ic_launcher.png'
    if not src.exists():
        raise SystemExit(f'Salus brand patch: missing {src}')
    dst_dir = res_root / folder
    dst_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst_dir / 'ic_launcher.png')

print('Salus v0.12 branding + launcher icon applied.')
