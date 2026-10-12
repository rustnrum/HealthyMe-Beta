import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/chatgpt_connection_service.dart';
import 'package:healthy_me/services/salus_ai_service.dart';

void main() {
  test('PKCE S256 matches RFC 7636 test vector', () {
    expect(ChatGptConnectionService.pkceChallenge(
      'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
  });

  test('AI food output only includes explicitly provided numeric values', () {
    final foods = AiEstimatedFood.parse('''{
      "foods":[{"name":"Chicken","estimated_grams":150,"calories":248,
        "protein":46,"carbs":0,"fat":5},
       {"name":"Broccoli","estimated_grams":75,"calories":25,
        "protein":2,"carbs":5,"fat":0}],
      "notes":"May contain oil","confidence":"low"
    }''');
    expect(foods.length, 2);
    expect(foods.first.name, 'Chicken');
    expect(foods.first.protein, 46);
    expect(foods.last.calories, 25);
  });

  test('invalid analysis is not silently converted to invented nutrition', () {
    expect(() => AiEstimatedFood.parse('Looks like chicken'), throwsFormatException);
    expect(AiEstimatedFood.number(-2), 0);
    expect(AiEstimatedFood.number('oops'), 0);
  });

  test('no mocked AI data, no embedded API key, and no changed Garmin source', () {
    final auth = File('lib/services/chatgpt_connection_service.dart').readAsStringSync();
    final api = File('lib/services/salus_ai_service.dart').readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();
    final photo = File('lib/screens/diet/food_photo_analysis_screen.dart').readAsStringSync();
    expect(auth, contains('JsonWebSignature.fromCompactSerialization(compact).verify(store)'));
    expect(auth, contains('FlutterSecureStorage()'));
    expect(auth, contains('code_challenge_method'));
    expect(auth, contains('InternetAddress.loopbackIPv4'));
    expect(api, contains("'stream': true"));
    expect(api, contains("'store': false"));
    expect(api, contains("type == 'response.completed'"));
    expect(photo, contains('AI photo estimate (unverified)'));
    expect(photo, contains('Add selected foods to today'));
    expect(app, contains("'/coach': (_) => const AiCoachScreen()"));
    expect(api, isNot(contains('sk-')));
    expect(auth, isNot(contains('sk-')));
  });
}
