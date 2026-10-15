"""Build 85 source migration boundary and historical regression contract refresh.

The original Beta 84 code is fully migrated. Do not reapply patches 47-83.
Legacy visual tests are maintained (not disabled) but must reference the
new active Home and current version rather than obsolete exact strings.
"""
from pathlib import Path
import re

pubspec = Path('pubspec.yaml').read_text(encoding='utf-8')
match = re.search(r'^version:\s*0\.21\.(\d+)\+(\d+)\s*$', pubspec, re.M)
if not match or int(match.group(1)) < 47 or int(match.group(2)) < 85:
    raise RuntimeError('Expected fully migrated beta version 0.21.47+85 or newer. Refusing to run obsolete incremental patches.')
if not Path('lib/screens/premium/salus_home_85.dart').is_file():
    raise RuntimeError('Build 85 Home source missing')
if not Path('assets/premium/salus_mountain_85.webp').is_file():
    raise RuntimeError('Build 85 mountain artwork missing')
if not Path('assets/preview84/img/ring_recovery.png').is_file():
    raise RuntimeError('Original ring artwork missing')
if 'SalusHome85()' not in Path('lib/screens/home_shell.dart').read_text(encoding='utf-8'):
    raise RuntimeError('Home is not connected to the approved design')

replacements = {
    'test/build73_renderer_contract_test.dart': [
        ("contains('SalusHome77()')", "contains('SalusHome85()')"),
    ],
    'test/build75_dark_premium_contract_test.dart': [
        ('37|38|39|40|41|42|43|44|45|46', '37|38|39|40|41|42|43|44|45|46|47'),
        ('75|76|77|78|79|80|81|82|83|84', '75|76|77|78|79|80|81|82|83|84|85'),
    ],
}
versions = [
    'build76_light_dark_navigation_contract_test.dart',
    'build77_visual_navigation_contract_test.dart',
    'build78_visual_match_test.dart',
    'build79_energy_contract_test.dart',
    'build80_design_energy_contract_test.dart',
    'build81_rhr_hrv_contract_test.dart',
    'build82_ring_hrv_visibility_test.dart',
    'build83_hrv_sources_test.dart',
]
nav_old = "contains('bottomNavigationBar: _SalusBottomNav(')"
nav_new = "contains('SalusHome85Nav(')"
for filename in versions:
    path = 'test/' + filename
    edits = [('version: 0.21.46+84', 'version: 0.21.47+85')]
    if filename in (
        'build76_light_dark_navigation_contract_test.dart',
        'build77_visual_navigation_contract_test.dart',
        'build78_visual_match_test.dart',
        'build80_design_energy_contract_test.dart',
    ):
        edits.append((nav_old, nav_new))
    if filename == 'build77_visual_navigation_contract_test.dart':
        edits.append(("contains('SalusHome77()')", "contains('SalusHome85()')"))
    replacements[path] = edits

for location, edits in replacements.items():
    path = Path(location)
    content = path.read_text(encoding='utf-8')
    for old, new in edits:
        if old == new:
            continue
        if new in content:
            continue  # Already migrated in a previously validated source commit.
        if content.count(old) != 1:
            raise RuntimeError(f'{location}: expected one exact legacy contract {old!r}, got {content.count(old)}')
        content = content.replace(old, new, 1)
    path.write_text(content, encoding='utf-8')
print(f'Salus Build {match.group(2)}: obsolete patches skipped, active Home/assets validated, historical contracts refreshed')
