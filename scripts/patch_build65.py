"""Build 65: real opt-in ChatGPT connection, Salus AI chat and food photos.

No user data, secrets, existing provider routing, or native Garmin implementation
is touched. Idempotent on successful source-commit reruns.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if new in s:
        return
    if s.count(old) != 1:
        raise RuntimeError(f'{path}: expected one anchor; found {s.count(old)}: {old[:100]}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

replace('pubspec.yaml', 'version: 0.21.26+64', 'version: 0.21.27+65')
replace('pubspec.yaml', '  image_picker: ^1.2.3', '''  image_picker: ^1.2.3
  crypto: ^3.0.6
  jose: ^0.3.5+2
  flutter_secure_storage: ^10.2.0
  url_launcher: ^6.3.2''')
replace('lib/app.dart', "import 'screens/activity_screen.dart';", "import 'screens/activity_screen.dart';\nimport 'screens/ai_coach_screen.dart';")

app = Path('lib/app.dart')
s = app.read_text(encoding='utf-8')
start = "        '/coach': (_) => Scaffold("
end = "\n      },\n      home: state.profile.completed"
new = "        '/coach': (_) => const AiCoachScreen(),"
if new not in s:
    if s.count(start) != 1 or s.count(end) != 1:
        raise RuntimeError('app.dart: cannot locate old placeholder route')
    i = s.index(start)
    j = s.index(end, i)
    app.write_text(s[:i] + new + s[j:], encoding='utf-8')

home = 'lib/screens/diet/diet_home_screen.dart'
replace(home,
    "import 'food_entry_dialog.dart';",
    "import 'food_entry_dialog.dart';\nimport 'food_photo_analysis_screen.dart';")
replace(home,
    """        // Camera-first daily action. Typed nutrients remain an optional fallback.
        SalusPaper(glow: true,""",
    """        // Photo recognition is explicit, reviewable and always optional.
        SalusPaper(glow: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const FoodPhotoAnalysisScreen())),
          child: const Row(children: [
            Icon(Icons.camera_alt_rounded, color: AppTheme.mint, size: 37),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Take a food photo', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 20,
                  fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('AI estimate → review → log', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12.5)),
              ])),
            Icon(Icons.chevron_right_rounded, color: AppTheme.mint),
          ])),
        const SizedBox(height: 10),
        // Barcode uses the local camera decoder and Open Food Facts.
        SalusPaper(glow: true,""")

# Remove the historical test that asserts the AI is deliberately unimplemented.
replace('test/build39_routes_and_notifications_test.dart',
    """    expect(app, contains('Salus AI is not available in this beta'));
    expect(app, isNot(contains('const AiCoachScreen()')));""",
    """    expect(app, contains("'/coach': (_) => const AiCoachScreen()"));
    expect(app, isNot(contains('Salus AI is not available in this beta')));""")
print('Build 65: optional ChatGPT authentication, AI chat, camera food analysis.')
