import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/navegacion/main_shell.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/registrar_cliente/dominio/onboarding_options.dart';
import 'package:drapemind_mobile/paquetes/sucursales_inventario_proveedores/datos/servicios/preferred_branch_store.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isReconfiguring;

  const OnboardingScreen({super.key, this.isReconfiguring = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _branchService = BranchService();
  final _preferredBranchStore = PreferredBranchStore();

  // Design Tokens (DrapeMind Luxury Atelier)
  static const Color dmBg = Color(0xFFF4F5EA);
  static const Color dmSurface = Color(0xFFFFFFFF);
  static const Color dmInk = Color(0xFF10110F);
  static const Color dmLime = Color(0xFFDFFF3F);
  static const Color dmCyan = Color(0xFFC9EEF0);
  static const Color dmBorder = Color(0xFFE1E3DA);
  static const Color dmTextMuted = Color(0xFF606659);

  // Flow State
  int _currentStep =
      0; // 0: Sucursal, 1: Estilo, 2: Medidas, 3: Detalles, 4: Reveal
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Options & Catalogs
  List<Branch> _branches = [];
  int? _selectedBranchId;

  String? _selectedGender;
  final List<String> _selectedStyles = [];
  String? _selectedSilhouette;

  String? _selectedTopSize;
  String? _selectedBottomSize;
  String? _selectedShoeSize;

  final List<String> _selectedColors = [];
  String? _selectedOccasion;
  double? _selectedBudget;

  final _customTopController = TextEditingController();
  final _customBottomController = TextEditingController();
  final _customShoeController = TextEditingController();
  final _customOccasionController = TextEditingController();

  bool _isCustomTop = false;
  bool _isCustomBottom = false;
  bool _isCustomShoe = false;

  final _genderOptions = OnboardingOptions.genders;
  final _styleOptions = OnboardingOptions.styles;
  final _topSizes = OnboardingOptions.topSizes;
  final _bottomSizes = OnboardingOptions.bottomSizes;
  final _shoeSizes = OnboardingOptions.shoeSizes;
  final _silhouetteOptions = OnboardingOptions.silhouettes;
  final _colorOptions = OnboardingOptions.colors;
  final _occasionOptions = OnboardingOptions.occasions;
  final _budgetRanges = OnboardingOptions.budgets;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _customTopController.dispose();
    _customBottomController.dispose();
    _customShoeController.dispose();
    _customOccasionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final branches = await _branchService.getBranches();
      _branches = branches;
      try {
        final savedBranchId = await _preferredBranchStore.read();
        if (savedBranchId != null &&
            _branches.any((b) => b.id == savedBranchId)) {
          _selectedBranchId = savedBranchId;
        } else if (_branches.isNotEmpty && _selectedBranchId == null) {
          _selectedBranchId = _branches.first.id;
        }
      } catch (_) {
        if (_branches.isNotEmpty && _selectedBranchId == null) {
          _selectedBranchId = _branches.first.id;
        }
      }

      if (!mounted) return;
      final profile = await context.read<AuthService>().getStyleProfile();
      if (profile != null) {
        _selectedGender = profile.genero;
        _selectedStyles.clear();
        _selectedStyles.addAll(profile.estilosPreferidos);
        _selectedSilhouette = profile.siluetaPreferida;

        if (profile.tallaSuperior != null &&
            profile.tallaSuperior!.isNotEmpty) {
          if (_topSizes.contains(profile.tallaSuperior)) {
            _selectedTopSize = profile.tallaSuperior;
            _isCustomTop = false;
          } else {
            _isCustomTop = true;
            _customTopController.text = profile.tallaSuperior!;
            _selectedTopSize = profile.tallaSuperior;
          }
        }

        if (profile.tallaInferior != null &&
            profile.tallaInferior!.isNotEmpty) {
          if (_bottomSizes.contains(profile.tallaInferior)) {
            _selectedBottomSize = profile.tallaInferior;
            _isCustomBottom = false;
          } else {
            _isCustomBottom = true;
            _customBottomController.text = profile.tallaInferior!;
            _selectedBottomSize = profile.tallaInferior;
          }
        }

        if (profile.tallaCalzado != null && profile.tallaCalzado!.isNotEmpty) {
          if (_shoeSizes.contains(profile.tallaCalzado)) {
            _selectedShoeSize = profile.tallaCalzado;
            _isCustomShoe = false;
          } else {
            _isCustomShoe = true;
            _customShoeController.text = profile.tallaCalzado!;
            _selectedShoeSize = profile.tallaCalzado;
          }
        }

        _selectedColors.clear();
        _selectedColors.addAll(profile.coloresFavoritos);
        _selectedBudget = profile.presupuestoHabitual;

        if (profile.ocasionesFrecuentes.isNotEmpty) {
          final firstOccasion = profile.ocasionesFrecuentes.first;
          final match = _occasionOptions.any((o) => o['id'] == firstOccasion);
          if (match) {
            _selectedOccasion = firstOccasion;
          } else {
            _selectedOccasion = firstOccasion;
            _customOccasionController.text = firstOccasion;
          }
        }
      }
    } catch (e) {
      _errorMessage = 'No se pudieron cargar todos los datos previos.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleStyle(String styleId) {
    setState(() {
      if (_selectedStyles.contains(styleId)) {
        _selectedStyles.remove(styleId);
      } else {
        _selectedStyles.add(styleId);
      }
    });
  }

  void _toggleColor(String colorId) {
    setState(() {
      if (_selectedColors.contains(colorId)) {
        _selectedColors.remove(colorId);
      } else {
        _selectedColors.add(colorId);
      }
    });
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final finalTopSize = _isCustomTop
        ? _customTopController.text.trim()
        : _selectedTopSize;
    final finalBottomSize = _isCustomBottom
        ? _customBottomController.text.trim()
        : _selectedBottomSize;
    final finalShoeSize = _isCustomShoe
        ? _customShoeController.text.trim()
        : _selectedShoeSize;
    final finalOccasion = _customOccasionController.text.trim().isNotEmpty
        ? _customOccasionController.text.trim()
        : _selectedOccasion;

    final profile = StyleProfile(
      genero: _selectedGender,
      estilosPreferidos: _selectedStyles,
      siluetaPreferida: _selectedSilhouette,
      tallaSuperior: finalTopSize?.isNotEmpty == true ? finalTopSize : null,
      tallaInferior: finalBottomSize?.isNotEmpty == true
          ? finalBottomSize
          : null,
      tallaCalzado: finalShoeSize?.isNotEmpty == true ? finalShoeSize : null,
      coloresFavoritos: _selectedColors,
      ocasionesFrecuentes: finalOccasion != null && finalOccasion.isNotEmpty
          ? [finalOccasion]
          : [],
      presupuestoHabitual: _selectedBudget,
      completado: true,
    );

    final auth = context.read<AuthService>();
    if (_selectedBranchId != null) {
      try {
        await _preferredBranchStore.save(_selectedBranchId!);
      } catch (_) {}
    }

    try {
      await auth.saveStyleProfile(profile);

      if (mounted) {
        if (widget.isReconfiguring) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: dmInk,
              content: Text(
                'Preferencias actualizadas en el Atelier.',
                style: TextStyle(color: dmLime, fontWeight: FontWeight.w700),
              ),
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isSaving = false;
            _currentStep = 4; // Reveal step
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage =
              'No se pudieron sincronizar tus preferencias con el servidor. Se guardaron localmente.';
        });
      }
    }
  }

  void _skipOnboarding() {
    context.read<AuthService>().skipOnboarding();
    if (widget.isReconfiguring) {
      Navigator.of(context).pop();
    }
  }

  void _finishAndGoStore() {
    context.read<AuthService>().markStyleProfileCompleted();
    if (widget.isReconfiguring) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  void _goToAiStudio() {
    context.read<AuthService>().markStyleProfileCompleted();
    if (widget.isReconfiguring) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainShell(initialIndex: 1), // AI Studio tab
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dmBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: dmInk))
            : Column(
                children: [
                  _buildHeader(),
                  if (_currentStep < 4) _buildStepIndicator(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.06, 0.0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: SingleChildScrollView(
                        key: ValueKey<int>(_currentStep),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: _buildCurrentStepContent(),
                      ),
                    ),
                  ),
                  if (_currentStep < 4) _buildFooterActions(),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: dmBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Circle Avatar Brand 'D'
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: dmInk,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'D',
                style: TextStyle(
                  color: dmLime,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Brand Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'DrapeMind',
                style: TextStyle(
                  color: dmInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'ATELIER & STUDIO',
                style: TextStyle(
                  color: dmTextMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 8.5,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Action button (Skip or Close)
          if (widget.isReconfiguring)
            IconButton(
              icon: const Icon(Icons.close, color: dmInk, size: 22),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Cerrar sin guardar',
            )
          else if (_currentStep < 4)
            TextButton(
              onPressed: _isSaving ? null : _skipOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: dmTextMuted,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Explorar sin configurar ↗'),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP INDICATOR (ANIMATED PROGRESS & PILLS)
  // ---------------------------------------------------------------------------
  Widget _buildStepIndicator() {
    final steps = [
      {'label': '01 Showroom', 'step': 0},
      {'label': '02 Estilo', 'step': 1},
      {'label': '03 Medidas', 'step': 2},
      {'label': '04 Detalles', 'step': 3},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.25,
                end: ((_currentStep + 1) / 4.0).clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: dmBorder.withValues(alpha: 0.5),
                valueColor: const AlwaysStoppedAnimation<Color>(dmInk),
                minHeight: 3,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.map((s) {
              final stepIndex = s['step'] as int;
              final isCurrent = _currentStep == stepIndex;
              final isPast = _currentStep > stepIndex;

              return GestureDetector(
                onTap: () {
                  if (stepIndex < _currentStep) {
                    setState(() => _currentStep = stepIndex);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? dmLime
                        : (isPast
                              ? dmCyan.withValues(alpha: 0.35)
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCurrent
                          ? Colors.transparent
                          : (isPast ? dmInk : dmBorder),
                      width: 1.1,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: dmLime.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    s['label'] as String,
                    style: TextStyle(
                      color: dmInk,
                      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP CONTENT ROUTER
  // ---------------------------------------------------------------------------
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepBranches();
      case 1:
        return _buildStepStyles();
      case 2:
        return _buildStepSizes();
      case 3:
        return _buildStepDetails();
      case 4:
        return _buildStepReveal();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: SUCURSALES (SHOWROOMS)
  // ---------------------------------------------------------------------------
  Widget _buildStepBranches() {
    return _buildCardWrapper(
      eyebrow: 'CERCA DE TI · SHOWROOMS',
      title: '¿En qué sucursal quieres comprar?',
      description:
          'La disponibilidad y las colecciones varían por sede. Puedes cambiar de showroom en cualquier momento.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_branches.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dmBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Consultando sedes físicas del Atelier...',
                style: TextStyle(color: dmTextMuted, fontSize: 13),
              ),
            )
          else
            ..._branches.map((branch) {
              final isSelected = _selectedBranchId == branch.id;
              return GestureDetector(
                onTap: () async {
                  setState(() => _selectedBranchId = branch.id);
                  try {
                    await _preferredBranchStore.save(branch.id);
                  } catch (_) {}
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? dmLime : dmSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : dmBorder,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: dmLime.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? dmInk : dmBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.storefront_outlined,
                          color: isSelected ? dmLime : dmInk,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              branch.nombre,
                              style: const TextStyle(
                                color: dmInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${branch.direccion} · ${branch.ciudad ?? ''}',
                              style: TextStyle(
                                color: isSelected ? dmInk : dmTextMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: dmInk, size: 22),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: GÉNERO & ESTILOS
  // ---------------------------------------------------------------------------
  Widget _buildStepStyles() {
    return _buildCardWrapper(
      eyebrow: '01 / 03 · ESTILO & CORTE',
      title: '¿Qué te gusta vestir?',
      description:
          'Elige las estéticas que definen tu carácter. Altair sugerirá piezas alineadas con tu estilo.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Busco prendas orientadas a:',
            style: TextStyle(
              color: dmInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderOptions.map((opt) {
              final isSelected = _selectedGender == opt['id'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedGender = selected ? opt['id'] : null);
                },
                backgroundColor: dmSurface,
                selectedColor: dmLime,
                side: BorderSide(
                  color: isSelected ? Colors.transparent : dmBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: TextStyle(
                  color: dmInk,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Estilos y universos favoritos (multiselección):',
            style: TextStyle(
              color: dmInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _styleOptions.map((opt) {
              final isSelected = _selectedStyles.contains(opt['id']);
              return GestureDetector(
                onTap: () => _toggleStyle(opt['id']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? dmLime : dmSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : dmBorder,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: dmLime.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check, color: dmInk, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        opt['id']!,
                        style: TextStyle(
                          color: dmInk,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: MEDIDAS & SILUETA
  // ---------------------------------------------------------------------------
  Widget _buildStepSizes() {
    return _buildCardWrapper(
      eyebrow: '02 / 03 · MEDIDAS & CALCE',
      title: 'Un punto de partida para tu talla.',
      description:
          'Estas tallas sirven de guía inicial para el showroom. Puedes cambiarlas o ingresar valores personalizados.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Talla Superior
          _buildSizeSection(
            label: 'Talla superior (Tops, Blazers, Hoodies):',
            sizes: _topSizes,
            selectedSize: _selectedTopSize,
            isCustom: _isCustomTop,
            customController: _customTopController,
            onSelect: (size) {
              setState(() {
                _isCustomTop = false;
                _selectedTopSize = size;
              });
            },
            onToggleCustom: () {
              setState(() => _isCustomTop = !_isCustomTop);
            },
          ),
          const SizedBox(height: 20),
          // Talla Inferior
          _buildSizeSection(
            label: 'Talla inferior (Pantalones, Faldas, Denim):',
            sizes: _bottomSizes,
            selectedSize: _selectedBottomSize,
            isCustom: _isCustomBottom,
            customController: _customBottomController,
            onSelect: (size) {
              setState(() {
                _isCustomBottom = false;
                _selectedBottomSize = size;
              });
            },
            onToggleCustom: () {
              setState(() => _isCustomBottom = !_isCustomBottom);
            },
          ),
          const SizedBox(height: 20),
          // Calzado
          _buildSizeSection(
            label: 'Talla de calzado (Sneakers, Botines):',
            sizes: _shoeSizes,
            selectedSize: _selectedShoeSize,
            isCustom: _isCustomShoe,
            customController: _customShoeController,
            onSelect: (size) {
              setState(() {
                _isCustomShoe = false;
                _selectedShoeSize = size;
              });
            },
            onToggleCustom: () {
              setState(() => _isCustomShoe = !_isCustomShoe);
            },
          ),
          const SizedBox(height: 24),
          // Silueta
          const Text(
            'Silueta y caída preferida:',
            style: TextStyle(
              color: dmInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _silhouetteOptions.map((fit) {
              final isSelected = _selectedSilhouette == fit;
              return ChoiceChip(
                label: Text(fit),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedSilhouette = selected ? fit : null);
                },
                backgroundColor: dmSurface,
                selectedColor: dmLime,
                side: BorderSide(
                  color: isSelected ? Colors.transparent : dmBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: TextStyle(
                  color: dmInk,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSection({
    required String label,
    required List<String> sizes,
    required String? selectedSize,
    required bool isCustom,
    required TextEditingController customController,
    required Function(String) onSelect,
    required VoidCallback onToggleCustom,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: dmInk,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...sizes.map((s) {
              final isSelected = !isCustom && selectedSize == s;
              return ChoiceChip(
                label: Text(s),
                selected: isSelected,
                onSelected: (_) => onSelect(s),
                backgroundColor: dmSurface,
                selectedColor: dmLime,
                side: BorderSide(
                  color: isSelected ? Colors.transparent : dmBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                labelStyle: TextStyle(
                  color: dmInk,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }),
            ChoiceChip(
              label: Text(isCustom ? 'Personalizada ✓' : 'Otra...'),
              selected: isCustom,
              onSelected: (_) => onToggleCustom(),
              backgroundColor: dmSurface,
              selectedColor: dmCyan,
              side: BorderSide(color: isCustom ? Colors.transparent : dmBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              labelStyle: TextStyle(
                color: dmInk,
                fontWeight: isCustom ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (isCustom) ...[
          const SizedBox(height: 8),
          TextField(
            controller: customController,
            decoration: InputDecoration(
              hintText: 'Ingresa tu medida o talla libre (ej. 31/32 o Custom)',
              filled: true,
              fillColor: dmSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: dmBorder),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 4: PALETAS, OCASIÓN & PRESUPUESTO
  // ---------------------------------------------------------------------------
  Widget _buildStepDetails() {
    return _buildCardWrapper(
      eyebrow: '03 / 03 · DETALLES & PRESUPUESTO',
      title: 'Los detalles hacen el look.',
      description:
          'Completa los toques finales. Altair filtrará recomendaciones dentro de tus rangos favoritos.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paletas de color
          const Text(
            'Paletas y armonías favoritas (multiselección):',
            style: TextStyle(
              color: dmInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: _colorOptions.map((palette) {
              final isSelected = _selectedColors.contains(palette['id']);
              return GestureDetector(
                onTap: () => _toggleColor(palette['id']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? dmLime : dmSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : dmBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _colorFromHex(palette['colorHex']!),
                          shape: BoxShape.circle,
                          border: Border.all(color: dmBorder, width: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              palette['id']!,
                              style: const TextStyle(
                                color: dmInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              palette['desc']!,
                              style: TextStyle(
                                color: isSelected ? dmInk : dmTextMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: dmInk, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Ocasión habitual
          const Text(
            'Ocasión habitual:',
            style: TextStyle(
              color: dmInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _occasionOptions.map((occ) {
              final isSelected = _selectedOccasion == occ['id'];
              return ChoiceChip(
                label: Text(occ['id']!),
                selected: isSelected,
                onSelected: (selected) {
                  setState(
                    () => _selectedOccasion = selected ? occ['id'] : null,
                  );
                },
                backgroundColor: dmSurface,
                selectedColor: dmLime,
                side: BorderSide(
                  color: isSelected ? Colors.transparent : dmBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                labelStyle: TextStyle(
                  color: dmInk,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Presupuesto habitual
          const Text(
            'Presupuesto habitual de compra (Bs):',
            style: TextStyle(
              color: dmInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _budgetRanges.map((b) {
              final isSelected = _selectedBudget == b['value'];
              return ChoiceChip(
                label: Text('${b['label']} (${b['range']})'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(
                    () => _selectedBudget = selected
                        ? b['value'] as double
                        : null,
                  );
                },
                backgroundColor: dmSurface,
                selectedColor: dmLime,
                side: BorderSide(
                  color: isSelected ? Colors.transparent : dmBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                labelStyle: TextStyle(
                  color: dmInk,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 5: REVEAL / READY
  // ---------------------------------------------------------------------------
  Widget _buildStepReveal() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: dmSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: dmBorder, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: dmCyan,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(
                  color: dmInk,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Todo listo para explorar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dmInk,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tus preferencias han quedado vinculadas a tu perfil. Puedes consultarlas o reconfigurarlas en cualquier momento desde Mi Cuenta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: dmTextMuted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _finishAndGoStore,
            style: ElevatedButton.styleFrom(
              backgroundColor: dmLime,
              foregroundColor: dmInk,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Explorar la colección del Atelier →',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _goToAiStudio,
            style: OutlinedButton.styleFrom(
              foregroundColor: dmInk,
              side: const BorderSide(color: dmBorder, width: 1.2),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Consultar sugerencias con Altair IA ✨',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER ACTIONS
  // ---------------------------------------------------------------------------
  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: dmBg,
        border: Border(top: BorderSide(color: dmBorder, width: 1)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      setState(() => _currentStep--);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: dmInk,
                side: const BorderSide(color: dmBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Atrás',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const Spacer(),
          if (_currentStep < 3)
            ElevatedButton(
              onPressed: () {
                setState(() => _currentStep++);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dmLime,
                foregroundColor: dmInk,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continuar →',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          else
            ElevatedButton(
              onPressed: _isSaving ? null : _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: dmLime,
                foregroundColor: dmInk,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: dmInk,
                      ),
                    )
                  : Text(
                      widget.isReconfiguring
                          ? 'Guardar cambios de estilo ✓'
                          : 'Guardar preferencias →',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
        ],
      ),
    );
  }

  // Helper Card Wrapper
  Widget _buildCardWrapper({
    required String eyebrow,
    required String title,
    required String description,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dmSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: dmBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: dmInk,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: dmInk,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: dmTextMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF1EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFA23B2A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          content,
        ],
      ),
    );
  }

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
