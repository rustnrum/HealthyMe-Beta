#!/usr/bin/env python3
"""Build 81: restore chart painter width and distinguish missing HRV telemetry.
Runs only over successful 0.21.42+80; no source routing, keys, or user storage modified.
"""
from pathlib import Path


def change(filename, old, new):
    p=Path(filename)
    original=p.read_text()
    occurrences=original.count(old)
    if occurrences != 1:
        raise RuntimeError(f'Build81 source anchor mismatch {filename}: {occurrences} copies of {old[:90]!r}')
    p.write_text(original.replace(old,new,1))

v=Path('pubspec.yaml').read_text()
if 'version: 0.21.43+81' in v:
    print('Build 81 already installed, no changes')
    raise SystemExit(0)
if 'version: 0.21.42+80' not in v:
    raise RuntimeError('Build 81 requires successful Build 80 source')

# The resting-HR chart currently has a height but no width. Inside Column with
# loose cross-axis constraints the CustomPaint is laid out at zero width,
# and its painter returns without drawing because width <= 52.
visual='lib/widgets/salus77_design.dart'
change(visual,
    'return SizedBox(height:height,child:CustomPaint(painter:_S77RestingHeartPainter(usable,color,S77.edge,S77.sub)));',
    'return SizedBox(width:double.infinity,height:height,child:CustomPaint(painter:_S77RestingHeartPainter(usable,color,S77.edge,S77.sub)));')

# Distinguish missing verified HRV from the resting-HR drawing regression.
# Tap already routes to /metric-hrv, where provider-separated data can be
# inspected, refreshed, and selected. Never plot synthetic HRV or Garmin's
# unverified short-RR sample.
home='lib/screens/premium/salus_home_77.dart'
change(home,
    "const SizedBox(height:5),unit=='bpm' ? S77RestingHeartChart(values:values,height:108,color:color) : PremiumLineChart(values:values,color:color,height:108,unit:unit),",
    """const SizedBox(height:5),unit=='bpm'
          ? S77RestingHeartChart(values:values,height:108,color:color)
          : values.whereType<double>().where((v)=>v.isFinite).length<2
            ? SizedBox(height:108,child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                mainAxisAlignment:MainAxisAlignment.center,children:[
                  Text('No verified HRV trend yet',style:TextStyle(color:S77.sub,fontSize:12)),
                  const SizedBox(height:7),
                  Text('Tap to check your HRV source and history',
                    style:TextStyle(color:S77.cyan,fontSize:10)),
                ]))
            : PremiumLineChart(values:values,color:color,height:108,unit:unit),""")

change('pubspec.yaml','version: 0.21.42+80','version: 0.21.43+81')
# Contract tests pin the current build by design, update rather than remove.
for f in [
    'build76_light_dark_navigation_contract_test.dart',
    'build77_visual_navigation_contract_test.dart',
    'build78_visual_match_test.dart',
    'build79_energy_contract_test.dart',
    'build80_design_energy_contract_test.dart',
]:
    change('test/'+f,'version: 0.21.42+80','version: 0.21.43+81')
change('test/build75_dark_premium_contract_test.dart',
    "r'^version: 0\\.21\\.(37|38|39|40|41|42)\\+(75|76|77|78|79|80)$'",
    "r'^version: 0\\.21\\.(37|38|39|40|41|42|43)\\+(75|76|77|78|79|80|81)$'")
print('Build 81 HRV/RHR fix applied')
