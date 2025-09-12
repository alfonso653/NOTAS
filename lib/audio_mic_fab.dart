import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

// Widget de animación de ondas tipo ecualizador
class WaveAnimation extends StatefulWidget {
	final bool isActive;
	const WaveAnimation({Key? key, required this.isActive}) : super(key: key);
	@override
	State<WaveAnimation> createState() => WaveAnimationState();
}

class WaveAnimationState extends State<WaveAnimation> with SingleTickerProviderStateMixin {
	late AnimationController _controller;
	late List<Animation<double>> _bars;

	@override
	void initState() {
		super.initState();
		_controller = AnimationController(
			vsync: this,
			duration: Duration(milliseconds: 900),
		);
		_bars = List.generate(4, (i) => Tween<double>(begin: 8, end: 22 + i * 4).animate(
			CurvedAnimation(parent: _controller, curve: Interval(i * 0.15, 1.0, curve: Curves.easeInOut)),
		));
		if (widget.isActive) _controller.repeat(reverse: true);
	}

	@override
	void didUpdateWidget(covariant WaveAnimation oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.isActive && !_controller.isAnimating) {
			_controller.repeat(reverse: true);
		} else if (!widget.isActive && _controller.isAnimating) {
			_controller.stop();
			setState(() {});
		}
	}

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			width: 32,
			height: 28,
			child: Row(
				mainAxisAlignment: MainAxisAlignment.center,
				children: List.generate(_bars.length, (i) => AnimatedBuilder(
					animation: _controller,
					builder: (ctx, child) {
						return Container(
							width: 5,
							height: widget.isActive ? _bars[i].value : 10,
							margin: EdgeInsets.symmetric(horizontal: 2),
							decoration: BoxDecoration(
								color: widget.isActive ? Colors.blueAccent : Colors.grey[300],
								borderRadius: BorderRadius.circular(3),
							),
						);
					},
				)),
			),
		);
	}
}

// Modelo para guardar info de audio
class _AudioInfo {
	final File file;
	final DateTime date;
	final Duration duration;
	bool isPlaying;
		_AudioInfo({required this.file, required this.date, required this.duration, required this.isPlaying});
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

		Future<void> _deleteAudio(_AudioInfo audio) async {
			try {
				if (await audio.file.exists()) {
					await audio.file.delete();
				}
				final metaFile = File(audio.file.path + '.json');
				if (await metaFile.exists()) {
					await metaFile.delete();
				}
				await _loadAudioFiles();
			} catch (e) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error eliminando audio: $e')),
				);
			}
		}


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
										isPlaying: false,
									));
					} else {
									audios.add(_AudioInfo(
										file: file,
										date: file.lastModifiedSync(),
										duration: Duration.zero,
										isPlaying: false,
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

		Future<void> _playAudio(_AudioInfo audio) async {
			setState(() {
				for (var a in _audioFiles) {
					a.isPlaying = false;
				}
				audio.isPlaying = true;
			});
			await _player.startPlayer(fromURI: audio.file.path, codec: Codec.aacADTS,
				whenFinished: () {
					setState(() {
						audio.isPlaying = false;
					});
				},
			);
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
												children: _audioFiles.map((audio) => Padding(
													padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
																child: Container(
																	decoration: BoxDecoration(
																		color: Colors.white,
																		borderRadius: BorderRadius.circular(16),
																		boxShadow: [
																			BoxShadow(
																				color: Colors.black12,
																				blurRadius: 6,
																				offset: Offset(0, 2),
																			),
																		],
																	),
																	padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
																	child: Row(
																		mainAxisSize: MainAxisSize.max,
																		children: [
																			Expanded(
																				child: Column(
																					crossAxisAlignment: CrossAxisAlignment.start,
																					children: [
																						Text(_formatDate(audio.date), style: TextStyle(fontWeight: FontWeight.bold)),
																						SizedBox(height: 4),
																						Text('Duración: ${_formatDuration(audio.duration)}'),
																					],
																				),
																			),
																			Padding(
																				padding: const EdgeInsets.symmetric(horizontal: 2),
																				child: WaveAnimation(isActive: audio.isPlaying),
																			),
																								IconButton(
																									icon: Text('🔊', style: TextStyle(fontSize: 24)),
																									onPressed: () => _playAudio(audio),
																								),
																																IconButton(
																																		icon: Text('🗑️', style: TextStyle(fontSize: 24)),
																																		tooltip: 'Eliminar audio',
																																		onPressed: () async {
																																				final confirm = await showDialog<bool>(
																																					context: context,
																																					builder: (ctx) => AlertDialog(
																																						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
																																						title: Text('¿Eliminar audio?', style: TextStyle(fontWeight: FontWeight.bold)),
																																						content: Text('Esta acción no se puede deshacer.'),
																																						actions: [
																																							TextButton(
																																								child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
																																								onPressed: () => Navigator.of(ctx).pop(false),
																																							),
																																							TextButton(
																																								child: Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
																																								onPressed: () => Navigator.of(ctx).pop(true),
																																							),
																																						],
																																					),
																																				);
																																														if (confirm == true) {
																																															Navigator.of(context).pop();
																																															await Future.delayed(Duration(milliseconds: 200));
																																															await _deleteAudio(audio);
																																														}
																																		},
																																),
// ...existing code...
																		],
																	),
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
