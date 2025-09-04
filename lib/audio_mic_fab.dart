import 'package:flutter/material.dart';
import 'audio_recording_bar.dart';

class AudioMicFAB extends StatefulWidget {
  const AudioMicFAB({Key? key}) : super(key: key);
  @override
  State<AudioMicFAB> createState() => _AudioMicFABState();
}

class _AudioMicFABState extends State<AudioMicFAB> {
  bool _recording = false;

  void _startRecording() {
    setState(() {
      _recording = true;
    });
  }

  void _stopRecording() {
    setState(() {
      _recording = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'audio_mic',
          backgroundColor: Colors.white,
          child: Image.asset(
            'assets/audio.gif',
            width: 28,
            height: 28,
          ),
          onPressed: _recording ? null : _startRecording,
        ),
        if (_recording)
          AudioRecordingBar(
            onStop: _stopRecording,
          ),
      ],
    );
  }
}
