#!/usr/bin/env python3
"""Apply Salus Build 84 graphic mockup preview to the EXISTING beta app.
No package IDs, signing material, health/diet/workout state, or device drivers are changed.
"""
from pathlib import Path
import re

app=Path('lib/app.dart')
s=app.read_text()
imp="import 'screens/preview84/screens/shell.dart';\n"
anchor="import 'screens/trends_screen.dart';\n"
if imp not in s:
    assert s.count(anchor)==1,'Cannot find App import insertion point'
    s=s.replace(anchor,anchor+imp)
route="        '/preview84': (_) => const PreviewShell(),\n"
anchor="        '/trends': (_) => const TrendsScreen(),\n"
if route not in s:
    assert s.count(anchor)==1,'Cannot find App routes insertion point'
    s=s.replace(anchor,anchor+route)
app.write_text(s)

home=Path('lib/screens/premium/salus_home_77.dart')
s=home.read_text()
button="""const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/preview84'),
            icon: const Icon(Icons.auto_awesome_rounded, size: 15),
            label: const Text('Preview new Home'),
          ),
        ),
        """
anchor='const SizedBox(height:12),SizedBox(height:210,child:Padding('
if "pushNamed('/preview84')" not in s:
    assert s.count(anchor)==1,'Cannot find original Salus Home insertion point'
    s=s.replace(anchor,button+anchor)
home.write_text(s)

pub=Path('pubspec.yaml')
s=pub.read_text()
if 'version: 0.21.45+83' in s:
    s=s.replace('version: 0.21.45+83','version: 0.21.46+84',1)
else:
    assert 'version: 0.21.46+84' in s, 'Expected Build 83 verified base; refusing version mismatch'
asset='    - assets/preview84/img/\n'
if asset not in s:
    needle='    - assets/premium/\n'
    assert s.count(needle)==1,'Cannot find Flutter asset registry'
    s=s.replace(needle,needle+asset)
pub.write_text(s)

# Validate original mockup assets are present in the unpacked overlay.
for name in ('hero_mountain','ring_recovery','ring_steps','ring_calories','spark_rhr',
             'spark_hrv','sleep_bar','body_battery','trend_recovery','trend_skin','avatar'):
    assert Path('assets/preview84/img',name+'.png').is_file(),f'Missing user asset: {name}'

# Only adjust version assertions, without disabling any regression tests.
for test in Path('test').glob('*.dart'):
    original = test.read_text()
    revised = original.replace('version: 0.21.45+83', 'version: 0.21.46+84')
    revised = revised.replace(
        r'(37|38|39|40|41|42|43|44|45)\+(75|76|77|78|79|80|81|82|83)',
        r'(37|38|39|40|41|42|43|44|45|46)\+(75|76|77|78|79|80|81|82|83|84)',
    )
    if revised != original:
        test.write_text(revised)

print('Build 84: 3 original preview screens, 11 original PNG assets, old-app return, package preserved.')
