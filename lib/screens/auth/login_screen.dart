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
      if (mounted) setState(() => _errorMessage = 'Ocurrió un error inesperado al conectar con el servidor ($e).');
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
                    child: AppSvg.raw(AppSvg.lock, size: 24, color: AppColors.forest),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ACTIVAR ACCESO RÁPIDO SEGURO',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.forest),
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
                          color: isFilled ? AppColors.forest : Colors.transparent,
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
                    child: const Text('Configurar más tarde', style: TextStyle(color: AppColors.textMuted)),
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
          child: Text(d, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.forest)),
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
        backgroundColor: AppColors.paperLight,
        title: Row(
          children: [
            AppSvg.raw(AppSvg.sparkle, size: 18, color: AppColors.forest),
            const SizedBox(width: 8),
            const Text('Configurar Conexión Backend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona o ingresa la IP y puerto del servidor:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Host (IP:Puerto)',
                hintText: '192.168.100.223:8000 o 127.0.0.1:8000',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Wi-Fi LAN (192.168.100.223:8000)', style: TextStyle(fontSize: 10.5)),
                  onPressed: () {
                    controller.text = '192.168.100.223:8000';
                  },
                ),
                ActionChip(
                  label: const Text('ADB Reverse (127.0.0.1:8000)', style: TextStyle(fontSize: 10.5)),
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
            onPressed: () {
              ApiConfig.setCustomHost(controller.text.trim());
              Navigator.pop(ctx);
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
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.paperLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lineStrong),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.forest,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Servidor: ${ApiConfig.defaultHost}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.forest),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // BRAND HEADER
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.forest.withAlpha(50),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AppSvg.raw(
                        AppSvg.sparkle,
                        size: 32,
                        color: AppColors.acid,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DRAPEMIND',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColors.forestDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Haute Couture & AI Personal Stylist',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // MAIN CARD
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.lineStrong),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // TABS
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isRegister = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: !_isRegister
                                              ? AppColors.forest
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Iniciar Sesión',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: !_isRegister
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: !_isRegister
                                            ? AppColors.forest
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isRegister = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: _isRegister
                                              ? AppColors.forest
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Crear Cuenta',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _isRegister
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: _isRegister
                                            ? AppColors.forest
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerBg,
                                border: Border.all(color: AppColors.danger.withAlpha(80)),
                                borderRadius: BorderRadius.circular(4),
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
                                  child: AppSvg.raw(AppSvg.user, size: 18, color: AppColors.forest),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Ingresa tu nombre' : null,
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
                                child: AppSvg.raw(AppSvg.user, size: 18, color: AppColors.forest),
                              ),
                            ),
                            validator: (v) =>
                                v == null || !v.contains('@') ? 'Ingresa un correo válido' : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: AppSvg.raw(AppSvg.lock, size: 18, color: AppColors.forest),
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.length < 4 ? 'Mínimo 4 caracteres' : null,
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
                                  child: AppSvg.raw(AppSvg.user, size: 18, color: AppColors.forest),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const SizedBox(height: 10),
                          ElevatedButton(
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
                                : Text(_isRegister ? 'Registrarme' : 'Entrar al Atelier'),
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
      avatar: AppSvg.raw(svgIcon, size: 14, color: AppColors.forest),
      backgroundColor: AppColors.paperLight,
      side: const BorderSide(color: AppColors.lineStrong),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.forest,
        ),
      ),
      onPressed: () => _quickFill(email, pass),
    );
  }
}
