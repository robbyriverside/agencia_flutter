import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:file_saver/file_saver.dart';

// Custom SyntaxHighlightController for live syntax highlighting
class SyntaxHighlightController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final lines = text.split('\n');
    List<TextSpan> spans = [];

    final agentStyle = TextStyle(
      color: Colors.lightBlue,
      fontWeight: FontWeight.bold,
    );
    final agentsStyle = TextStyle(
      color: Colors.orangeAccent,
      fontWeight: FontWeight.bold,
    );
    final keyStyle = TextStyle(
      color: Colors.yellowAccent,
      fontWeight: FontWeight.bold,
    );
    final exprStyle = TextStyle(color: Colors.greenAccent);
    final tmplStyle = TextStyle(color: Colors.white);
    final defaultStyle =
        style ??
        TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Courier New');

    bool insideBlock = false;

    for (var line in lines) {
      if (line.trim().isEmpty) {
        spans.add(TextSpan(text: '\n', style: defaultStyle));
        continue;
      }

      if (line.startsWith('agents:')) {
        spans.add(TextSpan(text: line + '\n', style: agentsStyle));
      } else if (RegExp(r'^\s{2}[\w\-]+:$').hasMatch(line)) {
        spans.add(TextSpan(text: line + '\n', style: agentStyle));
      } else if (line.contains('template:') || line.contains('prompt:')) {
        spans.add(TextSpan(text: line + '\n', style: keyStyle));
        insideBlock = true;
      } else if (insideBlock && RegExp(r'^\s+').hasMatch(line)) {
        final matches = RegExp(r'(\{\{.*?\}\})').allMatches(line);
        int last = 0;
        for (final match in matches) {
          if (match.start > last) {
            spans.add(
              TextSpan(
                text: line.substring(last, match.start),
                style: tmplStyle,
              ),
            );
          }
          spans.add(TextSpan(text: match.group(0), style: exprStyle));
          last = match.end;
        }
        if (last < line.length) {
          spans.add(TextSpan(text: line.substring(last), style: tmplStyle));
        }
        spans.add(TextSpan(text: '\n'));
      } else {
        spans.add(TextSpan(text: line + '\n', style: defaultStyle));
        insideBlock = false;
      }
    }

    return TextSpan(style: defaultStyle, children: spans);
  }
}

void main() {
  runApp(AgenciaApp());
}

class AgenciaApp extends StatelessWidget {
  const AgenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '{{A}}',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.blue[900],
        brightness: Brightness.light,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlueAccent,
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[900],
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
        appBar: AppBar(title: Text('Agencia {{A}}')),
        body: AgenciaForm(),
      ),
    );
  }
}

class AgenciaForm extends StatefulWidget {
  @override
  _AgenciaFormState createState() => _AgenciaFormState();
}

class _AgenciaFormState extends State<AgenciaForm> {
  final specController =
      SyntaxHighlightController()
        ..text = '''
agents:
  greet:
    template: |
      Hello, {{ .Input }}!
''';
  final inputController = TextEditingController(text: 'world');
  final agentController = TextEditingController(text: 'greet');
  String outputText = '';
  String errorText = '';
  final FocusNode specFocusNode = FocusNode();

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text("Running agent...", style: TextStyle(color: Colors.black)),
              ],
            ),
          ),
        );
      },
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
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Input", style: TextStyle(color: Colors.white)),
          TextField(
            controller: inputController,
            maxLines: 2,
            decoration: InputDecoration(border: OutlineInputBorder()),
          ),
          SizedBox(height: 12),
          Text("Starting Agent", style: TextStyle(color: Colors.white)),
          Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.45,
                child: TextField(
                  controller: agentController,
                  maxLines: 1,
                  decoration: InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              SizedBox(width: 6),
              ElevatedButton(
                onPressed: runAgent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Output", style: TextStyle(color: Colors.white)),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: outputText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Output copied to clipboard")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size(0, 0),
                ),
                child: Text("Copy Output"),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Colors.white,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        outputText,
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Agencia {{A}}", style: TextStyle(color: Colors.white)),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(0, 0),
                    ),
                    child: Text("Save"),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SpecEditorPage(specController.text),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(0, 0),
                    ),
                    child: Text("Edit"),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.grey),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: TextSelectionThemeData(
                    selectionColor: Colors.lightBlueAccent.withValues(
                      alpha: 0.5,
                    ),
                    cursorColor: Colors.white,
                    selectionHandleColor: Colors.lightBlueAccent,
                  ),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: TextField(
                      controller: specController,
                      focusNode: specFocusNode,
                      maxLines: null,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Courier New',
                        color: Colors.white,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration.collapsed(hintText: null),
                      scrollPadding: EdgeInsets.all(20),
                      enableInteractiveSelection: true,
                      selectionControls: materialTextSelectionControls,
                    ),
                  ),
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
  final String spec;

  SpecEditorPage(this.spec, {super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SyntaxHighlightController()..text = spec;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Edit {{A}}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: TextField(
              controller: controller,
              maxLines: null,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Courier New',
                color: Colors.white,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration.collapsed(hintText: null),
              scrollPadding: EdgeInsets.all(20),
              enableInteractiveSelection: true,
              selectionControls: materialTextSelectionControls,
            ),
          ),
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
