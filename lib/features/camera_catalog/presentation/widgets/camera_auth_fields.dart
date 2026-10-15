import 'package:flutter/material.dart';

class CameraAuthFields extends StatelessWidget {
  const CameraAuthFields({
    required this.usernameController,
    required this.passwordController,
    required this.defaultUser,
    required this.obscurePassword,
    required this.onToggleObscure,
    super.key,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String defaultUser;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: usernameController,
          decoration: InputDecoration(
            labelText: 'Usuário específico',
            hintText: defaultUser,
            helperText: 'Vazio usa o usuário global',
          ),
          maxLength: 128,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (value) =>
              (value?.length ?? 0) > 128 ? 'Use até 128 caracteres.' : null,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: 'Senha específica',
            helperText:
                'Vazia usa a senha global. Apague para voltar ao padrão.',
            suffixIcon: IconButton(
              tooltip: obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
              onPressed: onToggleObscure,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          obscureText: obscurePassword,
          maxLength: 1024,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (value) =>
              (value?.length ?? 0) > 1024 ? 'Use até 1024 caracteres.' : null,
          enableSuggestions: false,
          autocorrect: false,
        ),
      ],
    );
  }
}
