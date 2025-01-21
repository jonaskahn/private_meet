import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class AudioService {
  Future<String> analysis({required String filePath}) async {
    final whisper = Whisper(
        model: WhisperModel.mediumQ8,
        modelDir: await _getDownloadDir(),
        downloadHost:
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main");
    final player = AudioPlayer();
    var duration = await player.setUrl(filePath);
    player.dispose();
    debugPrint("Audio in: ${duration?.inSeconds} seconds");
    int parts = ((duration?.inSeconds ?? 0) / 30).ceil();
    if (parts == 0) {
      return "";
    }

    if (parts == 1) {
      return recognizeVoice(whisper, filePath);
    }
    return recognizeVoice(whisper, filePath);
  }

  Future<String> _getDownloadDir() async {
    final Directory? libraryDirectory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getLibraryDirectory();
    return libraryDirectory!.path;
  }

  Future<String> recognizeVoice(Whisper whisper, String path) async {
    final transcription = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
          audio: path,
          // Path to audio file
          isTranslate: false,
          isVerbose: true,
          language: "vi",
          // Translate result from audio lang to english text
          isNoTimestamps: true,
          nProcessors: Platform.numberOfProcessors - 1,
          // Get segments in result
          splitOnWord: true,
          speedUp: true),
    );
    return transcription.text;
  }
}
