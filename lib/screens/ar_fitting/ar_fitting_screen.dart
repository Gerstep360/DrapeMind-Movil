import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';

class ArFittingScreen extends StatefulWidget {
  final Product product;
  final ProductVariant? initialVariant;

  const ArFittingScreen({
    super.key,
    required this.product,
    this.initialVariant,
  });

  @override
  State<ArFittingScreen> createState() => _ArFittingScreenState();
}

class _ArFittingScreenState extends State<ArFittingScreen> with SingleTickerProviderStateMixin {
  final _arService = ArService();
  final _reservationService = ReservationService();

  ArConfigModel? _arConfig;
  bool _isLoading = true;
  String? _errorMessage;

  // Estado del Probador
  bool _isCameraMode = false;
  bool _isCameraStarting = false;
  CameraController? _cameraController;
  String? _cameraError;
  bool _isCompareMode = false;
  late String _selectedSize;
  String _compareSize = 'L';

  // Medidas antropométricas del usuario
  double _userHeight = 175.0; // cm
  double _userChest = 96.0; // cm
  double _userWaist = 82.0; // cm

  // Animación de respiración / pose
  late AnimationController _animCtrl;
  late Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.initialVariant?.talla ?? 'M';

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _breathAnim = Tween<double>(begin: 0.99, end: 1.015).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    _loadArConfig();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleCameraMode() async {
    if (_isCameraMode) {
      setState(() => _isCameraMode = false);
      return;
    }
    if (_cameraController?.value.isInitialized == true) {
      setState(() => _isCameraMode = true);
      return;
    }
    setState(() {
      _isCameraStarting = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no-camera', 'No se detectó una cámara disponible');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _cameraController?.dispose();
      setState(() {
        _cameraController = controller;
        _isCameraMode = true;
        _isCameraStarting = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.description ?? 'No se pudo iniciar la cámara';
        _isCameraMode = false;
        _isCameraStarting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(_cameraError!),
        ),
      );
    }
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    if (_isCameraStarting || controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Color(0xFF1E2421),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.acid),
        ),
      );
    }
    final preview = controller.value.previewSize;
    if (preview == null) return CameraPreview(controller);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: preview.height,
            height: preview.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Future<void> _loadArConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final config = await _arService.getTryOnConfig(
        widget.product.id,
        userChest: _userChest,
        userWaist: _userWaist,
        userHeight: _userHeight,
      );
      _applyConfig(config);
    } catch (_) {
      // Fallback dimensional de alta precisión local para máxima disponibilidad
      final fallback = _buildLocalArConfig();
      _applyConfig(fallback);
    }
  }

  void _applyConfig(ArConfigModel config) {
    if (!mounted) return;
    setState(() {
      _arConfig = config;
      if (!config.availableSizes.contains(_selectedSize) && config.availableSizes.isNotEmpty) {
        _selectedSize = config.recommendedSize ?? config.availableSizes.first;
      }
      if (config.availableSizes.length > 1) {
        _compareSize = config.availableSizes.firstWhere(
          (s) => s != _selectedSize,
          orElse: () => config.availableSizes.last,
        );
      }
      _isLoading = false;
    });
  }

  ArConfigModel _buildLocalArConfig() {
    final sizes = widget.product.variantes
        .where((v) => v.activo && v.talla.isNotEmpty)
        .map((v) => v.talla)
        .toSet()
        .toList();
    final available = sizes.isNotEmpty ? sizes : ['XS', 'S', 'M', 'L', 'XL'];

    final name = widget.product.nombre.toLowerCase();
    final isBottom = name.contains('pantalon') ||
        name.contains('pantalón') ||
        name.contains('jean') ||
        name.contains('falda') ||
        name.contains('palazzo');

    final metrics = <String, SizeDimensionMetric>{
      'XS': SizeDimensionMetric(chest: 90, shoulders: 42, length: isBottom ? 96 : 68, waist: 74, hip: 90, foot: 24),
      'S': SizeDimensionMetric(chest: 96, shoulders: 44, length: isBottom ? 98 : 70, waist: 80, hip: 96, foot: 25),
      'M': SizeDimensionMetric(chest: 102, shoulders: 46, length: isBottom ? 100 : 72, waist: 86, hip: 102, foot: 26.5),
      'L': SizeDimensionMetric(chest: 108, shoulders: 48, length: isBottom ? 102 : 74, waist: 92, hip: 108, foot: 27.5),
      'XL': SizeDimensionMetric(chest: 114, shoulders: 50, length: isBottom ? 104 : 76, waist: 98, hip: 114, foot: 28.5),
      'XXL': SizeDimensionMetric(chest: 120, shoulders: 52, length: isBottom ? 106 : 78, waist: 104, hip: 120, foot: 29.5),
      '28': SizeDimensionMetric(chest: 92, shoulders: 42, length: 98, waist: 72, hip: 88, foot: 24),
      '30': SizeDimensionMetric(chest: 96, shoulders: 44, length: 100, waist: 76, hip: 92, foot: 25),
      '32': SizeDimensionMetric(chest: 102, shoulders: 46, length: 102, waist: 82, hip: 98, foot: 26.5),
      '34': SizeDimensionMetric(chest: 108, shoulders: 48, length: 104, waist: 88, hip: 104, foot: 27.5),
      '36': SizeDimensionMetric(chest: 114, shoulders: 50, length: 106, waist: 94, hip: 110, foot: 28.5),
    };

    // Determinar recomendación inicial
    String rec = 'M';
    if (isBottom) {
      if (_userWaist <= 76) {
        rec = available.contains('S') ? 'S' : (available.contains('30') ? '30' : available.first);
      } else if (_userWaist <= 86) {
        rec = available.contains('M') ? 'M' : (available.contains('32') ? '32' : available.first);
      } else if (_userWaist <= 94) {
        rec = available.contains('L') ? 'L' : (available.contains('34') ? '34' : available.first);
      } else {
        rec = available.contains('XL') ? 'XL' : (available.contains('36') ? '36' : available.last);
      }
    } else {
      if (_userChest <= 92) {
        rec = available.contains('S') ? 'S' : available.first;
      } else if (_userChest <= 102) {
        rec = available.contains('M') ? 'M' : available.first;
      } else if (_userChest <= 110) {
        rec = available.contains('L') ? 'L' : available.first;
      } else {
        rec = available.contains('XL') ? 'XL' : available.last;
      }
    }

    return ArConfigModel(
      productoId: widget.product.id,
      supported: true,
      mode: '2d-overlay',
      assetUrl: widget.product.mainImageUrl,
      instructions: 'Alinea tus hombros y torso con la guía biomecánica.',
      sizeMetrics: metrics,
      fabricElasticity: 0.06,
      fitCategory: 'regular',
      availableSizes: available,
      recommendedSize: rec,
      material: widget.product.material ?? 'Tejido Atelier',
    );
  }

  // --- CÁLCULO DE AJUSTE / HOLGURA (FIT SCORE) ---
  Map<String, dynamic> _calculateFit(String size) {
    if (_arConfig == null) {
      return {'type': 'IDEAL', 'ease': 4.0, 'label': 'Ajuste Sastrero Ideal', 'color': AppColors.forest};
    }

    final metrics = _arConfig!.sizeMetrics[size] ??
        SizeDimensionMetric(chest: 100, shoulders: 45, length: 70, waist: 84, hip: 100, foot: 26);

    final isBottom = widget.product.nombre.toLowerCase().contains('pantalon') ||
        widget.product.nombre.toLowerCase().contains('jean') ||
        widget.product.nombre.toLowerCase().contains('falda');

    final ease = isBottom ? (metrics.waist - _userWaist) : (metrics.chest - _userChest);

    if (ease < 0.5) {
      return {
        'type': 'SLIM',
        'ease': ease,
        'label': 'Ajuste Ceñido / Slim Fit',
        'color': AppColors.warning,
        'desc': 'Tensión ligera en costuras (${ease.toStringAsFixed(1)} cm de holgura).',
      };
    } else if (ease <= 5.5) {
      return {
        'type': 'IDEAL',
        'ease': ease,
        'label': 'Ajuste Sastrero Ideal',
        'color': AppColors.forest,
        'desc': 'Caída limpia y libertad de movimiento (+${ease.toStringAsFixed(1)} cm).',
      };
    } else {
      return {
        'type': 'OVERSIZE',
        'ease': ease,
        'label': 'Caída Holgada / Oversize',
        'color': AppColors.forestDark,
        'desc': 'Silueta drapeada y moderna (+${ease.toStringAsFixed(1)} cm de holgura).',
      };
    }
  }

  void _addToCartSelectedSize() async {
    final cart = context.read<CartService>();

    final variant = widget.product.variantes.firstWhere(
      (v) => v.talla.toUpperCase() == _selectedSize.toUpperCase() && v.activo && v.stockDisponible > 0,
      orElse: () => widget.product.variantes.first,
    );

    try {
      await cart.addItem(variant.id, cantidad: 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forest,
            content: Text(
              '${widget.product.nombre} (Talla $_selectedSize) agregada al perchero',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('No se pudo agregar al perchero.'),
          ),
        );
      }
    }
  }

  void _createReservationSelectedSize() async {
    final variant = widget.product.variantes.firstWhere(
      (v) => v.talla.toUpperCase() == _selectedSize.toUpperCase() && v.activo,
      orElse: () => widget.product.variantes.first,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paperLight,
        title: Row(
          children: [
            AppSvg.raw(AppSvg.clock, size: 20, color: AppColors.forest),
            const SizedBox(width: 8),
            const Text('Reservar en Showroom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          '¿Deseas reservar ${widget.product.nombre} en Talla $_selectedSize por 48 horas para probártela en tienda física?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Reserva 48h'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _reservationService.createReservation(
          varianteId: variant.id,
          observacion: 'Prueba AR Talla $_selectedSize - ${widget.product.nombre}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.forest,
              content: Text('Reserva confirmada. Código: ${res.codigoPublico}'),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('No se pudo crear la reserva.'),
            ),
          );
        }
      }
    }
  }

  // --- MODAL DE CONSULTA A ALTAIR EN VIVO DENTRO DEL PROBADOR AR ---
  void _showAltairArConsultModal() {
    final ai = context.read<AiSocketService>();
    final fitData = _calculateFit(_selectedSize);
    final metric = _arConfig?.sizeMetrics[_selectedSize];
    final TextEditingController promptController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer<AiSocketService>(
              builder: (context, aiService, _) {
                final lastAssistantMsg = aiService.messages.lastWhere(
                  (m) => m.isAssistant,
                  orElse: () => ChatMessage(
                    id: 'ar-init',
                    role: 'assistant',
                    content:
                        'Saludos. Estoy analizando ${widget.product.nombre} en Talla $_selectedSize. '
                        'Con tus medidas (${_userChest.toInt()} cm de pecho), esta prenda tiene una holgura de ${(fitData['ease'] as double).toStringAsFixed(1)} cm (${fitData['label']}). '
                        '¿Deseas que evalúe cómo combinarla o compararla con otra talla?',
                  ),
                );

                return Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Altair
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              AppSvg.raw(AppSvg.sparkle, size: 18, color: AppColors.acid),
                              const SizedBox(width: 8),
                              const Text(
                                'ALTAIR · ASESORÍA DE CALCE AR',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: AppColors.forest,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: AppSvg.raw(AppSvg.close, size: 18, color: AppColors.textMuted),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Prenda: ${widget.product.nombre} (Talla $_selectedSize) · ${_arConfig?.material ?? "Atelier"}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMutedStrong),
                      ),
                      const SizedBox(height: 12),

                      // Respuesta de Altair o Estado de Razonamiento
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.lineStrong),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (aiService.isBusy)
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      aiService.currentThought ?? 'Altair evaluando calce...',
                                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.forest),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                lastAssistantMsg.content,
                                style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textMain),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // CHIPS DE CONSULTA RÁPIDA (100% SVG, 0 EMOJIS)
                      const Text(
                        'PREGUNTAS SUGERIDAS PARA ESTA PRENDA',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildArPromptChip(
                            label: '¿Cómo combinar esta prenda?',
                            prompt: '¿Con qué prendas del atelier combina mejor ${widget.product.nombre} en tono ${widget.initialVariant?.color ?? "neutro"}?',
                            ai: ai,
                          ),
                          _buildArPromptChip(
                            label: 'Comparar Talla $_selectedSize vs $_compareSize',
                            prompt: 'Compara el ajuste de ${widget.product.nombre} en Talla $_selectedSize (${metric?.chest.toInt()}cm pecho) vs Talla $_compareSize para mis ${_userChest.toInt()}cm de pecho.',
                            ai: ai,
                          ),
                          _buildArPromptChip(
                            label: 'Analizar tela y caída',
                            prompt: 'Explica la calidad, caída y durabilidad del material ${widget.product.material ?? "textil"} de esta prenda.',
                            ai: ai,
                          ),
                          _buildArPromptChip(
                            label: 'Calce para estatura ${_userHeight.toInt()}cm',
                            prompt: 'Para una estatura de ${_userHeight.toInt()}cm y pecho ${_userChest.toInt()}cm, ¿la talla $_selectedSize queda equilibrada en largo?',
                            ai: ai,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // INPUT MANUAL DE CONSULTA
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: promptController,
                              decoration: InputDecoration(
                                hintText: 'Pregunta a Altair sobre el calce o estilo...',
                                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: AppColors.lineStrong),
                                ),
                              ),
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  ai.sendMessage('En el probador AR de ${widget.product.nombre} (Talla $_selectedSize): $text');
                                  promptController.clear();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forest,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              final text = promptController.text.trim();
                              if (text.isNotEmpty) {
                                ai.sendMessage('En el probador AR de ${widget.product.nombre} (Talla $_selectedSize): $text');
                                promptController.clear();
                              }
                            },
                            child: AppSvg.raw(AppSvg.send, size: 16, color: AppColors.acid),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildArPromptChip({
    required String label,
    required String prompt,
    required AiSocketService ai,
  }) {
    return InkWell(
      onTap: () {
        ai.sendMessage(prompt);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.paperLight,
          border: Border.all(color: AppColors.forest.withAlpha(80)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSvg.raw(AppSvg.sparkle, size: 11, color: AppColors.forest),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL DE AJUSTE DE MEDIDAS DEL USUARIO ---
  void _showMeasurementsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          AppSvg.raw(AppSvg.sparkle, size: 18, color: AppColors.forest),
                          const SizedBox(width: 8),
                          const Text(
                            'CALIBRAR MEDIDAS CORPORALES',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: AppColors.forest),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: AppSvg.raw(AppSvg.close, size: 18, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ESTATURA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estatura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('${_userHeight.toInt()} cm', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.forest)),
                    ],
                  ),
                  Slider(
                    value: _userHeight,
                    min: 150,
                    max: 205,
                    activeColor: AppColors.forest,
                    onChanged: (v) {
                      setModalState(() => _userHeight = v);
                      setState(() => _userHeight = v);
                    },
                  ),

                  // PECHO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Contorno de Pecho', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('${_userChest.toInt()} cm', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.forest)),
                    ],
                  ),
                  Slider(
                    value: _userChest,
                    min: 75,
                    max: 130,
                    activeColor: AppColors.forest,
                    onChanged: (v) {
                      setModalState(() => _userChest = v);
                      setState(() => _userChest = v);
                    },
                  ),

                  // CINTURA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Contorno de Cintura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('${_userWaist.toInt()} cm', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.forest)),
                    ],
                  ),
                  Slider(
                    value: _userWaist,
                    min: 60,
                    max: 125,
                    activeColor: AppColors.forest,
                    onChanged: (v) {
                      setModalState(() => _userWaist = v);
                      setState(() => _userWaist = v);
                    },
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
                      onPressed: () {
                        Navigator.pop(context);
                        _loadArConfig();
                      },
                      child: const Text('Aplicar Calibración Biomecánica'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableSizes = _arConfig?.availableSizes ?? ['S', 'M', 'L', 'XL'];
    final fitData = _calculateFit(_selectedSize);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROBADOR AR · ${widget.product.nombre.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
            Text(
              'Bs ${widget.product.precio.toStringAsFixed(2)} · ${widget.product.material ?? "Alta Costura"}',
              style: const TextStyle(fontSize: 11, color: AppColors.acid, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          // Botón Altair Asesoría IA
          IconButton(
            icon: AppSvg.raw(AppSvg.sparkle, size: 18, color: AppColors.acid),
            tooltip: 'Altair Asesoría IA',
            onPressed: _showAltairArConsultModal,
          ),
          // Calibrar medidas
          IconButton(
            icon: AppSvg.raw(AppSvg.filter, size: 18, color: AppColors.white),
            tooltip: 'Calibrar Medidas',
            onPressed: _showMeasurementsDialog,
          ),
          // Modo Cámara / Maniquí
          IconButton(
            icon: AppSvg.raw(_isCameraMode ? AppSvg.user : AppSvg.sparkle, size: 18, color: AppColors.white),
            tooltip: _isCameraMode ? 'Modo Maniquí' : 'Modo Espejo AR',
            onPressed: _toggleCameraMode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)))
              : Column(
                  children: [
                    // SUB-BARRA DE ESTADO Y COMPARADOR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        border: Border(bottom: BorderSide(color: AppColors.lineStrong)),
                      ),
                      child: Row(
                        children: [
                          // Badge de Calce
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (fitData['color'] as Color).withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: fitData['color'] as Color),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: fitData['color'] as Color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  fitData['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: fitData['color'] as Color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Toggle Comparador de 2 Tallas
                          InkWell(
                            onTap: () => setState(() => _isCompareMode = !_isCompareMode),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isCompareMode ? AppColors.forest : AppColors.paperLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.forest),
                              ),
                              child: Text(
                                _isCompareMode ? 'Vista Simple' : 'Comparar 2 Tallas',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _isCompareMode ? AppColors.white : AppColors.forest,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // FLOATING ALTAIR LIVE STYLIST BADGE
                    InkWell(
                      onTap: _showAltairArConsultModal,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.forestDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.acid.withAlpha(90)),
                        ),
                        child: Row(
                          children: [
                            AppSvg.raw(AppSvg.sparkle, size: 15, color: AppColors.acid),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Altair: Talla $_selectedSize (${(fitData['ease'] as double).toStringAsFixed(1)}cm holgura). Toca para asesoría y combinaciones en vivo.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppSvg.raw(AppSvg.arrowRight, size: 12, color: AppColors.acid),
                          ],
                        ),
                      ),
                    ),

                    // LIENZO DE RENDER / AR CANVAS
                    Expanded(
                      child: _isCompareMode
                          ? _buildCompareCanvas(availableSizes)
                          : _buildSingleFittingCanvas(_selectedSize, fitData),
                    ),

                    // PANEL INFERIOR DE CONTROLES Y TALLAS
                    _buildBottomControls(availableSizes, fitData),
                  ],
                ),
    );
  }

  // --- LIENZO INDIVIDUAL DEL PROBADOR ---
  Widget _buildSingleFittingCanvas(String size, Map<String, dynamic> fitData) {
    final metric = _arConfig?.sizeMetrics[size] ??
        SizeDimensionMetric(chest: 100, shoulders: 45, length: 70, waist: 84, hip: 100, foot: 26);

    final chestRatio = (metric.chest / _userChest).clamp(0.85, 1.25);
    final shoulderRatio = (metric.shoulders / 45.0).clamp(0.85, 1.20);
    final lengthRatio = (metric.length / 70.0).clamp(0.90, 1.20);

    return AnimatedBuilder(
      animation: _breathAnim,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isCameraMode ? const Color(0xFF1E2421) : AppColors.paperLight,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // FONDO O GUÍA DE CÁMARA
              if (_isCameraMode)
                Positioned.fill(
                  child: _buildCameraPreview(),
                ),

              // SILUETA ANATOMICA DEL MANIQUÍ (BASE)
              if (!_isCameraMode)
                Transform.scale(
                  scale: _breathAnim.value,
                  child: CustomPaint(
                    size: const Size(260, 390),
                    painter: _MannequinPainter(
                      userHeight: _userHeight,
                      userChest: _userChest,
                      userWaist: _userWaist,
                      isCameraMode: false,
                    ),
                  ),
                ),

              if (_isCameraMode)
                IgnorePointer(
                  child: Container(
                    width: 230,
                    height: 390,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.acid.withAlpha(150),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(115),
                    ),
                  ),
                ),

              // SUPERPOSICIÓN DE LA PRENDA CON ESCALA DINÁMICA POR TALLA
              Transform.scale(
                scale: _breathAnim.value,
                child: SizedBox(
                  width: 210 * chestRatio * shoulderRatio,
                  height: 250 * lengthRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Render del Asset de la Prenda
                      if (_arConfig?.assetUrl != null)
                        Image.network(
                          _arConfig!.fullAssetUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildFallbackGarmentVector(size),
                        )
                      else
                        _buildFallbackGarmentVector(size),

                      // Mapa de Tensión / Holgura (Heatmap Contour)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GarmentTensionPainter(
                            ease: fitData['ease'] as double,
                            color: fitData['color'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // HUD FLOTANTE CON MEDIDAS EN VIVO
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.forestDark.withAlpha(230),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.acid.withAlpha(90)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Talla $size · Pecho: ${metric.chest.toInt()} cm · Largo: ${metric.length.toInt()} cm',
                            style: const TextStyle(color: AppColors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            fitData['desc'] as String,
                            style: const TextStyle(color: AppColors.acid, fontSize: 10.5),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Holgura ${(fitData['ease'] as double).toStringAsFixed(1)}cm',
                          style: const TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- COMPARADOR SPLIT VIEW DE 2 TALLAS ---
  Widget _buildCompareCanvas(List<String> availableSizes) {
    final fitA = _calculateFit(_selectedSize);
    final fitB = _calculateFit(_compareSize);

    return Column(
      children: [
        // Selectores de Comparación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: AppColors.white,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Talla A: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    DropdownButton<String>(
                      value: _selectedSize,
                      isDense: true,
                      items: availableSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _selectedSize = v!),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Talla B: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    DropdownButton<String>(
                      value: _compareSize,
                      isDense: true,
                      items: availableSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _compareSize = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Comparativa lado a lado
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.lineStrong)),
                  ),
                  child: _buildSingleFittingCanvas(_selectedSize, fitA),
                ),
              ),
              Expanded(
                child: _buildSingleFittingCanvas(_compareSize, fitB),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackGarmentVector(String size) {
    return Center(
      child: AppSvg.raw(
        AppSvg.tshirt,
        size: 140,
        color: AppColors.forest.withAlpha(200),
      ),
    );
  }

  // --- PANEL INFERIOR DE ACCIONES Y SELECTOR DE TALLAS ---
  Widget _buildBottomControls(List<String> availableSizes, Map<String, dynamic> fitData) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SELECTOR DE TALLA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SELECCIONAR TALLA PARA PROBAR',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                if (_arConfig?.recommendedSize != null)
                  Text(
                    'Recomendada: ${_arConfig!.recommendedSize}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.forest, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableSizes.map((s) {
                  final isSelected = _selectedSize == s;
                  final isRec = _arConfig?.recommendedSize == s;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? AppColors.white : AppColors.forest,
                            ),
                          ),
                          if (isRec) ...[
                            const SizedBox(width: 4),
                            AppSvg.raw(AppSvg.sparkle, size: 10, color: isSelected ? AppColors.acid : AppColors.forest),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.forest,
                      backgroundColor: AppColors.white,
                      side: BorderSide(
                        color: isSelected ? AppColors.forest : (isRec ? AppColors.acid : AppColors.lineStrong),
                        width: isRec ? 1.5 : 1,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedSize = s);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // BOTONES DE ACCIÓN
            Row(
              children: [
                // Reservar 48h
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.forest, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _createReservationSelectedSize,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppSvg.raw(AppSvg.clock, size: 14, color: AppColors.forest),
                        const SizedBox(width: 6),
                        const Text(
                          'Reservar 48h',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forest),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Agregar al Perchero
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _addToCartSelectedSize,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppSvg.raw(AppSvg.plus, size: 14, color: AppColors.acid),
                        const SizedBox(width: 6),
                        Text(
                          'Añadir Talla $_selectedSize al Perchero',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAINTER DE SILUETA / MANIQUÍ VECTORIAL ---
class _MannequinPainter extends CustomPainter {
  final double userHeight;
  final double userChest;
  final double userWaist;
  final bool isCameraMode;

  _MannequinPainter({
    required this.userHeight,
    required this.userChest,
    required this.userWaist,
    required this.isCameraMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isCameraMode ? Colors.white.withAlpha(60) : const Color(0xFFD6CEBE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final fillPaint = Paint()
      ..color = isCameraMode ? Colors.black.withAlpha(40) : const Color(0xFFEFECE4).withAlpha(180)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path();
    // Cabeza
    path.addOval(Rect.fromCenter(center: Offset(cx, cy - 130), width: 34, height: 46));

    // Cuello
    path.moveTo(cx - 10, cy - 107);
    path.lineTo(cx - 10, cy - 90);
    path.lineTo(cx + 10, cy - 90);
    path.lineTo(cx + 10, cy - 107);

    // Hombros y Torso ajustables antropométricamente
    final shoulderW = 48.0 * (userChest / 96.0);
    final waistW = 36.0 * (userWaist / 82.0);

    path.moveTo(cx - shoulderW, cy - 75);
    path.quadraticBezierTo(cx, cy - 85, cx + shoulderW, cy - 75); // Hombros
    path.lineTo(cx + shoulderW + 6, cy - 20); // Axila / Pecho
    path.quadraticBezierTo(cx + waistW, cy + 40, cx + waistW + 4, cy + 90); // Cintura y Cadera
    path.lineTo(cx - waistW - 4, cy + 90);
    path.quadraticBezierTo(cx - waistW, cy + 40, cx - shoulderW - 6, cy - 20);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Líneas guía sastreras
    final guidePaint = Paint()
      ..color = isCameraMode ? AppColors.acid.withAlpha(80) : AppColors.forest.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Línea de Pecho
    canvas.drawLine(Offset(cx - shoulderW - 10, cy - 25), Offset(cx + shoulderW + 10, cy - 25), guidePaint);
    // Línea de Cintura
    canvas.drawLine(Offset(cx - waistW - 8, cy + 45), Offset(cx + waistW + 8, cy + 45), guidePaint);
  }

  @override
  bool shouldRepaint(covariant _MannequinPainter oldDelegate) {
    return oldDelegate.userChest != userChest ||
        oldDelegate.userWaist != userWaist ||
        oldDelegate.isCameraMode != isCameraMode;
  }
}

// --- PAINTER DE CONTORNO DE TENSIÓN TEXTIL ---
class _GarmentTensionPainter extends CustomPainter {
  final double ease;
  final Color color;

  _GarmentTensionPainter({required this.ease, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final tensionPaint = Paint()
      ..color = color.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), tensionPaint);
  }

  @override
  bool shouldRepaint(covariant _GarmentTensionPainter oldDelegate) {
    return oldDelegate.ease != ease || oldDelegate.color != color;
  }
}
