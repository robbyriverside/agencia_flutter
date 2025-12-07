import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:file_saver/file_saver.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/agencia_service.dart';
import 'services/service_factory.dart';

void main() {
  runApp(AgenciaApp());
}

class AgenciaApp extends StatelessWidget {
  const AgenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agencia {{Ai}}',
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
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AgenciaService _service;

  late TextEditingController specController;
  // final inputController = TextEditingController(text: 'world');
  final agentController = TextEditingController(text: 'greet');
  String outputText = '';
  String errorText = '';
  final FocusNode specFocusNode = FocusNode();
  final ScrollController specScrollController = ScrollController();

  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  // One-Shot/Run UI State
  bool _showOneShotPane = false;
  final TextEditingController _oneShotInputController = TextEditingController();
  final TextEditingController _oneShotOutputController =
      TextEditingController();
  bool _isRunningOneShot = false;
  // Tabs: 0=Output, 1=Facts, 2=Observations
  int _oneShotTabIndex = 0;
  Map<String, dynamic> _oneShotFacts = {};
  Map<String, dynamic> _oneShotObservations = {};

  Future<void> _runOneShot() async {
    setState(() {
      _isRunningOneShot = true;
      _oneShotOutputController.text = "Running...";
    });

    try {
      final result = await _service.runOneShot(
        specController.text,
        agentController.text,
        _oneShotInputController.text,
      );

      setState(() {
        _oneShotOutputController.text = result['output']?.toString() ?? '';
        _oneShotFacts = result['facts'] ?? {};
        _oneShotObservations = result['observations'] ?? {};
      });
    } catch (e) {
      setState(() {
        _oneShotOutputController.text = "Error: $e";
      });
    } finally {
      setState(() {
        _isRunningOneShot = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    specController = TextEditingController(
      text: '''
agents:
  greet:
    template: |
      Hello, {{ INPUT }}!
''',
    );
    _logoController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
    _logoAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
    _service = createAgenciaService();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _service.dispose();
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
              service: _service,
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

    const message =
        'Run mode is no longer available. Please use Chat to talk to your agents.';
    setState(() {
      outputText = message;
      errorText = '';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    var winWidth = MediaQuery.of(context).size.width;
    var isMobile = winWidth < 400;
    var isTablet = winWidth < 1050;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFA5D6A7), // fresh light green
                Color(0xFF2E7D32), // deep green (center)
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
            actions: [
              IconButton(
                icon: Icon(
                  _showOneShotPane
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                tooltip: "One-Shot Run",
                onPressed: () {
                  setState(() {
                    _showOneShotPane = !_showOneShotPane;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_showOneShotPane)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              height: 380, // Fixed height or max height
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _oneShotInputController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: "Input",
                            hintText: "Enter input for the agent",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // ... Button ...
                      ElevatedButton(
                        onPressed: _isRunningOneShot ? null : _runOneShot,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                        child:
                            _isRunningOneShot
                                ? CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                                : Text("Run"),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Tabs for Output | Flags | Observations
                  Row(
                    children: [
                      for (int i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _oneShotTabIndex = i;
                              });
                            },
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  _oneShotTabIndex == i
                                      ? Color(0xFF2E7D32)
                                      : Colors.grey.shade200,
                              foregroundColor:
                                  _oneShotTabIndex == i
                                      ? Colors.white
                                      : Colors.black,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              ["Output", "Facts", "Observations"][i],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child:
                        _oneShotTabIndex == 0
                            ? TextField(
                              controller: _oneShotOutputController,
                              maxLines: null,
                              readOnly: true,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: "Output will appear here...",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(),
                              ),
                              style: TextStyle(fontFamily: 'monospace'),
                            )
                            : Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _oneShotTabIndex == 1
                                      ? (_oneShotFacts.isEmpty
                                          ? "No facts returned."
                                          : JsonEncoder.withIndent(
                                            '  ',
                                          ).convert(_oneShotFacts))
                                      : (_oneShotObservations.isEmpty
                                          ? "No observations returned."
                                          : JsonEncoder.withIndent(
                                            '  ',
                                          ).convert(_oneShotObservations)),
                                  style: TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Starting Agent",
                            style: TextStyle(color: Colors.black),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.35,
                                child: TextSelectionTheme(
                                  data: TextSelectionThemeData(
                                    selectionColor: Colors.lightBlueAccent
                                        .withValues(alpha: 0.5),
                                    cursorColor: Colors.lightBlueAccent,
                                    selectionHandleColor:
                                        Colors.lightBlueAccent,
                                  ),
                                  child: TextField(
                                    controller: agentController,
                                    maxLines: 1,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: chatAgent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(
                                    0xFF2E7D32,
                                  ), // deep green
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
                                    EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 14,
                                    ),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(
                                0xFFF1D8C4,
                              ), // lighter soft complementary background
                              border: Border.all(
                                color: Color(0xFF2E7D32),
                                width: 1.5,
                              ),
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
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "{{Ai}} Agents",
                        style: TextStyle(color: Colors.black),
                      ),
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
                            child: Text(
                              "Save",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => SpecEditorPage(specController),
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
                            child: Text(
                              "Edit",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.grey),
                      ),
                      child: TextSelectionTheme(
                        data: TextSelectionThemeData(
                          selectionColor: Colors.lightBlueAccent.withValues(
                            alpha: 0.5,
                          ),
                          cursorColor: Colors.lightBlueAccent,
                          selectionHandleColor: Colors.lightBlueAccent,
                        ),
                        child: TextField(
                          controller: specController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
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
            ),
          ),
        ],
      ),
    );
  }
}

class SpecEditorPage extends StatelessWidget {
  final TextEditingController specController;

  const SpecEditorPage(this.specController, {super.key});

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
              selectionColor: Colors.lightBlueAccent.withValues(alpha: 0.5),
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
  final AgenciaService service;

  const ChatPage({
    super.key,
    required this.agentController,
    required this.specController,
    required this.service,
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

class ChatMessage {
  final String id;
  final String sender;
  final String context;
  final String message;
  final bool isUser; // true if sent by the user
  ChatMessage({
    required this.id,
    required this.sender,
    required this.context,
    required this.message,
    this.isUser = false,
  });
}

class SenderMeta {
  final String sender;
  final String jobId;
  final String context;
  bool unread;
  String status; // 'priority', 'finished', 'update', etc.
  SenderMeta({
    required this.sender,
    required this.jobId,
    required this.context,
    this.unread = false,
    this.status = '',
  });
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _messages = [];
  String? _chatId;
  bool _closingChat = false;
  final FocusNode _chatFocusNode = FocusNode();
  StreamSubscription? _streamSubscription;
  bool _connectionInProgress = false;

  // Facts and observationsstate
  bool _showFactsPane = false;
  Map<String, dynamic> _facts = {};
  Map<String, dynamic> _observations = {};

  late final TextEditingController agentController;
  late final TextEditingController specController;

  // Sender selection/filter state
  String? _currentSender; // null means group view (all senders)
  String? _currentSenderJobId;
  bool _groupMode = true;
  List<SenderMeta> _senders = [];

  Future<void> _loadFactsAndPrefs() async {
    if (_chatId == null || _chatId!.isEmpty) {
      return;
    }
    try {
      final data = await widget.service.getFacts(_chatId!);
      setState(() {
        _facts = data['facts'] ?? {};
        _observations = data['observations'] ?? {};
      });
    } catch (e) {
      debugPrint("Failed to load facts/observations: $e");
    }
  }

  void _updateSendersFromMessages() {
    // Build/update sender list with unread status and status color
    final Map<String, SenderMeta> meta = {};
    for (final msg in _messages) {
      if (msg.isUser) continue;
      final key = '${msg.sender}:${msg.context}';
      // Try to extract job id from context or message if possible
      String jobId = '';
      if (msg.context.contains('job')) {
        jobId = msg.context;
      } else if (RegExp(r'job[_\-]?\w+').hasMatch(msg.message)) {
        jobId = RegExp(r'job[_\-]?\w+').firstMatch(msg.message)?.group(0) ?? '';
      }
      // Try to extract status from message or context
      String status = '';
      if (msg.context.toLowerCase().contains('priority')) status = 'priority';
      if (msg.context.toLowerCase().contains('finished')) status = 'finished';
      if (msg.context.toLowerCase().contains('update')) status = 'update';
      if (msg.message.toLowerCase().contains('priority')) status = 'priority';
      if (msg.message.toLowerCase().contains('finished')) status = 'finished';
      if (msg.message.toLowerCase().contains('update')) status = 'update';
      if (!meta.containsKey(key)) {
        meta[key] = SenderMeta(
          sender: msg.sender,
          jobId: jobId,
          context: msg.context,
          unread: false,
          status: status,
        );
      }
    }
    // Mark unread for senders with unseen messages
    for (final msg in _messages) {
      if (!msg.isUser) {
        final key = '${msg.sender}:${msg.context}';
        if (_groupMode || _currentSender == null) {
          // In group mode, any agent message is unread if it is the last message
          if (msg == _messages.last) {
            meta[key]?.unread = true;
          }
        } else {
          // In filtered mode, mark unread if last message for that sender/context
          if (msg.sender == _currentSender &&
              (_currentSenderJobId == null ||
                  msg.context == _currentSenderJobId) &&
              msg == _messages.last) {
            meta[key]?.unread = true;
          }
        }
      }
    }
    setState(() {
      _senders = meta.values.toList();
    });
  }

  // Renamed from _connectWebSocket
  void _connectChat() {
    if (_connectionInProgress) {
      return;
    }
    _connectionInProgress = true;

    setState(() {
      _chatId = null;
      _facts = {};
      _observations = {};
    });

    _streamSubscription?.cancel();
    _streamSubscription = null;

    final stream = widget.service.connectChat(
      specController.text,
      agentController.text,
    );

    _streamSubscription = stream.listen(
      (decoded) {
        if (!mounted) return;

        // Reset connecting state on specific events
        if (decoded is Map) {
          if (decoded['type'] == 'connected' || decoded['type'] == 'error') {
            // We don't setState here separately to avoid rebuilding unnecessarily if we do it below
            // But we need to clear the flag.
            _connectionInProgress = false;
          }
        }

        if (decoded is Map) {
          if (decoded['type'] == 'chat_init') {
            final newChatId = decoded['chat_id']?.toString();
            if (newChatId != null && newChatId.isNotEmpty) {
              setState(() {
                _chatId = newChatId;
                _connectionInProgress = false;
              });
              if (_showFactsPane) {
                _loadFactsAndPrefs();
              }
            }
            return;
          }
          if (decoded['type'] == 'connected') {
            setState(() {
              _chatId = "local_session";
              _connectionInProgress = false;
            });
            if (_showFactsPane) {
              _loadFactsAndPrefs();
            }
            return;
          }
        }

        setState(() {
          try {
            // Accept both structured and fallback to string for dev
            if (decoded is Map &&
                decoded.containsKey('sender') &&
                decoded.containsKey('message')) {
              // Extract message string, handling nested JSON object
              final msgField = decoded['message'];
              final msgString =
                  msgField is Map
                      ? msgField['message']?.toString() ?? jsonEncode(msgField)
                      : msgField.toString();

              final id = decoded['id']?.toString() ?? UniqueKey().toString();
              final context = decoded['context']?.toString() ?? "";

              _messages.add(
                ChatMessage(
                  id: id,
                  sender: decoded['sender'].toString(),
                  context: context,
                  message: msgString,
                  isUser: decoded['isUser'] == true,
                ),
              );
            } else {
              // Fallback: treat as string
              _messages.add(
                ChatMessage(
                  id: UniqueKey().toString(),
                  sender: "Agent",
                  context: "",
                  message: decoded.toString(),
                  isUser: false,
                ),
              );
            }
          } catch (e) {
            debugPrint("Error processing chat message: $e");
            // Error handling
          }
          _updateSendersFromMessages();
        });
      },
      onDone: () {
        debugPrint("Chat stream closed");
        if (!mounted) {
          return;
        }
        setState(() {
          _chatId = null;
          _connectionInProgress = false;
        });
      },
      onError: (error) {
        debugPrint("Chat error: $error");
        if (!mounted) {
          return;
        }
        setState(() {
          _chatId = null;
          _connectionInProgress = false;
        });
      },
    );
  }

  Future<void> _handleBackNavigation() async {
    if (_closingChat) return;

    final shouldClose =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text('Close Chat?'),
                content: Text(
                  'Closing the chat will end the current session. Do you want to continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text('Close Chat'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!shouldClose || !mounted) {
      return;
    }

    setState(() {
      _closingChat = true;
    });

    // Close chat via service (which might call API or dispose local session)
    widget.service.closeCurrentChat();

    if (!mounted) {
      return;
    }

    setState(() {
      _closingChat = false;
      _chatId = null;
      _facts = {};
      _observations = {};
    });

    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    agentController = widget.agentController;
    specController = widget.specController;
    _groupMode = true;
    _currentSender = null;
    _currentSenderJobId = null;
  }

  @override
  void dispose() {
    // Service dispose is handled by HomePage, valid here?
    // We should ensure current chat is closed if we pop
    // But _handleBackNavigation does it.
    // If popped by other means (e.g. Android back button logic which calls handleBackNavigation if configured), fine.
    // If purely disposed, we might want to ensure termination?
    // Let's rely on service.closeCurrentChat call logic.
    // Ideally we'd call widget.service.closeCurrentChat() here just in case?
    // It's safe to call multiple times.
    widget.service.closeCurrentChat();

    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  // Debounce tracking
  DateTime? _lastMessageTime;

  void _sendMessage() {
    final now = DateTime.now();
    if (_lastMessageTime != null &&
        now.difference(_lastMessageTime!) < Duration(milliseconds: 500)) {
      return;
    }
    _lastMessageTime = now;

    final raw = _chatController.text;
    final message = raw.trimRight();
    if (message.isEmpty) return;

    if (_chatId == null) {
      // Try to connect
      _connectChat();
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: "",
          sender: "You",
          context: _currentSender ?? agentController.text,
          message: message,
          isUser: true,
        ),
      );
      _chatController.text = '';
      _chatController.selection = TextSelection.collapsed(offset: 0);
      _updateSendersFromMessages();
    });
    _chatFocusNode.requestFocus();

    // Send
    widget.service.sendChatMessage(message);
  }

  List<ChatMessage> get _filteredMessages {
    if (_groupMode || _currentSender == null) {
      return _messages;
    }
    return _messages
        .where(
          (msg) =>
              (!msg.isUser &&
                  msg.sender == _currentSender &&
                  (_currentSenderJobId == null ||
                      msg.context == _currentSenderJobId)) ||
              (msg.isUser),
        )
        .toList();
  }

  void _selectSender(SenderMeta senderMeta) {
    setState(() {
      _currentSender = senderMeta.sender;
      _currentSenderJobId = senderMeta.context;
      _groupMode = false;
      // Mark as read
      for (var s in _senders) {
        if (s.sender == senderMeta.sender && s.context == senderMeta.context) {
          s.unread = false;
        }
      }
    });
  }

  void _returnToGroupView() {
    setState(() {
      _groupMode = true;
      _currentSender = null;
      _currentSenderJobId = null;
      // Mark all as read
      for (var s in _senders) {
        s.unread = false;
      }
    });
  }

  Color? _statusColor(String status, bool unread) {
    if (!unread) return null;
    switch (status) {
      case 'priority':
        return Colors.red;
      case 'finished':
        return Colors.green;
      case 'update':
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF212121),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _closingChat ? null : _handleBackNavigation,
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
                final yamlContent = StringBuffer();
                if (_chatId == null || _chatId!.isEmpty) {
                  yamlContent.writeln("Start a chat session to view facts.");
                } else {
                  final hasData = _facts.isNotEmpty || _observations.isNotEmpty;
                  if (_facts.isNotEmpty) {
                    yamlContent.writeln("Facts:");
                    _facts.forEach((key, value) {
                      yamlContent.writeln("  $key: $value");
                    });
                    yamlContent.writeln();
                  }
                  if (_observations.isNotEmpty) {
                    yamlContent.writeln("Observations:");
                    _observations.forEach((key, value) {
                      yamlContent.writeln("  $key: $value");
                    });
                    yamlContent.writeln();
                  }
                  if (!hasData) {
                    yamlContent.writeln("No facts or observations.");
                  }
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
              itemCount: _filteredMessages.length,
              itemBuilder: (context, index) {
                final msg = _filteredMessages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Align(
                    alignment:
                        msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            msg.isUser ? Color(0xFF388E3C) : Color(0xFF424242),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${msg.sender}${msg.id.isNotEmpty && msg.id != msg.sender ? " [${msg.id}]" : ""}",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          TextSelectionTheme(
                            data: TextSelectionThemeData(
                              selectionColor: Colors.yellowAccent.withValues(
                                alpha: 0.7,
                              ),
                              cursorColor: Colors.lightBlueAccent,
                              selectionHandleColor: Colors.lightBlueAccent,
                            ),
                            child: SelectableText(
                              msg.message,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Sender icon row
          if (_senders.isNotEmpty)
            Container(
              color: Color(0xFF333333),
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                children: [
                  ..._senders.map((sender) {
                    final isSelected =
                        !_groupMode &&
                        _currentSender == sender.sender &&
                        _currentSenderJobId == sender.context;
                    return GestureDetector(
                      onTap: () {
                        _selectSender(sender);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  isSelected
                                      ? Colors.blue
                                      : _statusColor(
                                            sender.status,
                                            sender.unread,
                                          ) ??
                                          Colors.grey[700],
                              radius: 14,
                              child: Text(
                                sender.sender.isNotEmpty
                                    ? sender.sender[0].toUpperCase()
                                    : "?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              sender.sender,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Spacer(),
                  if (!_groupMode)
                    ElevatedButton(
                      onPressed: _returnToGroupView,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text("Return to Group View"),
                    ),
                ],
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
