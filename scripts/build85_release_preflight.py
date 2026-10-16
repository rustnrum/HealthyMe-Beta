"""Build91: fail-closed view/recipe integration; never replay Build89 removals."""
from pathlib import Path
from runpy import run_path

assert 'version: 0.21.53+91' in Path('pubspec.yaml').read_text()
assert 'com.rustnrum.healthyme.beta03' in Path('scripts/prepare_android.sh').read_text()
assert 'BLUETOOTH' not in Path('native/android/AndroidManifest.xml').read_text()
assert 'assets/protocols/' not in Path('pubspec.yaml').read_text()
run_path('scripts/build91_integrate.py', run_name='__main__')

for filename in [
    'test/build86_preservation_contract_test.dart',
    'test/build87_visual_preservation_test.dart',
    'test/build89_health_connect_only_test.dart',
    'test/build76_light_dark_navigation_contract_test.dart',
]:
    path = Path(filename)
    old = path.read_text()
    if 'version: 0.21.52+90' in old:
        path.write_text(old.replace('version: 0.21.52+90', 'version: 0.21.53+91'))
    elif 'version: 0.21.53+91' not in old:
        raise RuntimeError(f'Unexpected version contract: {filename}')

p = Path('test/build75_dark_premium_contract_test.dart')
s = p.read_text()
old = '50|51|52)\\+(75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90)'
new = '50|51|52|53)\\+(75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91)'
if old in s:
    p.write_text(s.replace(old, new))
elif new not in s:
    raise RuntimeError('Obsolete version test changed unexpectedly')
