import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'agencia_service.dart';

class AgenciaServiceWeb implements AgenciaService {
  WebSocketChannel? _socket;

  @override
  Future<Map<String, dynamic>> runOneShot(
    String spec,
    String agent,
    String input,
  ) async {
    final uri = Uri.parse('/api/run');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'spec': spec, 'agent': agent, 'input': input}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to run agent: ${response.body}');
    }
  }

  @override
  Stream<dynamic> connectChat(String spec, String agent) {
    if (_socket != null) {
      _socket!.sink.close();
    }

    // Matching original main.dart behavior for dev
    final wsUrl = 'ws://localhost:8080/api/chat';

    _socket = WebSocketChannel.connect(Uri.parse(wsUrl));

    // The chat protocol expects an init message (without type)
    _socket!.sink.add(jsonEncode({'spec': spec, 'agent': agent}));

    return _socket!.stream.map((event) {
      if (event is String) {
        return jsonDecode(event);
      }
      return event;
    });
  }

  @override
  void sendChatMessage(String message) {
    // Matching original main.dart behavior (raw message object)
    _socket?.sink.add(jsonEncode({'message': message}));
  }

  @override
  Future<Map<String, dynamic>> getFacts(String chatId) async {
    final uri = Uri(path: '/api/facts', queryParameters: {'chat_id': chatId});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  @override
  void closeCurrentChat() {
    _socket?.sink.close();
    _socket = null;
  }

  @override
  void dispose() {
    closeCurrentChat();
  }
}
