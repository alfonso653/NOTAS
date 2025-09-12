import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Modelo para guardar info de audio
class _AudioInfo {
	final File file;
	final DateTime date;
	final Duration duration;
	_AudioInfo({required this.file, required this.date, required this.duration});
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
		List<_AudioInfo> audios = [];
		if (await noteDir.exists()) {
			for (var file in noteDir.listSync().whereType<File>()) {
				if (file.path.endsWith('.aac')) {
					// Buscar archivo de metadata
					final metaFile = File(file.path + '.json');
					if (await metaFile.exists()) {
						final meta = await metaFile.readAsString();
						final data = meta.split('|');
						audios.add(_AudioInfo(
							file: file,
							date: DateTime.tryParse(data[0]) ?? DateTime.now(),
							duration: Duration(seconds: int.tryParse(data[1]) ?? 0),
						));
					} else {
						audios.add(_AudioInfo(
							file: file,
							date: file.lastModifiedSync(),
							duration: Duration.zero,
						));
					}
				}
			}
			setState(() {
				_audioFiles = audios;
			});
		}
	}

		Future<void> _startRecording() async {
			// Solicitar permiso de micrófono
			var status = await Permission.microphone.request();
			if (!status.isGranted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Permiso de micrófono denegado')),
				);
				return;
			}
			setState(() {
				_isRecording = true;
				_recordDuration = Duration.zero;
			});
			_recordStart = DateTime.now();
			_timer = Timer.periodic(Duration(seconds: 1), (timer) {
				setState(() {
					_recordDuration = DateTime.now().difference(_recordStart);
				});
			});
			final dir = await getApplicationDocumentsDirectory();
			final noteDir = Directory('${dir.path}/audio_${widget.noteId}');
			if (!await noteDir.exists()) await noteDir.create();
			final filePath = '${noteDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
			await _recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);
		}

	Future<void> _stopRecording() async {
		await _recorder.stopRecorder();
		_timer?.cancel();
		setState(() { _isRecording = false; });
		// Guardar metadata
		final dir = await getApplicationDocumentsDirectory();
		final noteDir = Directory('${dir.path}/audio_${widget.noteId}');
		if (await noteDir.exists()) {
			// Buscar el último archivo .aac creado
			final files = noteDir.listSync().whereType<File>().where((f) => f.path.endsWith('.aac')).toList();
			if (files.isNotEmpty) {
				final lastFile = files.reduce((a, b) => a.lastModifiedSync().isAfter(b.lastModifiedSync()) ? a : b);
				final metaFile = File(lastFile.path + '.json');
				await metaFile.writeAsString('${DateTime.now().toIso8601String()}|${_recordDuration.inSeconds}');
			}
		}
		await _loadAudioFiles();
	}

	Future<void> _playAudio(File file) async {
		await _player.startPlayer(fromURI: file.path, codec: Codec.aacADTS);
	}

	@override
	void dispose() {
		_recorder.closeRecorder();
		_player.closePlayer();
		super.dispose();
	}

	void _showAudioList() {
		showModalBottomSheet(
			context: context,
			builder: (ctx) {
				return ListView(
					children: _audioFiles.map((audio) => ListTile(
						title: Text(_formatDate(audio.date)),
						subtitle: Text('Duración: ${_formatDuration(audio.duration)}'),
									trailing: IconButton(
										icon: Text('🔊', style: TextStyle(fontSize: 24)),
										onPressed: () => _playAudio(audio.file),
									),
					)).toList(),
				);
			},
		);
	}
String _formatDate(DateTime date) {
	return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						AnimatedScale(
							scale: _isRecording ? 1.2 : 1.0,
							duration: Duration(milliseconds: 300),
							child: IconButton(
								icon: Text(
									_isRecording ? '🔴' : '🟢',
									style: TextStyle(fontSize: 32),
								),
								color: _isRecording ? Colors.red : Colors.green,
								tooltip: _isRecording ? 'Grabando...' : 'Grabar audio',
								onPressed: _isRecording ? _stopRecording : _startRecording,
							),
						),
						if (_isRecording)
							Padding(
								padding: const EdgeInsets.only(left: 8.0),
								child: Text(
									_formatDuration(_recordDuration),
									style: TextStyle(
										fontSize: 20,
										fontWeight: FontWeight.bold,
										color: Colors.black87,
									),
								),
							),
					],
				),
				SizedBox(height: 8),
				GestureDetector(
					onTap: _showAudioList,
					child: Container(
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(16),
							boxShadow: [
								BoxShadow(
									color: Colors.black12,
									blurRadius: 8,
									offset: Offset(0, 2),
								),
							],
						),
						padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
						child: Text(
							'🎼',
							style: TextStyle(
								fontSize: 32,
								fontWeight: FontWeight.bold,
								color: Colors.purpleAccent,
								shadows: [
									Shadow(
										color: Colors.purpleAccent.withOpacity(0.3),
										blurRadius: 6,
										offset: Offset(0, 2),
									),
								],
							),
						),
					),
				),
			],
		);

	}

	String _formatDuration(Duration d) {
		String twoDigits(int n) => n.toString().padLeft(2, '0');
		final m = twoDigits(d.inMinutes);
		final s = twoDigits(d.inSeconds % 60);
		return "$m:$s";
	}
}
