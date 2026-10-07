from pathlib import Path
import re
import shutil

VERSION = '0.14.0+30'


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 30 brand patch: {message}')


pub = Path('pubspec.yaml')
if not pub.exists():
    fail('pubspec.yaml missing')
match = re.search(r'^version:\s*(\S+)\s*$', pub.read_text(), flags=re.M)
if match is None or match.group(1) != VERSION:
    fail(f'pubspec must identify {VERSION}')

manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    fail('AndroidManifest.xml missing')
text = manifest.read_text()
text, count = re.subn(
    r'android:label="[^"]*"',
    'android:label="Salus"',
    text,
    count=1,
)
if count != 1:
    fail('Android application label missing')
manifest.write_text(text)

src_root = Path('branding/android')
res_root = Path('android/app/src/main/res')
for folder in (
    'mipmap-mdpi',
    'mipmap-hdpi',
    'mipmap-xhdpi',
    'mipmap-xxhdpi',
    'mipmap-xxxhdpi',
):
    src = src_root / folder / 'ic_launcher.png'
    if not src.exists():
        fail(f'missing launcher source {src}')
    dst = res_root / folder
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst / 'ic_launcher.png')

print('Salus build 30 branding applied.')
