"""Build 90 is a view-only release on top of already-migrated Build 89.

Do NOT replay the destructive Build 89 hardware-removal migration. It was
committed to the repository by successful Build 89 and is not repeatable.
This preflight only asserts project identity and updates obsolete version-only
assertions in the existing tests; it changes no application data or modules.
"""
from pathlib import Path

assert 'version: 0.21.52+90' in Path('pubspec.yaml').read_text()
assert 'com.rustnrum.healthyme.beta03' in Path('scripts/prepare_android.sh').read_text()
assert 'BLUETOOTH' not in Path('native/android/AndroidManifest.xml').read_text()
assert Path('lib/screens/premium/salus_home_87.dart').exists()
assert Path('assets/premium/salus_wordmark_90.png').exists()

for filename in [
    'test/build86_preservation_contract_test.dart',
    'test/build87_visual_preservation_test.dart',
    'test/build89_health_connect_only_test.dart',
    'test/build76_light_dark_navigation_contract_test.dart',
]:
    path = Path(filename)
    old = path.read_text()
    if 'version: 0.21.51+89' in old:
        path.write_text(old.replace('version: 0.21.51+89',
                                    'version: 0.21.52+90'))
    elif 'version: 0.21.52+90' not in old:
        raise RuntimeError(f'Unexpected version assertion in {filename}')

path = Path('test/build75_dark_premium_contract_test.dart')
s = path.read_text()
a = '50|51)\\+(75|76|77|78|79|80|81|82|83|84|85|86|87|88|89)'
b = '50|51|52)\\+(75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90)'
if a in s:
    path.write_text(s.replace(a, b))
elif b not in s:
    raise RuntimeError('Build 75 version checker changed unexpectedly')

# Build 89 removed protocol assets; Flutter fails analysis if restored here.
assert 'assets/protocols/' not in Path('pubspec.yaml').read_text()
