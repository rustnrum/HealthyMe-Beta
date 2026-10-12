#!/usr/bin/env python3
"""Build 74: test regression caused by new full-screen MaterialApp builder.

The only common new root compositor in Builds 72-73 absent from Build 70
is a global Stack+Positioned voice launcher. Keep voice accessible using
module-local Scaffold FABs so all important routes and data remain intact.
"""
from pathlib import Path


def exact(text, old, new, path):
    if text.count(old) != 1:
        raise RuntimeError(f'{path}: expected unique anchor {old[:60]!r}, found {text.count(old)}')
    return text.replace(old, new, 1)

version_file = Path('pubspec.yaml')
version = version_file.read_text()
old_version = 'version: 0.21.35+73'
new_version = 'version: 0.21.36+74'
if new_version in version:
    app = Path('lib/app.dart').read_text()
    if 'builder: (context, child) => Stack(fit: StackFit.expand' in app:
        raise RuntimeError('Build 74 already versioned, but global overlay still active')
    for path in ['lib/screens/home_shell.dart','lib/screens/diet/diet_shell.dart',
                 'lib/screens/health/health_shell.dart','lib/screens/workout_screen.dart']:
        if 'SalusVoiceLauncher(' not in Path(path).read_text():
            raise RuntimeError(f'{path}: module voice launcher missing in Build 74')
    print('Build 74 root overlay isolation already applied')
else:
    if version.count(old_version) != 1:
        raise RuntimeError('Unexpected version for Build 74; refusing patch')
    paths = [Path(p) for p in (
        'lib/app.dart','lib/screens/home_shell.dart',
        'lib/screens/diet/diet_shell.dart','lib/screens/health/health_shell.dart',
        'lib/screens/workout_screen.dart')]
    texts = {p:p.read_text() for p in paths}
    ap=paths[0]
    s=texts[ap]
    start='      // One voice assistant covers every Salus route. Do not place separate'
    stop='      debugShowCheckedModeBanner: false,'
    if s.count(start)!=1 or s.count(stop)!=1:
        raise RuntimeError('Global MaterialApp Stack anchor missing')
    a=s.index(start)
    b=s.index(stop,a)
    s=s[:a]+s[b:]
    s=exact(s,"import 'widgets/salus_voice_launcher.dart';\n",'',str(ap))
    s=exact(s,'final ValueNotifier<bool> _salusVoiceOpen = ValueNotifier<bool>(false);\n','',str(ap))
    texts[ap]=s

    # Module-local FABs are small widget layers inside their own Scaffolds.
    # Unlike MaterialApp.builder, they do not cover the full viewport.
    inserts = (
      (paths[1],"import '../widgets/module_menu_button.dart';\n",
        "    return Scaffold(\n      appBar: index == 0"),
      (paths[2],"import '../../widgets/module_menu_button.dart';\n",
        "      child: Scaffold(\n        appBar: _index == 0"),
      (paths[3],"import '../../widgets/module_menu_button.dart';\n",
        "    child: Scaffold(\n      appBar: AppBar("),
      (paths[4],"import '../widgets/module_menu_button.dart';\n",
        "    return Scaffold(\n      backgroundColor: _tab == 'Overview'"),
    )
    for path, marker, anchor in inserts:
        s=texts[path]
        relative='../../widgets/salus_voice_launcher.dart' if '/diet/' in str(path) or '/health/' in str(path) else '../widgets/salus_voice_launcher.dart'
        s=exact(s, marker,marker+f"import '{relative}';\n",str(path))
        new_anchor=anchor.replace('Scaffold(\n',"Scaffold(\n      floatingActionButton: SalusVoiceLauncher(\n        onPressed: () => Navigator.of(context).pushNamed('/voice')),\n",1)
        s=exact(s,anchor,new_anchor,str(path))
        texts[path]=s

    # Validate all modifications in memory before any file is written.
    assert 'Stack(fit: StackFit.expand' not in texts[ap]
    assert 'MaterialApp(' in texts[ap]
    for path in paths[1:]:
        if texts[path].count('SalusVoiceLauncher(') != 1:
            raise RuntimeError(f'{path}: voice launcher was not inserted once')
    for path,s in texts.items():
        path.write_text(s)
    version_file.write_text(version.replace(old_version,new_version,1))
    print('Build 74: removed global full-screen Stack; retained module-local voice and all data')
