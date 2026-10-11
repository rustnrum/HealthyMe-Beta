"""Build 62: repair legacy test assertions after verified HRV quarantine.

No production code is changed here. Tests for Garmin notifications, Home, and
source routing should not depend on whichever future beta version is published.
This migration is idempotent on CI reruns.
"""
from pathlib import Path
import re

LEGACY_VERSION_TESTS = (
    'test/build54_garmin_protocol_contract_test.dart',
    'test/build52_garmin_attribute_payload_contract_test.dart',
    'test/build57_home_contract_test.dart',
    'test/build55_garmin_realwatch_regressions_test.dart',
    'test/build56_garmin_session_recovery_test.dart',
    'test/build58_recovery_contract_test.dart',
)

# Five unrelated source-contract tests and the Recovery test pinned Build 61.
# A version check belongs to the release workflow, not these behavior tests.
version_assertion = re.compile(
    r"(?m)^[ \t]*expect\(File\('pubspec\.yaml'\)\.readAsStringSync\(\),\s*"
    r"contains\('version: 0\.21\.23\+61'\)\);[ \t]*\n"
)
for path in LEGACY_VERSION_TESTS:
    file = Path(path)
    content = file.read_text(encoding='utf-8')
    content, removed = version_assertion.subn('', content)
    # A second workflow run after source commit should simply do nothing.
    if removed > 1:
        raise RuntimeError(f'{path}: found {removed} duplicated legacy version assertions')
    if "contains('version: 0.21.23+61')" in content:
        raise RuntimeError(f'{path}: unexpected legacy version assertion syntax')
    if removed:
        file.write_text(content, encoding='utf-8')

# Build 58 expected Garmin BLE HRV to contribute to Recovery; Build 62 now
# explicitly excludes that experimental source from the baseline.
path = Path('test/build58_recovery_contract_test.dart')
content = path.read_text(encoding='utf-8')
old = '''    expect(direct, contains("hrv30: directDailySeries('HRV', base.hrv30)"));'''
new = '''    expect(direct, contains("hrv30: excludeGarminHrv ? const [] : directDailySeries('HRV', base.hrv30)"));'''
if new not in content:
    if content.count(old) != 1:
        raise RuntimeError('Recovery contract: missing exactly one legacy HRV assertion')
    path.write_text(content.replace(old, new, 1), encoding='utf-8')

print('Build 62: legacy behavior tests updated without changing production HRV safety.')
