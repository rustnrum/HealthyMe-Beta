"""Build92: additive Workout model/editor + Home presentation update.
Fail closed on unexpected changes; never rerun obsolete Bluetooth cleanup.
"""
from pathlib import Path
from runpy import run_path

assert 'version: 0.21.54+92' in Path('pubspec.yaml').read_text()
assert 'com.rustnrum.healthyme.beta03' in Path('scripts/prepare_android.sh').read_text()
assert 'BLUETOOTH' not in Path('native/android/AndroidManifest.xml').read_text()
assert 'assets/protocols/' not in Path('pubspec.yaml').read_text()
run_path('scripts/build92_workout_fields.py', run_name='__main__')

# Retain existing regression checks. Only update old hard-coded version strings.
for filename in [
    'test/build86_preservation_contract_test.dart',
    'test/build87_visual_preservation_test.dart',
    'test/build89_health_connect_only_test.dart',
    'test/build76_light_dark_navigation_contract_test.dart',
]:
    p = Path(filename)
    old = p.read_text()
    assert old.count('version: 0.21.53+91') == 1, filename
    p.write_text(old.replace('version: 0.21.53+91', 'version: 0.21.54+92'))

p = Path('test/build75_dark_premium_contract_test.dart')
s = p.read_text()
a = r'50|51|52|53)\+(75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91)'
b = r'50|51|52|53|54)\+(75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92)'
assert s.count(a) == 1, 'Version contract changed unexpectedly'
p.write_text(s.replace(a,b))

# Do not change the app ID, signing, meal and health services, or approved art.
assert 'SalusHome87()' in Path('lib/screens/home_shell.dart').read_text()
assert 'assets/premium/salus_wordmark_90.png' in Path('lib/screens/premium/salus_home_87.dart').read_text()
assert 'HomeInsightService.build(app)' in Path('lib/screens/premium/salus_home_87.dart').read_text()
