import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:audio_streamer/audio_streamer.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class MyNoiseMeter {
  AudioStreamer _streamer = AudioStreamer();
  late StreamController<NoiseReading> _controller;

  Stream<NoiseReading>? _stream;

  // The error callback function.
  Function? onError;
  MyNoiseMeter([this.onError]);

  static int get sampleRate => AudioStreamer.sampleRate;

  Stream<NoiseReading> get noiseStream {
    if (_stream == null) {
      _controller = StreamController<NoiseReading>.broadcast(
          onListen: _start, onCancel: _stop);
      _stream = (onError != null)
          ? _controller.stream.handleError(onError!)
          : _controller.stream;
    }
    return _stream!;
  }

  void _onAudio(List<double> buffer) => _controller.add(NoiseReading(buffer));

  void _onInternalError(PlatformException e) {
    _stream = null;
    _controller.addError(e);
  }

  void _start() async {
    try {
      _streamer.start(_onAudio, _onInternalError);
    } catch (error) {
      print(error);
    }
  }

  /// Stop noise monitoring
  void _stop() async => await _streamer.stop();
}
