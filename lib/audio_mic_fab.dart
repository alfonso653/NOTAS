import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
	List<File> _audioFiles = [];

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
		if (await noteDir.exists()) {
			setState(() {
				_audioFiles = noteDir.listSync().whereType<File>().toList();
			});
		}
	}

		Future<void> _startRecording() async {
			setState(() { _isRecording = true; }); // Cambia a rojo antes de iniciar grabación
			final dir = await getApplicationDocumentsDirectory();
			final noteDir = Directory('${dir.path}/audio_${widget.noteId}');
			if (!await noteDir.exists()) await noteDir.create();
			final filePath = '${noteDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
			await _recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);
		}

	Future<void> _stopRecording() async {
		await _recorder.stopRecorder();
		setState(() { _isRecording = false; });
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
					children: _audioFiles.map((file) => ListTile(
						title: Text(file.path.split('/').last),
						trailing: IconButton(
							icon: Icon(Icons.play_arrow),
							onPressed: () => _playAudio(file),
						),
					)).toList(),
				);
			},
		);
	}

	@override
	Widget build(BuildContext context) {
		return Column(
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
				SizedBox(height: 8),
				IconButton(
					icon: Icon(Icons.more_vert),
					onPressed: _showAudioList,
				),
			],
		);
	}
}
