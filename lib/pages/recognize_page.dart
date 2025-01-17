import 'dart:async';
import 'dart:io';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isAnalysis = false;
  String? _resultText;
  String? _recordingPath;

  /// Work around
  Widget _buildStaticCard() {
    return Container(
      height: 200,
      width: double.infinity,
      child: Card(
        elevation: 12.0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
        child: WaveWidget(
          config: CustomConfig(
            colors: [
              Colors.white70,
              Colors.white54,
              Colors.white30,
              Colors.white24,
            ],
            durations: [4000, 5000, 6000, 7000],
            heightPercentages: [0.25, 0.26, 0.28, 0.31],
          ),
          backgroundColor: Colors.grey[600],
          size: Size(double.infinity, double.infinity),
          isLoop: false,
          waveAmplitude: 0,
        ),
      ),
    );
  }

  Widget _buildAnimatedCard() {
    return AnimatedOpacity(
      opacity: _isRecording ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Container(
        height: 200,
        width: double.infinity,
        child: Card(
          elevation: 12.0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
          ),
          child: WaveWidget(
            config: CustomConfig(
              colors: [
                Colors.white70,
                Colors.white54,
                Colors.white30,
                Colors.white24,
              ],
              durations: [35000, 19440, 10800, 6000],
              heightPercentages: [0.20, 0.23, 0.25, 0.30],
            ),
            backgroundColor: Colors.deepOrange,
            size: Size(double.infinity, double.infinity),
            isLoop: true,
            // Always keep it running
            waveAmplitude: 20,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      final directory = await _getDownloadDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$directory/$timestamp.wav';

      await _recorder.start(
        RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 16000,
            numChannels: 1,
            autoGain: true,
            echoCancel: true),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _isAnalysis = false;
        _recordingPath = path;
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording saved to: $path')),
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;

    try {
      if (_isPlaying) {
        await _player.stop();
        setState(() => _isPlaying = false);
      } else {
        await _player.play(DeviceFileSource(_recordingPath!));
        setState(() => _isPlaying = true);

        // Listen for playback completion
        _player.onPlayerComplete.listen((event) {
          setState(() => _isPlaying = false);
        });
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
    }
  }

  Future<void> _analysisVoice(BuildContext context) async {
    try {
      setState(() {
        _isAnalysis = true;
        _resultText = null;
      });
      final modelDir = await _getDownloadDir();
      final whisper = Whisper(
          model: WhisperModel.medium,
          modelDir: modelDir,
          downloadHost:
              "https://huggingface.co/ggerganov/whisper.cpp/resolve/main");
      if (_recordingPath != null && _recordingPath!.trim() != "") {
        final transcription = await whisper.transcribe(
          transcribeRequest: TranscribeRequest(
              audio: _recordingPath!,
              // Path to audio file
              isTranslate: false,
              language: "vi",
              // Translate result from audio lang to english text
              isNoTimestamps: false,
              nProcessors: Platform.numberOfProcessors - 1,
              // Get segments in result
              splitOnWord: true,
              speedUp: true),
        );
        setState(() {
          _resultText = transcription.text;
        });
      }
    } catch (e) {
      debugPrint('Error analysis voice: $e');
    } finally {
      setState(() {
        _isAnalysis = false;
      });
    }
  }

  Future<void> _uploadFile() async {
    setState(() {
      _recordingPath = null;
      _isRecording = false;
      _isAnalysis = false;
      _resultText = null;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _recordingPath = result.files.single.path;
      });
    }
  }

  Future<String> _getDownloadDir() async {
    final Directory? libraryDirectory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getLibraryDirectory();
    return libraryDirectory!.path;
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Record & Analysis',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildStaticCard(),
                _buildAnimatedCard(), // Always present, just invisible
              ],
            ),
            const SizedBox(height: 40),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FloatingActionButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                backgroundColor:
                    _isRecording ? Colors.red[600] : Colors.deepOrangeAccent,
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
              ),
              const SizedBox(
                width: 40,
              ),
              FloatingActionButton(
                onPressed: () async {
                  _uploadFile();
                },
                backgroundColor: Colors.blue[600],
                child: Icon(
                  Icons.file_upload,
                  color: Colors.white,
                ),
              ),
            ]),
            const SizedBox(
              height: 40,
            ),
            const Divider(
              height: 20,
              thickness: 2,
              endIndent: 0,
              color: Colors.deepOrange,
            ),
            if (_recordingPath != null && !_isRecording) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 60,
                    child: TextButton(
                      onPressed: _playRecording,
                      style: TextButton.styleFrom(
                          backgroundColor:
                              _isPlaying ? Colors.red[900] : Colors.deepOrange),
                      child: Text(
                        _isPlaying ? "Stop" : "Play",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 40,
                  ),
                  SizedBox(
                    width: 120,
                    height: 60,
                    child: TextButton(
                      onPressed: () async {
                        _analysisVoice(context);
                      },
                      style: TextButton.styleFrom(
                          backgroundColor:
                              _isAnalysis ? Colors.red[900] : Colors.blue),
                      child: Text(
                        _isAnalysis ? "Stop" : "Analysis",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 40,
                  ),
                ],
              )
            ],
            if (_recordingPath != null && _isAnalysis) ...[
              SizedBox(
                height: 40,
              ),
              SizedBox(
                width: 250.0,
                child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontSize: 18.0,
                      fontWeight: FontWeight.normal,
                    ),
                    child: AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText(
                          "Analysis is in process. You can't stop",
                          textStyle: const TextStyle(
                            fontSize: 32.0,
                            fontWeight: FontWeight.bold,
                          ),
                          speed: const Duration(milliseconds: 100),
                        ),
                      ],
                      isRepeatingAnimation: true,
                      pause: const Duration(milliseconds: 50),
                      displayFullTextOnTap: true,
                      stopPauseOnTap: true,
                    )),
              ),
            ],
            if (_resultText != null) ...[
              CustomPopup(
                content: Text(_resultText!),
                child: Icon(Icons.help),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
