import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/theme/app_theme.dart';
import '../services/ai_meal_planner_service.dart';
import '../services/chatgpt_connection_service.dart';
import '../services/salus_ai_service.dart';

/// Shared Salus voice and text conversation. Not ChatGPT's native Voice mode.
/// Speech recognition is a device/OS facility and may require internet access.
/// The user controls the mic; no passive/background microphone capture.
/// One in-memory conversation shared across voice entry points and module
/// navigation. No automatic storage of spoken transcripts on disk.
class SalusConversationSession {
  static final List<Map<String, String>> messages = <Map<String, String>>[];
  static String topic = 'Diet';
}

class SalusVoiceScreen extends StatefulWidget {
  const SalusVoiceScreen({super.key});
  @override
  State<SalusVoiceScreen> createState() => _SalusVoiceScreenState();
}

class _SalusVoiceScreenState extends State<SalusVoiceScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _recognizer = stt.SpeechToText();
  final _tts = FlutterTts();
  final _ai = const SalusAiService();
  final _planner = const SalusMealPlannerService();
  final _account = const ChatGptConnectionService();
  final _messages = SalusConversationSession.messages;
  List<SalusMealIdea> _recipes = [];
  String _module = SalusConversationSession.topic;
  String? _error;
  bool _ready = false;
  bool _busy = false;
  bool _micOn = false;
  bool _speaking = false;
  bool _spokenReplies = true;
  bool _autoListen = false;
  bool _voiceTurn = false;
  bool _connected = false;
  int? _awaitingCategoryFor;

  @override
  void initState() {
    super.initState();
    unawaited(_setup());
  }

  Future<void> _setup() async {
    try {
      final account = await _account.account();
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      final last = await _planner.loadLastDiscovery();
      if (mounted) setState(() {
        _connected = account != null;
        _recipes = last;
        _ready = true;
      });
    } catch (error) {
      if (mounted) setState(() { _error = 'Voice setup: $error'; _ready = true; });
    }
  }

  @override
  void dispose() {
    unawaited(_recognizer.cancel());
    unawaited(_tts.stop());
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    if (mounted) setState(() => _error = '$e');
  }

  Future<void> _listen() async {
    if (_micOn || _busy || _speaking || !_ready || !_connected) return;
    try {
      await _tts.stop();
      final available = await _recognizer.initialize(
        onStatus: (status) {
          if (mounted && (status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus)) {
            setState(() => _micOn = false);
          }
        },
        onError: (error) { if (mounted) setState(() {
          _micOn = false; _error = 'Microphone: ${error.errorMsg}';
        }); },
      );
      if (!available) {
        _showError('Android speech recognition is unavailable. You can still type.');
        return;
      }
      _voiceTurn = true;
      setState(() { _micOn = true; _error = null; });
      await _recognizer.listen(
        onResult: (result) {
          if (!mounted) return;
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
          if (result.finalResult) {
            final transcript = result.recognizedWords.trim();
            setState(() => _micOn = false);
            if (transcript.isNotEmpty) unawaited(_send(transcript));
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 3),
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (error) {
      if (mounted) setState(() { _micOn = false; _error = 'Speech recognition: $error'; });
    }
  }

  Future<void> _stopListening() async {
    _autoListen = false;
    await _recognizer.stop();
    if (mounted) setState(() => _micOn = false);
  }

  void _append(String role, String text) {
    if (!mounted) return;
    setState(() => _messages.add({'role': role, 'text': text}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 190), curve: Curves.easeOut);
    });
  }

  Future<void> _answer(String text) async {
    _append('assistant', text);
    if (!_spokenReplies || !_voiceTurn || !mounted) return;
    setState(() => _speaking = true);
    try {
      // Screen readers and recognizers should not hear an unbounded answer.
      final spoken = text.length > 900 ? '${text.substring(0, 900)}. Read the rest on screen.' : text;
      await _tts.speak(spoken);
    } catch (error) { _showError('Spoken reply: $error'); }
    finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  int? _mentionedIndex(String text) {
    final lower = text.toLowerCase();
    final values = <String, int>{'first':0,'1st':0,'one':0,'second':1,'2nd':1,
      'two':1,'third':2,'3rd':2,'three':2,'fourth':3,'4th':3,'fifth':4,'5th':4,
      'sixth':5,'6th':5,'seventh':6,'7th':6,'eighth':7,'8th':7};
    for (final entry in values.entries) {
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lower)) return entry.value;
    }
    return null;
  }

  String? _category(String text) {
    final query = text.toLowerCase();
    for (final slot in SalusMealPlannerService.recipeCategories) {
      if (query.contains(slot.toLowerCase())) return slot;
    }
    return null;
  }

  Future<bool> _trySaveVoiceCommand(String question) async {
    if (_module != 'Diet') return false;
    final lower = question.toLowerCase();
    final save = RegExp(r'\b(save|bookmark|favorite|favourite)\b').hasMatch(lower);
    if (!save && _awaitingCategoryFor == null) return false;
    final index = _awaitingCategoryFor ?? _mentionedIndex(lower);
    if (index == null) {
      await _answer('Tell me which numbered recipe to save, such as save the second recipe to Dinner.');
      return save;
    }
    if (index >= _recipes.length) {
      await _answer('I do not have that numbered recipe available. Search for meals first.');
      return true;
    }
    final category = _category(lower);
    if (category == null) {
      _awaitingCategoryFor = index;
      await _answer('Should I save ${_recipes[index].name} under Breakfast, Lunch, or Dinner?');
      return true;
    }
    _awaitingCategoryFor = null;
    await _confirmFavorite(_recipes[index], category);
    return true;
  }

  Future<void> _confirmFavorite(SalusMealIdea idea, String category) async {
    final approved = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Save to $category?'),
        content: Text('${idea.name} will be saved in My Meals. It will not be logged as eaten or added to the calendar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Save recipe')),
        ],
      ));
    if (approved != true || !mounted) {
      await _answer('Recipe not saved.');
      return;
    }
    final added = await _planner.saveFavorite(idea, category);
    await _answer(added ? 'Saved ${idea.name} to $category in My Meals.'
      : '${idea.name} is already saved under $category.');
  }

  bool _isMealSearch(String query) {
    if (_module != 'Diet') return false;
    final t = query.toLowerCase();
    if (_recipes.isNotEmpty && RegExp(r'\b(more|alternatives|different|another)\b').hasMatch(t)) return true;
    return RegExp(r'\b(find|suggest|show|recommend|ideas|options|make|cook)\b').hasMatch(t) &&
      RegExp(r'\b(food|meal|recipe|dinner|lunch|breakfast|dish|chicken|steak|shrimp|fish|pasta|mexican|mediterranean)\b').hasMatch(t);
  }

  Future<void> _send([String? spoken]) async {
    if (_busy || !_connected) return;
    final question = (spoken ?? _controller.text).trim();
    if (question.isEmpty) return;
    final past = List<Map<String, String>>.from(_messages);
    _controller.clear();
    _append('user', question);
    setState(() { _busy = true; _error = null; });
    try {
      // Direct changes always require an explicit confirmation dialog.
      if (await _trySaveVoiceCommand(question)) return;
      if (_isMealSearch(question)) {
        final pref = await _planner.loadPreferences();
        final previous = _recipes.map((e) => e.name).take(12).join(', ');
        final result = await _planner.discover(
          request: '$question. ${previous.isEmpty ? '' : 'Context: Previously discussed: $previous. Suggest suitable variations only if requested.'}',
          preferences: pref,
        );
        if (mounted) setState(() => _recipes = result.meals);
        await _planner.saveLastDiscovery(result);
        final summary = result.meals.asMap().entries
          .map((e) => '${e.key + 1}: ${e.value.name}')
          .join('. ');
        await _answer('I found ${result.meals.length} recipes. $summary. You can ask me to save a numbered recipe or tap Save on its card.');
      } else {
        final reply = await _ai.ask('Salus conversation topic: $_module. $question', prior: past);
        await _answer(reply);
      }
    } catch (error) { _showError(error); }
    finally {
      if (mounted) setState(() => _busy = false);
      if (mounted && _autoListen && _voiceTurn && !_micOn) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (mounted) unawaited(_listen());
      }
    }
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await _account.connect();
      if (mounted) setState(() => _connected = true);
    } catch (error) { _showError(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Talk to Salus'), actions: [
      IconButton(tooltip: 'Clear voice conversation',
        onPressed: _busy ? null : () => setState(() { _messages.clear(); _recipes.clear(); _awaitingCategoryFor = null; }),
        icon: const Icon(Icons.delete_outline_rounded)),
      IconButton(tooltip: _spokenReplies ? 'Mute spoken responses' : 'Enable spoken responses',
        onPressed: () async {
          if (_spokenReplies) await _tts.stop();
          if (mounted) setState(() { _spokenReplies = !_spokenReplies; _speaking = false; });
        },
        icon: Icon(_spokenReplies ? Icons.volume_up : Icons.volume_off)),
    ]),
    body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(children: [
        Wrap(spacing: 7, runSpacing: 5, children: [
          for (final scope in ['Diet', 'Health', 'Workout', 'General'])
            ChoiceChip(label: Text(scope), selected: _module == scope,
              onSelected: _busy ? null : (_) => setState(() { _module = scope; SalusConversationSession.topic = scope; })),
        ]),
        const SizedBox(height: 8),
        const Text('One Salus assistant across modules. No background listening. '
          'Your health records are not automatically sent to ChatGPT.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        if (_error != null) Padding(padding: const EdgeInsets.all(7),
          child: Text(_error!, style: const TextStyle(color: AppTheme.rose))),
        if (!_connected) ...[
          const Spacer(),
          const Text('Connect ChatGPT to use Salus AI conversation.'),
          const SizedBox(height: 9),
          FilledButton(onPressed: _ready && !_busy ? _connect : null, child: const Text('Connect ChatGPT')),
          const Spacer(),
        ] else ...[
          Expanded(child: ListView(controller: _scroll, children: [
            if (_messages.isEmpty) const Padding(padding: EdgeInsets.all(20),
              child: Text('Ask about dinner ideas, a workout, or a general wellness question. '
                'Tap the microphone to speak or type below.', textAlign: TextAlign.center)),
            for (final m in _messages)
              Align(alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 370),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: m['role'] == 'user' ? AppTheme.surfaceHigh : AppTheme.surface),
                  child: Text(m['text'] ?? ''))),
            if (_module == 'Diet' && _recipes.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 9),
                child: Text('Recipes discussed · Select one to save')),
              for (var i = 0; i < _recipes.length; i++)
                Card(child: ListTile(
                  title: Text('${i + 1}. ${_recipes[i].name}'),
                  subtitle: Text('${_recipes[i].cuisine} · ${_recipes[i].minutes} min'),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Save to My Meals', icon: const Icon(Icons.bookmark_add_outlined),
                    onSelected: (c) => _confirmFavorite(_recipes[i], c),
                    itemBuilder: (_) => [for (final c in SalusMealPlannerService.recipeCategories)
                      PopupMenuItem(value: c, child: Text('Save to $c'))],
                  ),
                )),
            ],
            if (_busy) const Padding(padding: EdgeInsets.all(15),
              child: Center(child: CircularProgressIndicator())),
          ])),
          Row(children: [
            Expanded(child: TextField(controller: _controller,
              maxLines: 2, minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Ask Salus anything…', border: OutlineInputBorder()))),
            IconButton(tooltip: 'Send message', onPressed: _busy ? null : () { _voiceTurn = false; _send(); },
              icon: const Icon(Icons.send, color: AppTheme.mint)),
            IconButton(tooltip: _micOn ? 'Stop listening' : 'Speak to Salus',
              onPressed: _busy || _speaking ? null : _micOn ? _stopListening : _listen,
              icon: Icon(_micOn ? Icons.stop_circle : Icons.mic, color: AppTheme.cyan)),
          ]),
          Row(children: [
            Expanded(child: SwitchListTile.adaptive(
              title: const Text('Listen again after reply', style: TextStyle(fontSize: 12)),
              value: _autoListen,
              onChanged: (v) => setState(() => _autoListen = v),
              contentPadding: EdgeInsets.zero)),
            if (_speaking) const Text('Speaking…', style: TextStyle(fontSize: 12)),
            if (_micOn) const Text('Listening…', style: TextStyle(fontSize: 12)),
          ]),
        ],
        const Text('Voice uses Android recognition and speech playback. '
          'It is not native ChatGPT Realtime Voice. Confirm all changes and verify nutrition estimates.',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
      ]),
    )),
  );
}
