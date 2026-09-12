import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegister = false;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final auth = context.read<AuthService>();
    final security = context.read<SecurityService>();

    try {
      if (_isRegister) {
        await auth.register(
          nombre: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          telefono: _phoneController.text.trim(),
        );
      } else {
        await auth.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      // Al loguearse exitosamente, si no tiene PIN configurado, sugerimos activarlo
      if (mounted && !security.isPinEnabled) {
        _promptPinSetup();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Ocurrió un error inesperado al conectar con el servidor ($e).',
        );
      }
    }
  }

  void _promptPinSetup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String newPin = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: AppSvg.raw(
                      AppSvg.lock,
                      size: 24,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ACTIVAR ACCESO RÁPIDO SEGURO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Para proteger tus compras y tu saldo en Bs, puedes configurar un PIN de 4 dígitos o Huella para no volver a escribir tu contraseña.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < newPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isFilled
                              ? AppColors.forest
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.forest, width: 2),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Teclado numérico simplificado para modal
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 1; i <= 9; i++)
                        _buildModalDigit('$i', () {
                          if (newPin.length < 4) {
                            setModalState(() => newPin += '$i');
                            if (newPin.length == 4) {
                              context.read<SecurityService>().setPin(newPin);
                              Navigator.pop(ctx);
                            }
                          }
                        }),
                      _buildModalDigit('0', () {
                        if (newPin.length < 4) {
                          setModalState(() => newPin += '0');
                          if (newPin.length == 4) {
                            context.read<SecurityService>().setPin(newPin);
                            Navigator.pop(ctx);
                          }
                        }
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Configurar más tarde',
                      style: TextStyle(color: AppColors.textMuted),
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

  Widget _buildModalDigit(String d, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.paperLight,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lineStrong),
        ),
        child: Center(
          child: Text(
            d,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
        ),
      ),
    );
  }

  void _quickFill(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
    setState(() => _isRegister = false);
    _submit();
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiConfig.defaultHost);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: AppColors.paperLight,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppSvg.raw(AppSvg.sparkle, size: 16, color: AppColors.ink),
            ),
            const SizedBox(width: 10),
            const Text(
              'Servidor Backend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona o ingresa la IP y puerto del servidor activo:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Host (IP pública o local)',
                hintText: '167.86.106.105 o 127.0.0.1:8000',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  backgroundColor: AppColors.lime.withAlpha(60),
                  side: const BorderSide(color: AppColors.lime, width: 1.2),
                  label: const Text(
                    'VPS Oficial (167.86.106.105)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  onPressed: () {
                    controller.text = '167.86.106.105';
                  },
                ),
                ActionChip(
                  backgroundColor: AppColors.cyan.withAlpha(60),
                  side: const BorderSide(color: AppColors.cyan, width: 1.2),
                  label: const Text(
                    'Wi-Fi LAN (192.168.100.223:8000)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  onPressed: () {
                    controller.text = '192.168.100.223:8000';
                  },
                ),
                ActionChip(
                  backgroundColor: AppColors.paperDark,
                  side: const BorderSide(color: AppColors.line),
                  label: const Text(
                    'ADB Reverse / Local (127.0.0.1:8000)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  onPressed: () {
                    controller.text = '127.0.0.1:8000';
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text == '167.86.106.105' || text.isEmpty) {
                await ApiConfig.resetHost();
              } else {
                await ApiConfig.setCustomHost(text);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SERVER CONNECTION BAR
                  Align(
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: _showServerConfigDialog,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paperLight,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0810110F),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF57A773),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Servidor: ${ApiConfig.defaultHost}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BRAND HEADER
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A10110F),
                            blurRadius: 20,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'D',
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'DrapeMind',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyan,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'MODA OPERADA CON INTELIGENCIA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Del perchero\na la decisión.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                      color: AppColors.ink,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Inventario real, reservas en tienda y un estilista IA que consulta herramientas antes de responder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMutedStrong,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // MAIN CARD
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A10110F),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // SEGMENTED PILL TABS (Iniciar sesión / Registrarse)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.paperDark,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isRegister = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isRegister ? AppColors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: !_isRegister
                                            ? const [
                                                BoxShadow(
                                                  color: Color(0x0F10110F),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        'Iniciar sesión',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !_isRegister
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: !_isRegister
                                              ? AppColors.ink
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isRegister = true),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isRegister ? AppColors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: _isRegister
                                            ? const [
                                                BoxShadow(
                                                  color: Color(0x0F10110F),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        'Registrarse',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: _isRegister
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: _isRegister
                                              ? AppColors.ink
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Form Heading Title & Subtitle (Identical to Angular)
                          Text(
                            !_isRegister ? 'Bienvenido de vuelta' : 'Crea tu cuenta',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !_isRegister
                                ? 'Ingresa con tu cuenta de administrador, vendedor o cliente.'
                                : 'Regístrate para guardar favoritos, reservar prendas y diseñar con IA.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerBg,
                                border: Border.all(
                                  color: AppColors.danger.withAlpha(80),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_isRegister) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nombre Completo',
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: AppSvg.raw(
                                    AppSvg.user,
                                    size: 18,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Ingresa tu nombre'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ],

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Correo Electrónico',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: AppSvg.raw(
                                  AppSvg.user,
                                  size: 18,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || !v.contains('@')
                                ? 'Ingresa un correo válido'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: AppSvg.raw(
                                  AppSvg.lock,
                                  size: 18,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 4
                                ? 'Mínimo 4 caracteres'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          if (_isRegister) ...[
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Teléfono (Opcional)',
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: AppSvg.raw(
                                    AppSvg.user,
                                    size: 18,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const SizedBox(height: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: auth.isLoading ? null : _submit,
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isRegister
                                            ? 'Registrarme y acceder'
                                            : 'Entrar al sistema',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                        color: AppColors.lime,
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() => _isRegister = !_isRegister),
                              child: Text(
                                !_isRegister
                                    ? '¿No tienes una cuenta aún? Regístrate aquí'
                                    : '¿Ya tienes cuenta? Inicia sesión',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // DEMO QUICK LOGINS
                  const Text(
                    'ACCESOS RÁPIDOS DE PRUEBA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.textMutedStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickChip(
                        label: 'Cliente Demo',
                        svgIcon: AppSvg.user,
                        email: 'carlos@drapemind.com',
                        pass: 'demo123',
                      ),
                      _buildQuickChip(
                        label: 'Vendedor Showroom',
                        svgIcon: AppSvg.store,
                        email: 'ana@drapemind.com',
                        pass: 'demo123',
                      ),
                      _buildQuickChip(
                        label: 'Administrador',
                        svgIcon: AppSvg.shield,
                        email: 'admin@drapemind.com',
                        pass: 'admin123',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required String svgIcon,
    required String email,
    required String pass,
  }) {
    return ActionChip(
      avatar: AppSvg.raw(svgIcon, size: 14, color: AppColors.ink),
      backgroundColor: AppColors.paperLight,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      onPressed: () => _quickFill(email, pass),
    );
  }
}
