import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/realidad_aumentada/utilizar_vestidor_virtual/dominio/body_geometry.dart';
import 'componentes/ar_painters.dart';

/// On-device upper-body try-on. The demo is not a catalogue item or a size scan.
class BodyTryOnScreen extends StatefulWidget {
  const BodyTryOnScreen({super.key});
  @override
  State<BodyTryOnScreen> createState() => _BodyTryOnScreenState();
}

class _BodyTryOnScreenState extends State<BodyTryOnScreen>
    with WidgetsBindingObserver {
  final _scan = BodyScan();
  final _detector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );
  CameraController? _camera;
  Future<void>? _pendingFrame;
  Future<void>? _shutdown;
  bool _starting = false, _disposed = false, _front = true;
  bool _foreground = true, _resumeRequested = false;
  int _generation = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDetection = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchdog;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    _watchdog = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted &&
          _scan.anchors != null &&
          DateTime.now().difference(_lastDetection).inMilliseconds > 600) {
        setState(_scan.reset);
      }
    });
  }

  Future<void> _start() async {
    if (_disposed || !_foreground || _camera != null) return;
    if (_starting) {
      _resumeRequested = true;
      return;
    }
    _starting = true;
    if (mounted) setState(() {});
    final generation = ++_generation;
    CameraController? controller;
    try {
      await _shutdown;
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw StateError('El seguimiento corporal requiere Android o iOS.');
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No hay una cámara disponible.');
      final lens = _front
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final description = cameras.firstWhere(
        (c) => c.lensDirection == lens,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      setState(() {
        _error = null;
        _scan.reset();
      });
      await controller.startImageStream((frame) {
        if (_pendingFrame != null || generation != _generation || _disposed) {
          return;
        }
        if (DateTime.now().difference(_lastFrame).inMilliseconds < 100) return;
        _lastFrame = DateTime.now();
        _pendingFrame = _detect(
          frame,
          description,
          generation,
        ).whenComplete(() => _pendingFrame = null);
      });
    } catch (e) {
      if (controller != null) await controller.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _camera = null;
          _error = e is CameraException
              ? 'No se pudo abrir la cámara. Revisa su permiso en Ajustes.'
              : 'No se pudo iniciar el seguimiento corporal. Reintenta en un dispositivo compatible.';
        });
      }
    } finally {
      _starting = false;
      if (mounted) setState(() {});
      final resume = _resumeRequested;
      _resumeRequested = false;
      if (resume && !_disposed && _foreground && _camera == null) {
        unawaited(_start());
      }
    }
  }

  Future<void> _stop() {
    _generation++;
    final camera = _camera;
    _camera = null;
    _scan.reset();
    final previous = _shutdown;
    final stopping = () async {
      await previous;
      if (camera != null) {
        try {
          if (camera.value.isStreamingImages) await camera.stopImageStream();
        } on CameraException {
          /* Camera may already have been closed by the OS. */
        }
        await _pendingFrame;
        await camera.dispose();
      }
    }();
    _shutdown = stopping;
    return stopping;
  }

  Future<void> _detect(
    CameraImage frame,
    CameraDescription camera,
    int generation,
  ) async {
    try {
      final rotation = InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      );
      if (rotation == null) throw StateError('Orientación no soportada');
      final format = Platform.isIOS
          ? InputImageFormat.bgra8888
          : InputImageFormat.nv21;
      final bytes = Platform.isIOS ? frame.planes.first.bytes : _nv21(frame);
      final input = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
      final poses = await _detector.processImage(input);
      if (!mounted || generation != _generation) return;
      BodyAnchors? body;
      // Multiple bodies are ambiguous: ask for one person instead of switching identities.
      if (poses.length == 1) {
        final pose = poses.single;
        Offset? point(PoseLandmarkType type) {
          final p = pose.landmarks[type];
          if (p == null || p.likelihood < .75) return null;
          final quarter =
              camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
          final width = Platform.isAndroid && quarter
              ? frame.height
              : frame.width;
          final height = Platform.isAndroid && quarter
              ? frame.width
              : frame.height;
          var x = p.x / width;
          // Native pose coordinates match the portrait preview, including front-camera mirroring.
          if (camera.sensorOrientation == 270 ||
              (!quarter && camera.lensDirection == CameraLensDirection.front)) {
            x = 1 - x;
          }
          return Offset(x, p.y / height);
        }

        final ls = point(PoseLandmarkType.leftShoulder),
            rs = point(PoseLandmarkType.rightShoulder);
        final lh = point(PoseLandmarkType.leftHip),
            rh = point(PoseLandmarkType.rightHip);
        if (ls != null && rs != null && lh != null && rh != null) {
          body = BodyAnchors(ls, rs, lh, rh);
        }
      }
      _lastDetection = DateTime.now();
      setState(() {
        _error = null;
        _scan.update(body);
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _scan.reset();
          _error =
              'No se pudo analizar la cámara. Cambia de cámara o reintenta.';
        });
      }
    }
  }

  /// CameraX may expose YUV planes even when NV21 was requested. Respect strides.
  Uint8List _nv21(CameraImage image) {
    if (image.planes.length == 1 &&
        image.format.group == ImageFormatGroup.nv21) {
      return image.planes.single.bytes;
    }
    if (image.planes.length != 3 || image.width.isOdd || image.height.isOdd) {
      throw StateError('Formato de cámara no compatible');
    }
    final w = image.width, h = image.height;
    final bytes = Uint8List(w * h * 3 ~/ 2);
    final y = image.planes[0], u = image.planes[1], v = image.planes[2];
    for (var row = 0; row < h; row++) {
      for (var col = 0; col < w; col++) {
        bytes[row * w + col] =
            y.bytes[row * y.bytesPerRow + col * (y.bytesPerPixel ?? 1)];
      }
    }
    var at = w * h;
    for (var row = 0; row < h ~/ 2; row++) {
      for (var col = 0; col < w ~/ 2; col++) {
        bytes[at++] =
            v.bytes[row * v.bytesPerRow + col * (v.bytesPerPixel ?? 1)];
        bytes[at++] =
            u.bytes[row * u.bytesPerRow + col * (u.bytesPerPixel ?? 1)];
      }
    }
    return bytes;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _foreground = false;
      _shutdown = _stop();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _stop().then((_) => _detector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Prueba corporal'),
        actions: [
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.flip_camera_android_outlined),
            onPressed: _starting
                ? null
                : () async {
                    _shutdown = _stop();
                    await _shutdown;
                    _front = !_front;
                    await _start();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  Text(
                    _scan.ready
                        ? 'Prenda siguiendo tu cuerpo'
                        : 'Encuadra hombros y caderas',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Una persona, de frente y con buena luz. Apoya el móvil y aléjate para entrar en el encuadre.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: camera?.value.isInitialized == true
                    ? AspectRatio(
                        aspectRatio:
                            camera!.value.previewSize!.height /
                            camera.value.previewSize!.width,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: CameraPreview(
                            camera,
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: DemoGarmentPainter(
                                  _scan.ready ? _scan.anchors : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.accessibility_new_rounded,
                        size: 100,
                        color: AppColors.ink,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  if (_error != null)
                    TextButton(
                      onPressed: _starting
                          ? null
                          : () async {
                              _shutdown = _stop();
                              await _shutdown;
                              await _start();
                            },
                      child: const Text('Reintentar cámara'),
                    ),
                  AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _scan.ready ? AppColors.lime : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _scan.ready
                              ? Icons.check_circle_outline
                              : Icons.center_focus_strong,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _scan.ready
                                ? 'Polera Studio · prueba AR'
                                : 'Escaneando postura · mantente de frente',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Prenda de demostración, no a la venta. Seguimiento 2D: no calcula tallas, profundidad ni oclusión. Las imágenes se procesan en tu teléfono.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
