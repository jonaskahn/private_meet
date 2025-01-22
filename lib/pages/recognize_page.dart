import 'dart:async';
import 'dart:io';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:private_meet/pages/chat_page.dart';
import 'package:record/record.dart';
import 'package:timer_stop_watch/timer_stop_watch.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../services/audio_service.dart';

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final _timerStopWatch = TimerStopWatch();

  String? _timer;
  late Stream<String> _stopwatch;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isAnalysis = false;
  String? _resultText;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _stopwatch =
        _timerStopWatch.setStopwatch(timeFormat: "hh:mm:ss", start: true);
  }

  @override
  void dispose() {
    _timerStopWatch.dispose();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// Work around
  Widget _buildStaticCard() {
    return SizedBox(
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
      child: SizedBox(
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

  Future<void> _checkPermission() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  void _resetStatesBeforeRecordOrUpload() {
    setState(() {
      _timer = null;
      _resultText = null;
      _isAnalysis = false;
      _isPlaying = false;
      _recordingPath = null;
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    _resetStatesBeforeRecordOrUpload();
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

  void _resetStateBeforeAnalysis() {
    setState(() {
      _isAnalysis = true;
      _resultText = null;
      _timer = null;
      _stopwatch =
          _timerStopWatch.setStopwatch(timeFormat: "hh:mm:ss", start: true);
    });
  }

  Future<void> _analysisVoice() async {
    if (_isAnalysis) {
      return;
    }
    try {
      _resetStateBeforeAnalysis();
      final modelDir = await _getDownloadDir();
      final whisper = Whisper(
          model: WhisperModel.mediumQ5,
          modelDir: modelDir,
          downloadHost:
              "https://huggingface.co/ggerganov/whisper.cpp/resolve/main");
      if (_recordingPath != null && _recordingPath!.trim() != "") {
        _timerStopWatch.startStopwatch();
        final audioService = AudioService();
        final result = await audioService.analysis(filePath: _recordingPath!);
        setState(() {
          _isAnalysis = false;
          _isRecording = false;
          _resultText = result;
          _isPlaying = false;
          _recordingPath = null;
        });
      }
    } catch (e) {
      debugPrint('Error analysis voice: $e');
    } finally {
      setState(() {
        _isAnalysis = false;
        _stopwatch =
            _timerStopWatch.setStopwatch(timeFormat: "hh:mm:ss", start: true);
      });
    }
  }

  Future<void> _uploadFile() async {
    _resetStatesBeforeRecordOrUpload();
    final instance = FilePicker.platform;

    FilePickerResult? result = await instance.pickFiles();
    FilePickerStatus.done;
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
                heroTag: "btn1",
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
                heroTag: "btn2",
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
            if (_recordingPath != null &&
                !_isRecording &&
                _resultText == null) ...[
              const SizedBox(height: 40),
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
                        _analysisVoice();
                      },
                      style: TextButton.styleFrom(backgroundColor: Colors.blue),
                      child: Text(
                        "Analysis",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            ],
            if (_recordingPath != null && _isAnalysis) ...[
              SizedBox(
                height: 40,
              ),
              StreamBuilder(
                  stream: _stopwatch,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _timer = snapshot.data.toString();
                      return Text(
                        snapshot.data.toString(),
                        style: TextStyle(fontSize: 16),
                      );
                    } else if (snapshot.hasError) {
                      print(snapshot.error);
                      return SizedBox();
                    } else {
                      return CircularProgressIndicator();
                    }
                  }),
              SizedBox(
                height: 20,
              ),
              DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  child: AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        "analysis voice",
                        textStyle: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                        speed: const Duration(milliseconds: 100),
                      ),
                    ],
                    repeatForever: _isAnalysis,
                    isRepeatingAnimation: true,
                    displayFullTextOnTap: true,
                    stopPauseOnTap: false,
                  )),
            ],
            if (_resultText != null) ...[
              SizedBox(
                height: 40,
              ),
              SizedBox(
                width: 120,
                height: 60,
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(data: _resultText!),
                        ),
                      );
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: Text(
                      "Chat now",
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w900),
                    )),
              ),
              SizedBox(height: 40),
              Text("Analysis in: $_timer")
            ],
          ],
        ),
      ),
    );
  }
}
