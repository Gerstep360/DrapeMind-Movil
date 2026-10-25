import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

class LoginFormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController name, email, password, phone;
  final bool register, loading, showPassword;
  final String? error;
  final VoidCallback submit, togglePassword;
  final ValueChanged<bool> changeMode;
  final VoidCallback? configureConnection;
  const LoginFormView({
    super.key,
    required this.formKey,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.register,
    required this.loading,
    required this.showPassword,
    required this.submit,
    required this.togglePassword,
    required this.changeMode,
    this.error,
    this.configureConnection,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            border: Border.all(color: AppColors.ink, width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'D',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DrapeMind',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                'Tu estilo, tu espacio',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      register ? 'Tu cuenta, tu estilo' : 'Bienvenido',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      register
                          ? 'Guarda tus favoritos y encuentra prendas para ti.'
                          : 'Tu correo y contraseña. Nosotros te llevamos a tu espacio.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.paperLight,
                        border: Border.all(color: AppColors.lineStrong),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Entrar'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Crear cuenta'),
                                ),
                              ],
                              selected: {register},
                              showSelectedIcon: false,
                              onSelectionChanged: loading
                                  ? null
                                  : (values) => changeMode(values.first),
                            ),
                            const SizedBox(height: 22),
                            if (register) ...[
                              TextFormField(
                                controller: name,
                                autofillHints: const [AutofillHints.name],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre completo',
                                ),
                                validator: (v) =>
                                    v == null || v.trim().length < 2
                                    ? 'Escribe tu nombre'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (v) =>
                                  v != null && v.trim().contains('@')
                                  ? null
                                  : 'Escribe un correo válido',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: password,
                              obscureText: !showPassword,
                              autofillHints: [
                                register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              textInputAction: register
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onFieldSubmitted: loading
                                  ? null
                                  : (_) => submit(),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: showPassword
                                      ? 'Ocultar contraseña'
                                      : 'Mostrar contraseña',
                                  onPressed: togglePassword,
                                  icon: Icon(
                                    showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Escribe tu contraseña'
                                  : register && v.length < 8
                                  ? 'Usa al menos 8 caracteres'
                                  : null,
                            ),
                            if (register) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: phone,
                                keyboardType: TextInputType.phone,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono (opcional)',
                                ),
                              ),
                            ],
                            AnimatedSize(
                              duration: MediaQuery.of(context).disableAnimations
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: error == null
                                  ? const SizedBox(height: 18)
                                  : Semantics(
                                      liveRegion: true,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        child: Text(
                                          error!,
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            FilledButton.icon(
                              onPressed: loading ? null : submit,
                              icon: loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward),
                              label: Text(
                                loading
                                    ? (register
                                          ? 'Creando cuenta…'
                                          : 'Entrando…')
                                    : (register ? 'Crear mi cuenta' : 'Entrar'),
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppColors.ink,
                                foregroundColor: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!register)
                      TextButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Contacta con tu tienda para recuperar el acceso de forma segura.',
                            ),
                          ),
                        ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    if (configureConnection != null)
                      TextButton(
                        onPressed: configureConnection,
                        child: const Text('Configurar conexión local'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
