import 'dart:async';

abstract class AgenciaService {
  Future<Map<String, dynamic>> runOneShot(
    String spec,
    String agent,
    String input,
  );

  Stream<dynamic> connectChat(String spec, String agent);

  void sendChatMessage(String message);

  Future<Map<String, dynamic>> getFacts(String chatId);

  void closeCurrentChat();

  void dispose();
}
