import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agencia_flutter/main.dart';
import 'package:agencia_flutter/services/agencia_service.dart';

class MockAgenciaService implements AgenciaService {
  @override
  Future<Map<String, dynamic>> runOneShot(
    String spec,
    String agent,
    String input,
  ) async {
    return {};
  }

  @override
  Stream<dynamic> connectChat(String spec, String agent) {
    return Stream.empty();
  }

  @override
  void sendChatMessage(String message) {}
  @override
  Future<Map<String, dynamic>> getFacts(String chatId) async {
    return {};
  }

  @override
  void closeCurrentChat() {}
  @override
  void dispose() {}
}

void main() {
  testWidgets('ChatPage builds without crashing', (WidgetTester tester) async {
    final service = MockAgenciaService();
    final agentController = TextEditingController(text: 'agent');
    final specController = TextEditingController(text: 'spec');

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          agentController: agentController,
          specController: specController,
          service: service,
        ),
      ),
    );

    expect(find.text('Chat'), findsOneWidget);
    expect(
      find.byType(TextField),
      findsOneWidget,
    ); // TextFormField builds a TextField
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
