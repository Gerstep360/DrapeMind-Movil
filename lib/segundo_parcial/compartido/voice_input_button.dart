import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';

class VoiceInputButton extends StatefulWidget {
  final ValueChanged<String> onText;
  final String purpose;
  final bool disabled;
  final ApiClient? api;
  final String? label;
  final ValueChanged<bool>? onBusy;
  const VoiceInputButton({
    super.key,
    required this.onText,
    this.purpose = 'ALTAIR',
    this.disabled = false,
    this.api,
    this.label,
    this.onBusy,
  });
  @override
  State<VoiceInputButton> createState() => _VoiceInputState();
}

class _VoiceInputState extends State<VoiceInputButton>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('drapemind/documents');
  bool _recording = false, _processing = false, _starting = false;
  int _seconds = 0;
  Timer? _timer;
  late final _api = widget.api ?? ApiClient();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_recording || _starting) {
      unawaited(channel.invokeMethod<void>('cancelVoice').catchError((_) {}));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _recording) {
      _timer?.cancel();
      unawaited(channel.invokeMethod<void>('cancelVoice').catchError((_) {}));
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _toggle() async {
    if (_processing || _starting) return;
    try {
      if (!_recording) {
        setState(() => _starting = true);
        widget.onBusy?.call(true);
        await channel.invokeMethod<void>('startVoice');
        if (!mounted) {
          await channel.invokeMethod<void>('cancelVoice');
          return;
        }
        setState(() {
          _recording = true;
          _seconds = 0;
          _starting = false;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
          if (_seconds >= 60) {
            _timer?.cancel();
            _toggle();
          }
        });
      } else {
        _timer?.cancel();
        setState(() {
          _recording = false;
          _processing = true;
        });
        final bytes = await channel.invokeMethod<Uint8List>('stopVoice');
        if (bytes == null) {
          throw ApiException('No se pudo recuperar la grabación.');
        }
        final result = await _api.post(
          '/voice/transcribe',
          body: {'audio_wav': base64Encode(bytes), 'proposito': widget.purpose},
          timeout: const Duration(seconds: 45),
        );
        if (mounted) widget.onText(result['texto'] as String);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PlatformException
                  ? e.message ?? 'No pudimos abrir el micrófono.'
                  : e is ApiException
                  ? e.message
                  : 'La voz no está disponible en este dispositivo. Puedes escribir tu consulta.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _processing = false;
        });
        widget.onBusy?.call(_recording);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.label != null
      ? OutlinedButton.icon(
          onPressed: widget.disabled || _processing || _starting
              ? null
              : _toggle,
          icon: Icon(
            _recording ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
          ),
          label: Text(
            _processing
                ? 'Transcribiendo…'
                : _recording
                ? 'Terminar ($_seconds s)'
                : widget.label!,
          ),
        )
      : IconButton(
          tooltip: _processing
              ? 'Transcribiendo con NVIDIA…'
              : _recording
              ? 'Terminar grabación ($_seconds s)'
              : 'Dictar consulta',
          onPressed: widget.disabled || _processing || _starting
              ? null
              : _toggle,
          color: _recording ? Colors.red : null,
          icon: _processing || _starting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _recording
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_rounded,
                ),
        );
}
