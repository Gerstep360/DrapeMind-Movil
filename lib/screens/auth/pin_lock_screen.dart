import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _validatePin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _validatePin() {
    final security = context.read<SecurityService>();
    final success = security.verifyAndUnlock(_enteredPin);
    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'PIN incorrecto. Intenta nuevamente.';
        _enteredPin = '';
      });
    }
  }

  void _onBiometricUnlock() async {
    final security = context.read<SecurityService>();
    final success = await security.unlockWithBiometrics();
    if (success && mounted) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final userName = user?.nombre.split(' ').first ?? 'Estimado Cliente';

    return Scaffold(
      backgroundColor: const Color(0xFF0E1311),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              // HEADER DE SEGURIDAD
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.forestDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.acid.withAlpha(90), width: 1.5),
                ),
                child: AppSvg.raw(AppSvg.lock, size: 28, color: AppColors.acid),
              ),
              const SizedBox(height: 16),
              Text(
                'DRAPEMIND ATELIER',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.acid,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hola, $userName',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ingresa tu PIN de 4 dígitos para acceder a tu perchero y compras',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),

              // INDICADORES DE 4 DÍGITOS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isFilled ? AppColors.acid : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFilled ? AppColors.acid : AppColors.forest.withAlpha(120),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // MENSAJE DE ERROR
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w700),
                )
              else
                const SizedBox(height: 16),

              const Spacer(),

              // TECLADO NUMÉRICO DE ALTA COSTURA
              _buildNumpad(),

              const SizedBox(height: 16),

              // BOTÓN CERRAR SESIÓN / CAMBIAR DE CUENTA
              TextButton(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    context.read<SecurityService>().resetLock();
                  }
                },
                child: const Text(
                  'Cerrar sesión o cambiar de cuenta',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 12),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 12),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón Huella Biometría
              _buildSpecialKey(
                icon: AppSvg.sparkle,
                onTap: _onBiometricUnlock,
                tooltip: 'Desbloquear con Huella',
              ),
              _buildDigitKey('0'),
              // Botón Borrar
              _buildSpecialKey(
                icon: AppSvg.close,
                onTap: _onDeletePressed,
                tooltip: 'Borrar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitKey(d)).toList(),
    );
  }

  Widget _buildDigitKey(String digit) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.forestDark.withAlpha(150),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.forest.withAlpha(80)),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required String icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.forest.withAlpha(40),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AppSvg.raw(icon, size: 20, color: AppColors.acid),
        ),
      ),
    );
  }
}
