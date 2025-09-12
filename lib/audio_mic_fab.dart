import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Modelo de audio
class _AudioInfo {
  final File file;
  final DateTime date;
  final Duration duration;
  bool isPlaying;

  _AudioInfo({
    required this.file,
    required this.date,
    required this.duration,
    required this.isPlaying,
  });
}

Duration _recordDuration = Duration.zero;
late DateTime _recordStart;
Timer? _timer;

class AudioButton extends StatefulWidget {
  final String noteId;
  const AudioButton({Key? key, required this.noteId}) : super(key: key);

  @override
  State<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<AudioButton> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecording = false;
  List<_AudioInfo> _audioFiles = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _recorder.openRecorder();
    await _player.openPlayer();
    await _loadAudioFiles();
  }

  Future<void> _loadAudioFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final noteDir = Directory('${dir.path}/audio_${widget.noteId}');
    final List<_AudioInfo> audios = [];

    if (await noteDir.exists()) {
      for (final file in noteDir.listSync().whereType<File>()) {
        if (file.path.endsWith('.aac')) {
          final metaFile = File(file.path + '.json');
          if (await metaFile.exists()) {
            final meta = await metaFile.readAsString();
            final parts = meta.split('|');
            audios.add(
              _AudioInfo(
                file: file,
                date: DateTime.tryParse(parts[0]) ?? DateTime.now(),
                duration: Duration(seconds: int.tryParse(parts[1]) ?? 0),
                isPlaying: false,
              ),
            );
          } else {
            audios.add(
              _AudioInfo(
                file: file,
                date: file.lastModifiedSync(),
                duration: Duration.zero,
                isPlaying: false,
              ),
            );
          }
        }
      }
    }

    setState(() => _audioFiles = audios);
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de micrófono denegado')),
      );
      return;
    }
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });

    _recordStart = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordDuration = DateTime.now().difference(_recordStart);
      });
    });

    final dir = await getApplicationDocumentsDirectory();
    final noteDir = Directory('${dir.path}/audio_${widget.noteId}');
    if (!await noteDir.exists()) await noteDir.create();
    final filePath =
        '${noteDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _timer?.cancel();
    setState(() => _isRecording = false);

    final dir = await getApplicationDocumentsDirectory();
    final noteDir = Directory('${dir.path}/audio_${widget.noteId}');
    if (await noteDir.exists()) {
      final files = noteDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.aac'))
          .toList();
      if (files.isNotEmpty) {
        final last = files.reduce((a, b) =>
            a.lastModifiedSync().isAfter(b.lastModifiedSync()) ? a : b);
        final metaFile = File(last.path + '.json');
        await metaFile.writeAsString(
          '${DateTime.now().toIso8601String()}|${_recordDuration.inSeconds}',
        );
      }
    }
    await _loadAudioFiles();
  }

  Future<void> _playOrToggle(_AudioInfo audio) async {
    if (audio.isPlaying) {
      await _player.stopPlayer();
      setState(() => audio.isPlaying = false);
      return;
    }

    await _player.stopPlayer();
    setState(() {
      for (var a in _audioFiles) {
        a.isPlaying = false;
      }
      audio.isPlaying = true;
    });

    await _player.startPlayer(
      fromURI: audio.file.path,
      codec: Codec.aacADTS,
      whenFinished: () {
        if (mounted) {
          setState(() => audio.isPlaying = false);
        }
      },
    );
  }

  Future<void> _deleteAudio(_AudioInfo audio) async {
    try {
      if (await audio.file.exists()) await audio.file.delete();
      final metaFile = File(audio.file.path + '.json');
      if (await metaFile.exists()) await metaFile.delete();
      await _loadAudioFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error eliminando audio: $e')),
      );
    }
  }

  void _showAudioList() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          color: const Color(0xFFF8F3E8),
          child: ListView(
            children: _audioFiles.map((audio) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(
                      "${_formatDate(audio.date)}   -   ${_formatDuration(audio.duration)}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ▶️ / ⏸️ con emojis
                        IconButton(
                          icon: Text(
                            audio.isPlaying ? '⏸️' : '▶️',
                            style: const TextStyle(fontSize: 22),
                          ),
                          onPressed: () => _playOrToggle(audio),
                        ),
                        // 🗑️ con emoji
                        IconButton(
                          icon: const Text(
                            '🗑️',
                            style: TextStyle(fontSize: 22),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                title: const Text("¿Eliminar seguro?"),
                                content: const Text(
                                    "Esta acción no se puede deshacer."),
                                actions: [
                                  TextButton(
                                    child: const Text("Cancelar"),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                  ),
                                  TextButton(
                                    child: const Text("Eliminar",
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              Navigator.of(context).pop();
                              await Future.delayed(
                                  const Duration(milliseconds: 200));
                              await _deleteAudio(audio);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes);
    final s = two(d.inSeconds % 60);
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                _formatDuration(_recordDuration),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          // 🔴 / 🟢
          FloatingActionButton(
            heroTag: "recorder_btn",
            backgroundColor: Colors.white,
            onPressed: _isRecording ? _stopRecording : _startRecording,
            child: Text(
              _isRecording ? '🔴' : '🟢',
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(height: 12),
          // 🎼
          FloatingActionButton(
            heroTag: "list_btn",
            backgroundColor: Colors.white,
            onPressed: _showAudioList,
            child: const Text(
              '🎼',
              style: TextStyle(fontSize: 24, color: Colors.purpleAccent),
            ),
          ),
        ],
      ),
    );
  }
}
