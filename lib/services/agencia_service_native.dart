import 'dart:async';
import 'package:agencia_dart/agencia_dart.dart';
import 'agencia_service.dart';

class AgenciaServiceNative implements AgenciaService {
  SpecSession? _session;
  final StreamController<dynamic> _chatStreamController =
      StreamController<dynamic>.broadcast();

  // Keep track of current agent for chat
  String? _currentAgent;

  @override
  Future<Map<String, dynamic>> runOneShot(
    String spec,
    String agent,
    String input,
  ) async {
    final resolver = MemoryResolver();

    // Create session (it parses the spec)
    // Note: SpecSession.fromYaml throws if spec is invalid
    try {
      final session = SpecSession.fromYaml(
        spec: spec,
        resolver: resolver,
        startAgent: agent,
      );

      // Set default input for {{ INPUT }} directive
      resolver.setInput('', input);

      // Run the agent
      final result = await session.run(input, agent: agent);

      // Convert observations to the expected Map<String, dynamic> format
      // Session observations: Map<String, Map<String, List<String>>>
      // OneShot UI seems to expect simple structure or just displays JSON.
      // We'll pass it as is, or closest equivalent.

      return {
        'output': result.text,
        'facts': session.facts,
        'observations': session.observations,
      };
    } catch (e) {
      // Return minimal error structure to avoid crash
      return {
        'output': 'Error running local agent: $e',
        'facts': {},
        'observations': {},
        'error': e.toString(),
      };
    }
  }

  // Track subscription to cancel it explicitly
  StreamSubscription? _sessionSubscription;

  @override
  Stream<dynamic> connectChat(String spec, String agent) {
    // Dispose previous session and subscription
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    if (_session != null) {
      _session!.dispose();
      _session = null;
    }

    _currentAgent = agent;
    final resolver = MemoryResolver();

    try {
      _session = SpecSession.fromYaml(
        spec: spec,
        resolver: resolver,
        startAgent: agent,
      );

      // Listen to internal events and map to UI events
      _sessionSubscription = _session!.events.listen(
        (event) {
          _mapAndEmitEvent(event);
        },
        onError: (e, s) {
          _chatStreamController.add({'type': 'error', 'message': e.toString()});
        },
      );

      // Emit connected message
      _chatStreamController.add({
        'type': 'connected',
        'message': 'Local Agent Ready',
      });
    } catch (e, s) {
      Future.microtask(() => _chatStreamController.addError(e));
    }

    return _chatStreamController.stream;
  }

  void _mapAndEmitEvent(ChatEvent event) {
    if (event is ChatRunCompleted) {
      if (!event.card.hidden) {
        final text = event.result.asString();

        _chatStreamController.add({
          'sender': event.card.agentName,
          'message': text,
          'isUser': false,
          'id': event.card.agentName,
          'context': '',
        });
      }
    } else if (event is ChatRunFailed) {
      _chatStreamController.add({
        'sender': 'System',
        'message': 'Error: ${event.error}',
        'isUser': false,
        'error': true,
      });
    }
  }

  // Execution lock to serialize session runs
  Future<void> _executionLock = Future.value();

  @override
  void sendChatMessage(String message) {
    if (_session != null && _currentAgent != null) {
      _executionLock = _executionLock.whenComplete(() async {
        if (_session == null) return;

        try {
          // KEY FIX: Set the input on the resolver before running!
          // This ensures {{ INPUT }} directives resolve correctly.
          if (_session!.resolver is MemoryResolver) {
            (_session!.resolver as MemoryResolver).setInput('', message);
          }

          await _session!.run(message, agent: _currentAgent!);
        } catch (e, s) {
          // ignore error
        }
      });
    }
  }

  @override
  Future<Map<String, dynamic>> getFacts(String chatId) async {
    if (_session != null) {
      return {'facts': _session!.facts, 'observations': _session!.observations};
    }
    return {};
  }

  @override
  void closeCurrentChat() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _session?.dispose();
    _session = null;
  }

  @override
  void dispose() {
    closeCurrentChat();
    _chatStreamController.close();
  }
}
