import 'dart:io';

import 'package:fllama/fllama_universal.dart';
import 'package:fllama/misc/openai.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tsid_dart/tsid_dart.dart';

import '../services/hugging_face_service.dart';

class ChatMessage {
  int id;
  String text;
  Role role;

  ChatMessage({required this.id, required this.text, required this.role});
}

class ChatScreen extends StatefulWidget {
  final String data;

  const ChatScreen({
    super.key,
    required this.data,
  });

  @override
  State<StatefulWidget> createState() {
    return _ChatScreenState();
  }
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isDownloading = false;
  bool _isModelExist = false;
  double _progress = 0;
  String _status = '';
  int? _runningRequestId;
  bool _isInfer = false;
  List<ChatMessage> _messages = [];

  final _modelName = 'qwen2.5-3b-instruct-q5_k_m.gguf';
  final _downloader = HuggingFaceDownloader(
      modelUrl:
          'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q5_k_m.gguf?download=true',
      fileName: 'qwen2.5-3b-instruct-q5_k_m.gguf');

  String? _modelPath;
  final TextEditingController _questionTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkModelExistence();
    _messages = [];
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    super.dispose();
  }

  Future<Directory> get _tempModelDir async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${directory.path}/models_tmp');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<Directory> get _finalModelDir async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${directory.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<void> _checkModelExistence() async {
    final modelDir = await _finalModelDir;
    final file = File(path.join(modelDir.path, _modelName));

    setState(() {
      _isModelExist = file.existsSync();
      _modelPath = file.path;
      if (_isModelExist) {
        _status = 'Downloaded';
      }
    });
  }

  List<Message> convertFromChat(List<ChatMessage> messages) {
    return messages
        .map((message) => Message(message.role, message.text.trim()))
        .toList();
  }

  Future<void> _runChatInference() async {
    try {
      setState(() {
        _isInfer = true;
        _messages.add(ChatMessage(
            id: Tsid.getTsid().toLong(),
            text: _questionTextController.text.trim(),
            role: Role.user));
      });
      final request = OpenAiRequest(
        maxTokens: 1024,
        messages: [
          Message(Role.system,
              """You are MDO assistant, trained by BSSD. Your goal is to help answer user question precisely and concisely from voice analysis data. Do not try to makeup the answer if you are do not know, answer in Vietnamese and markdown format, auto correct grammar.
              """),
          Message(Role.user,
              "Chỉ trả lời câu hỏi của tôi với kết quả phân tích giọng nói sau đây\n ${widget.data}"),
          Message(Role.assistant,
              "Tất nhiên rồi, tôi sẽ chỉ trả lời câu hỏi của bạn với kết quả phân tích bạn cung cấp và chỉ trả về định dạng markdown"),
          ...convertFromChat(_messages)
        ],
        numGpuLayers: 99,
        modelPath: _modelPath!,
        topP: 1.0,
        contextSize: 32000,
        temperature: 0.7,
      );
      final response = ChatMessage(
          id: Tsid.getTsid().toLong(), text: "...", role: Role.assistant);
      _messages.add(response);
      int requestId = await fllamaChat(request, (res, done) {
        setState(() {
          response.text = res.trim();
          if (done) {
            _runningRequestId = null;
          }
        });
      });

      setState(() {
        _runningRequestId = requestId;
      });
      _questionTextController.clear();
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        _isInfer = false;
      });
    }
  }

  Future<void> _moveFile(File source, String targetPath) async {
    try {
      await source.rename(targetPath);
    } catch (e) {
      try {
        await source.copy(targetPath);
        await source.delete();
      } catch (e) {
        throw Exception('Failed to move file: $e');
      }
    }
  }

  Future<void> _cleanupTempDir() async {
    try {
      final tempDir = await _tempModelDir;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error cleaning up temp directory: $e');
    }
  }

  Future<void> _startDownload(
      {bool force = false, required BuildContext context}) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _status = 'Starting download...';
    });

    try {
      await _cleanupTempDir();

      await _downloader.downloadModel(
        onProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _status =
                  'Downloaded: ${(received / 1024 / 1024).toStringAsFixed(2)}MB '
                  'of ${(total / 1024 / 1024).toStringAsFixed(2)}MB '
                  '(${(_progress * 100).toStringAsFixed(1)}%)';
            });
          }
        },
        onComplete: (filePath) async {
          setState(() {
            _status = 'Moving file to final location...';
          });

          try {
            final tempDir = await _tempModelDir;
            final finalDir = await _finalModelDir;
            final tempFile = File(path.join(tempDir.path, _modelName));
            final finalPath = path.join(finalDir.path, _modelName);

            if (await tempFile.exists()) {
              await _moveFile(tempFile, finalPath);
              print("Reset chatUI");
              if (mounted) {
                setState(() {
                  print("Reset state to show chat UI");
                  _isModelExist = true;
                  _isDownloading = false;
                  _modelPath = finalPath;
                });
              }
            } else {
              throw Exception('Downloaded file not found in temp directory');
            }
          } catch (e) {
            setState(() {
              _status = 'Error moving file: $e';
              _isDownloading = false;
            });
          } finally {
            await _cleanupTempDir();
          }
        },
        onError: (error) {
          setState(() {
            _status = 'Error: $error';
            _isDownloading = false;
          });
          _cleanupTempDir();
        },
      );
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isDownloading = false;
      });
      _cleanupTempDir();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.blue,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'redownload') {
                await _startDownload(force: true, context: context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'redownload',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Redownload Model'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isModelExist && !_isDownloading)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () async {
                      await _startDownload(context: context);
                      _checkModelExistence();
                    },
                    style: ElevatedButton.styleFrom(
                        textStyle: TextStyle(fontWeight: FontWeight.w900)),
                    child: Text('Download Model'),
                  ),
                )
              ]),
            if (_isDownloading)
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 4,
                      child: LinearProgressIndicator(value: _progress),
                    ),
                    SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            if (_isModelExist) ...[
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message.role == Role.user;
                    return Column(
                      children: [
                        Container(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color:
                                    isUser ? Colors.black : Colors.orange[100],
                              ),
                              padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                              child: isUser
                                  ? Text(message.text,
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16))
                                  : GptMarkdown(
                                      message.text,
                                      style: TextStyle(fontSize: 16),
                                    ),
                            )),
                        SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      reverse: true,
                      child: TextField(
                        controller: _questionTextController,
                        keyboardType: TextInputType.multiline,
                        enabled: _runningRequestId == null,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(20)),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    )),
                    SizedBox(width: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _runningRequestId != null
                            ? () => {}
                            : _runChatInference,
                        style: ElevatedButton.styleFrom(
                          enableFeedback: true,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: _runningRequestId != null
                            ? Icon(Icons.stop, color: Colors.grey)
                            : Icon(Icons.send),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
