import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:file_saver/file_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/html.dart' as html_ws;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(AgenciaApp());
}

class AgenciaApp extends StatelessWidget {
  const AgenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '{{Ai}}',
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFFAFAFA), // soft white/grey
        brightness: Brightness.light,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2E7D32), // deep green
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF2E7D32), // deep green
          elevation: 1,
          shadowColor: Colors.grey,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFA5D6A7), // fresh light green
                  Color(0xFF2E7D32), // deep green (center)
                  // Color(0xFFA5D6A7), // fresh light green
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.5],
              ),
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text('Agencia {{Ai}}'),
            ),
          ),
        ),
        body: AgenciaForm(),
      ),
    );
  }
}

class AgenciaForm extends StatefulWidget {
  @override
  _AgenciaFormState createState() => _AgenciaFormState();
}

class _AgenciaFormState extends State<AgenciaForm>
    with SingleTickerProviderStateMixin {
  late TextEditingController specController;
  final inputController = TextEditingController(text: 'world');
  final agentController = TextEditingController(text: 'greet');
  String outputText = '';
  String errorText = '';
  final FocusNode specFocusNode = FocusNode();
  final ScrollController specScrollController = ScrollController();

  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    specController = TextEditingController(
      text: '''
agents:
  greet:
    template: |
      Hello, {{ .Input }}!
''',
    );
    _logoController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
    _logoAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  void showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _logoAnimation,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFF1D8C4),
                      border: Border.all(color: Color(0xFF2E7D32), width: 1.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      "{{Ai}}",
                      style: GoogleFonts.audiowide(
                        textStyle: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text("Running agent...", style: TextStyle(color: Colors.black)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> chatAgent() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChatPage(
              agentController: agentController,
              specController: specController,
            ),
      ),
    );
  }

  Future<void> runAgent() async {
    try {
      loadYaml(specController.text);
    } catch (e) {
      setState(() {
        outputText = 'YAML error: $e';
        errorText = 'YAML error: $e';
      });
      return;
    }

    showProgressDialog();

    final requestBody = {
      'spec': specController.text,
      'input': inputController.text,
      'agent': agentController.text,
    };
    // print("Sending: ${jsonEncode(requestBody)}");

    final response = await http.post(
      Uri.parse('/api/run'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    Navigator.of(context, rootNavigator: true).pop(); // close dialog

    if (response.statusCode == 200) {
      final Map<String, dynamic> result = jsonDecode(response.body);
      setState(() {
        outputText = result['output'] ?? '';
        errorText = result['error'] ?? '';
      });
    } else {
      print(
        'HTTP ${response.statusCode} ${response.reasonPhrase}\n${response.body}',
      );
      setState(() {
        outputText = response.body;
        errorText = response.body;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var winWidth = MediaQuery.of(context).size.width;
    var isMobile = winWidth < 400;
    var isTablet = winWidth < 1050;
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Input", style: TextStyle(color: Colors.black)),
          SizedBox(height: 4),
          TextField(
            controller: inputController,
            maxLines: 2,
            decoration: InputDecoration(border: OutlineInputBorder()),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Starting Agent", style: TextStyle(color: Colors.black)),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.35,
                        child: TextField(
                          controller: agentController,
                          maxLines: 1,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: runAgent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32), // deep green
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          shadowColor: Colors.black54,
                        ).copyWith(
                          padding: WidgetStateProperty.all(
                            EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          ),
                          alignment: Alignment.center,
                        ),
                        child: Text(
                          "Run",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: chatAgent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32), // deep green
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          shadowColor: Colors.black54,
                        ).copyWith(
                          padding: WidgetStateProperty.all(
                            EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          ),
                          alignment: Alignment.center,
                        ),
                        child: Text(
                          "Chat",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                  ),
                ],
              ),
              // Agencia symbol to the right of Run button
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(
                        0xFFF1D8C4,
                      ), // lighter soft complementary background
                      border: Border.all(color: Color(0xFF2E7D32), width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (isTablet)
                          ? ((isMobile)
                              ? "{{Ai}}"
                              : " Agentic\n   {{Ai}} \nDesigner")
                          : " Agentic {{Ai}} Designer ",
                      style: GoogleFonts.audiowide(
                        textStyle: TextStyle(
                          fontSize: (isTablet) ? 16 : 28,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(width: 4),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Output", style: TextStyle(color: Colors.black)),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: outputText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Output copied to clipboard")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32), // deep green
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size(0, 0),
                ),
                child: Text(
                  "Copy Output",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Color(
                      0xFFE8F5E9,
                    ), // lighter fresh green for Output box
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: TextSelectionTheme(
                        data: TextSelectionThemeData(
                          selectionColor: Colors.lightBlueAccent.withOpacity(
                            0.5,
                          ),
                          cursorColor: Colors.lightBlueAccent,
                          selectionHandleColor: Colors.lightBlueAccent,
                        ),
                        child: TextField(
                          controller: TextEditingController(text: outputText),
                          style: TextStyle(color: Colors.black),
                          maxLines: null,
                          readOnly: true,
                          decoration: InputDecoration.collapsed(hintText: null),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("{{Ai}} Agents", style: TextStyle(color: Colors.black)),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final bytes = Uint8List.fromList(
                        utf8.encode(specController.text),
                      );
                      await FileSaver.instance.saveFile(
                        name: "agencia",
                        bytes: bytes,
                        ext: "yaml",
                        mimeType: MimeType.text,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32), // deep green
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(0, 0),
                    ),
                    child: Text("Save", style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SpecEditorPage(specController),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32), // deep green
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(0, 0),
                    ),
                    child: Text("Edit", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 4),
          Expanded(
            child: Container(
              height: 400,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.grey),
              ),
              child: TextSelectionTheme(
                data: TextSelectionThemeData(
                  selectionColor: Colors.lightBlueAccent.withValues(alpha: 0.5),
                  cursorColor: Colors.lightBlueAccent,
                  selectionHandleColor: Colors.lightBlueAccent,
                ),
                child: TextField(
                  controller: specController,
                  maxLines: null,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Roboto',
                    color: Colors.white,
                  ),
                  decoration: InputDecoration.collapsed(hintText: null),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpecEditorPage extends StatelessWidget {
  final TextEditingController specController;

  SpecEditorPage(this.specController, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Edit {{Ai}} Agents"),
      ),
      body: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.grey),
        ),
        child: SizedBox.expand(
          child: TextSelectionTheme(
            data: TextSelectionThemeData(
              selectionColor: Colors.lightBlueAccent.withOpacity(0.5),
              cursorColor: Colors.lightBlueAccent,
              selectionHandleColor: Colors.lightBlueAccent,
            ),
            child: TextField(
              controller: specController,
              maxLines: null,
              expands: true,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Roboto',
                color: Colors.white,
              ),
              decoration: InputDecoration.collapsed(hintText: null),
            ),
          ),
        ),
      ),
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
    );
  }
}

class ChatPage extends StatefulWidget {
  final TextEditingController agentController;
  final TextEditingController specController;

  const ChatPage({
    super.key,
    required this.agentController,
    required this.specController,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

// Custom formatter to allow newline only with Shift+Enter
// and suppress newline if Enter is pressed without Shift.
// This works for desktop/web where hardware keyboard events are available.
class EnterKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow newline only if shift key is pressed
    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    final shiftPressed =
        pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.shiftRight);

    // If Enter without Shift, block newline insertion
    if (!shiftPressed &&
        newValue.text.length > oldValue.text.length &&
        newValue.text.endsWith('\n')) {
      return oldValue;
    }

    return newValue;
  }
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _chatController = TextEditingController();
  final List<String> _messages = [];
  WebSocketChannel? _socket;
  final FocusNode _chatFocusNode = FocusNode();
  // For temporary editing, not strictly needed but included per instruction
  TextEditingController _tempController = TextEditingController();

  // Facts and preferences state
  bool _showFactsPane = false;
  Map<String, dynamic> _facts = {};
  Map<String, dynamic> _preferences = {};

  late final TextEditingController agentController;
  late final TextEditingController specController;

  Future<void> _loadFactsAndPrefs() async {
    try {
      final response = await http.get(Uri.parse('/api/facts'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _facts = data['facts'] ?? {};
          _preferences = data['preferences'] ?? {};
        });
      }
    } catch (e) {
      print("Failed to load facts/preferences: $e");
    }
  }

  void _connectWebSocket() {
    try {
      _socket = html_ws.HtmlWebSocketChannel.connect(
        'ws://localhost:8080/api/chat',
      );
      // Send the initial handshake payload with agent and spec
      _socket!.sink.add(
        jsonEncode({
          "agent": agentController.text,
          "spec": specController.text,
        }),
      );
    } catch (e) {
      print("WebSocket creation error: $e");
      return;
    }

    _socket!.stream.listen(
      (event) {
        setState(() {
          _messages.add(event.toString());
        });
      },
      onDone: () {
        print("WebSocket closed.");
        _socket = null;
      },
      onError: (error) {
        print("WebSocket error: $error");
        _socket = null;
      },
    );
  }

  @override
  void initState() {
    super.initState();
    agentController = widget.agentController;
    specController = widget.specController;
    // Do not connect on init; only connect when sending a message if needed.
  }

  @override
  void dispose() {
    _socket?.sink.close();
    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final raw = _chatController.text;
    final message =
        raw.trimRight(); // preserve internal newlines, trim only trailing
    if (message.isEmpty) return;

    // Only (re)connect if socket is null (closed/disconnected)
    if (_socket == null) {
      try {
        _connectWebSocket();
        // Wait briefly for connection to establish, then send, or give up if still null.
        Future.delayed(Duration(milliseconds: 500), () {
          if (_socket == null) {
            setState(() {
              _messages.add(
                "🤖 Sorry, I'm currently disconnected and couldn't send your message. Please try again later.",
              );
            });
          } else {
            setState(() {
              _messages.add("You: $message");
              _chatController.text = '';
              _chatController.selection = TextSelection.collapsed(offset: 0);
            });
            _chatFocusNode.requestFocus();
            _socket?.sink.add(message);
          }
        });
      } catch (e) {
        setState(() {
          _messages.add(
            "🤖 Apologies, we're unable to reconnect at the moment. Please try again shortly.",
          );
        });
      }
      return;
    }

    setState(() {
      _messages.add("You: $message");
      _chatController.text = '';
      _chatController.selection = TextSelection.collapsed(offset: 0);
    });
    _chatFocusNode.requestFocus();
    _socket?.sink.add(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF212121), // dark gray
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Chat", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF2E7D32),
        actions: [
          IconButton(
            icon: Icon(
              _showFactsPane
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showFactsPane = !_showFactsPane;
                if (_showFactsPane) {
                  _loadFactsAndPrefs();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFactsPane)
            LayoutBuilder(
              builder: (context, constraints) {
                final double maxHeight = constraints.maxHeight * 0.5;
                final hasData = _facts.isNotEmpty || _preferences.isNotEmpty;
                final yamlContent = StringBuffer();
                if (_facts.isNotEmpty) {
                  yamlContent.writeln("Facts:");
                  _facts.forEach((key, value) {
                    yamlContent.writeln("  $key: $value");
                  });
                  yamlContent.writeln();
                }
                if (_preferences.isNotEmpty) {
                  yamlContent.writeln("Preferences:");
                  _preferences.forEach((key, value) {
                    yamlContent.writeln("  $key: $value");
                  });
                }
                if (!hasData) {
                  yamlContent.writeln("No facts or preferences.");
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        yamlContent.toString(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFF424242),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _messages[index],
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (KeyEvent event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !(HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.shiftLeft) ||
                              HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.shiftRight))) {
                        _sendMessage();
                      }
                    },
                    child: TextFormField(
                      controller: _chatController,
                      focusNode: _chatFocusNode,
                      keyboardType: TextInputType.multiline,
                      inputFormatters: [EnterKeyFormatter()],
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: null,
                      onChanged: (text) => setState(() {}),
                      // onFieldSubmitted: (_) => _sendMessage(),
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        hintText: "Type your message...",
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Color(0xFF616161),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text("Send"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
