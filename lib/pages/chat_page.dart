import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../services/hugging_face_service.dart';

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

  final _modelName = 'Qwen2.5-3B.Q4_0.gguf';
  final _downloader = HuggingFaceDownloader(
    modelUrl:
        'https://huggingface.co/QuantFactory/Qwen2.5-3B-GGUF/resolve/main/Qwen2.5-3B.Q4_0.gguf?download=true',
    fileName: 'Qwen2.5-3B.Q4_0.gguf',
  );

  @override
  void initState() {
    super.initState();
    _checkModelExistence();
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
      if (_isModelExist) {
        _status = 'Downloaded';
      }
    });
  }

  Future<void> _moveFile(File source, String targetPath) async {
    try {
      await source.rename(targetPath);
    } catch (e) {
      // If rename fails (e.g., across devices), try copy and delete
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

  Future<void> _startDownload({bool force = false}) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _status = 'Starting download...';
    });

    try {
      // Clean up any existing temp files
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
              setState(() {
                _status = 'Downloaded';
                _isDownloading = false;
                _isModelExist = true;
              });
            } else {
              throw Exception('Downloaded file not found in temp directory');
            }
          } catch (e) {
            setState(() {
              _status = 'Error moving file: $e';
              _isDownloading = false;
            });
          } finally {
            // Clean up temp directory
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
                await _startDownload(force: true);
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
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            if (!_isModelExist && !_isDownloading)
              ElevatedButton(
                onPressed: () => _startDownload(),
                style: ElevatedButton.styleFrom(
                    textStyle: TextStyle(fontWeight: FontWeight.w900)),
                child: Text('Download Model'),
              ),
            if (_isDownloading)
              Column(
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
          ],
        ),
      ),
    );
  }
}
