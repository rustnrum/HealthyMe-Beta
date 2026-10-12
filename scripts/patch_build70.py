"""Build 70: one global voice entry, recipe bookmarks, expanded discovery.

Do not change saved food log schemas, Garmin, ring, notification, or Recovery
logic. Feature code arrives in the overlay; patch only existing app scaffolding.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    src = p.read_text(encoding='utf-8')
    if new in src:
        return
    n = src.count(old)
    if n != 1:
        raise RuntimeError(f'{path}: expected exactly one anchor, found {n}: {old[:80]}')
    p.write_text(src.replace(old, new, 1), encoding='utf-8')

replace('pubspec.yaml', 'version: 0.21.31+69', 'version: 0.21.32+70')
replace('pubspec.yaml', '  path_provider: ^2.1.6', '''  path_provider: ^2.1.6
  speech_to_text: ^7.5.0
  flutter_tts: ^4.2.5''')
replace('native/android/AndroidManifest.xml',
'''    <uses-permission android:name="android.permission.CAMERA" />''',
'''    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />''')
replace('native/android/AndroidManifest.xml',
'''    <queries>
        <package android:name="com.google.android.apps.healthdata" />''',
'''    <queries>
        <intent><action android:name="android.speech.RecognitionService" /></intent>
        <intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>
        <package android:name="com.google.android.apps.healthdata" />''')
replace('lib/app.dart',
'''import 'screens/ai_coach_screen.dart';''',
'''import 'screens/ai_coach_screen.dart';
import 'screens/salus_voice_screen.dart';
import 'widgets/salus_voice_launcher.dart';''')
replace('lib/app.dart',
'''class HealthyMeApp extends ConsumerWidget {''',
'''final GlobalKey<NavigatorState> _salusVoiceNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<bool> _salusVoiceOpen = ValueNotifier<bool>(false);

class HealthyMeApp extends ConsumerWidget {''')
replace('lib/app.dart',
'''    return MaterialApp(
      debugShowCheckedModeBanner: false,''',
'''    return MaterialApp(
      navigatorKey: _salusVoiceNavigatorKey,
      // One voice assistant covers every Salus route. Do not place separate
      // microphones with independent conversation state in each module.
      builder: (context, child) => Stack(fit: StackFit.expand, children: [
        child ?? const SizedBox.shrink(),
        if (state.profile.completed && MediaQuery.viewInsetsOf(context).bottom == 0)
          Positioned(right: 15, bottom: 92,
            child: ValueListenableBuilder<bool>(
              valueListenable: _salusVoiceOpen,
              builder: (context, open, _) => open
                ? const SizedBox.shrink()
                : SalusVoiceLauncher(onPressed: () {
                    final navigator = _salusVoiceNavigatorKey.currentState;
                    if (navigator == null || _salusVoiceOpen.value) return;
                    _salusVoiceOpen.value = true;
                    navigator.pushNamed('/voice').whenComplete(() {
                      _salusVoiceOpen.value = false;
                    });
                  }),
            )),
      ]),
      debugShowCheckedModeBanner: false,''')
replace('lib/app.dart',
'''        '/coach': (_) => const AiCoachScreen(),''',
'''        '/coach': (_) => const AiCoachScreen(),
        '/voice': (_) => const SalusVoiceScreen(),''')
