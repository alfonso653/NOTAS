import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final m = two(d.inMinutes);
  final s = two(d.inSeconds % 60);
  return "$m:$s";
}

/// Modelo de audio
class _AudioInfo {
  final File file;
  final DateTime date;
  Duration duration; // <- mutable para actualizar si vino en 0
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

  // Para refrescar el BottomSheet desde fuera del builder
  StateSetter? _sheetSetState;

  // Progreso
  Duration _currentPosition = Duration.zero;
  bool _isDragging = false;
  bool _isRecording = false;
  List<_AudioInfo> _audioFiles = [];

  // Suscripción al stream de progreso
  StreamSubscription? _progressSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _recorder.openRecorder();
    await _player.openPlayer();

    // Emitir progreso cada 200 ms
    await _player.setSubscriptionDuration(const Duration(milliseconds: 200));

    // Suscripción al stream de progreso
    _progressSub = _player.onProgress?.listen((event) {
      // Algunas versiones exponen event.position / event.duration (Duration)
      final pos = event.position ?? Duration.zero;
      final total = event.duration ?? Duration.zero;

      if (!mounted) return;
      if (_isDragging) return; // no auto-mover mientras arrastras

      // Refrescar dentro del BottomSheet si está abierto; si no, en el padre
      final updater = _sheetSetState ?? setState;
      updater(() {
        _currentPosition = pos;
        // Si la duración guardada del audio actual es 0, actualízala
        final playing = _audioFiles.where((a) => a.isPlaying).toList();
        if (playing.isNotEmpty) {
          final a = playing.first;
          if (a.duration == Duration.zero && total > Duration.zero) {
            a.duration = total;
          }
        }
      });
    });

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
      if (mounted) {
        setState(() {
          _recordDuration = DateTime.now().difference(_recordStart);
        });
      }
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
      setState(() {
        audio.isPlaying = false;
        _currentPosition = Duration.zero;
      });
      return;
    }

    await _player.stopPlayer();

    setState(() {
      for (var a in _audioFiles) {
        a.isPlaying = false;
      }
      audio.isPlaying = true;
      _currentPosition = Duration.zero;
    });

    await _player.startPlayer(
      fromURI: audio.file.path,
      codec: Codec.aacADTS,
      whenFinished: () {
        if (mounted) {
          setState(() {
            audio.isPlaying = false;
            _currentPosition = Duration.zero;
          });
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
      setState(() {});
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            _sheetSetState = setModalState; // <- guardamos la referencia
            return Container(
              color: const Color(0xFFF8F3E8),
              child: ListView(
                children: _audioFiles.map((audio) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              "${_formatDate(audio.date)}   -   ${_formatDuration(audio.duration)}",
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Text(
                                    audio.isPlaying ? '⏸️' : '▶️',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  onPressed: () async {
                                    await _playOrToggle(audio);
                                    setModalState(() {}); // refresca el sheet
                                  },
                                ),
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
                                            borderRadius:
                                                BorderRadius.circular(12)),
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
                                                style: TextStyle(
                                                    color: Colors.red)),
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteAudio(audio);
                                      setModalState(() {}); // refresca
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          // Barra de progreso interactiva (solo se muestra si está reproduciendo)
                          if (audio.isPlaying)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.blue,
                                      inactiveTrackColor: Colors.grey[300],
                                      thumbColor: Colors.blue,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 10.0),
                                      trackHeight: 6.0,
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 20.0),
                                      trackShape:
                                          const RoundedRectSliderTrackShape(),
                                    ),
                                    child: Slider(
                                      value: audio.duration.inMilliseconds > 0
                                          ? _currentPosition.inMilliseconds
                                              .toDouble()
                                              .clamp(
                                                  0.0,
                                                  audio.duration.inMilliseconds
                                                      .toDouble())
                                          : 0.0,
                                      min: 0.0,
                                      max: audio.duration.inMilliseconds > 0
                                          ? audio.duration.inMilliseconds
                                              .toDouble()
                                          : 100.0,
                                      onChangeStart: (double value) {
                                        _isDragging = true;
                                      },
                                      onChanged: (double value) {
                                        setModalState(() {
                                          _currentPosition = Duration(
                                              milliseconds: value.toInt());
                                        });
                                      },
                                      onChangeEnd: (double value) async {
                                        _isDragging = false;
                                        setModalState(() {
                                          _currentPosition = Duration(
                                              milliseconds: value.toInt());
                                        });
                                        try {
                                          await _player
                                              .seekToPlayer(_currentPosition);
                                        } catch (_) {
                                          // versiones antiguas:
                                          // await _player.seekToPosition(_currentPosition);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_formatDuration(_currentPosition)} / ${_formatDuration(audio.duration)}",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _sheetSetState = null; // limpiar referencia al cerrar
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _timer?.cancel(); // limpia cronómetro de grabación
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
