import '../../../core/common_widgets/aasha_surface.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_state.dart';
import '../../../data/models/auth_status.dart';
import '../../../data/models/app_user.dart';
import '../../../core/common_widgets/app_button.dart';
import '../../../core/common_widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.role == UserRole.user ? 'User Login' : 'Official Login',
        ),
      ),
      body: AashaSurface(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                widget.role == UserRole.user
                    ? 'Find your family'
                    : 'Access official records',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Please login to continue using the app.'),
              const SizedBox(height: 32),
              AppTextField(
                label: 'Email Address',
                hint: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: true,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/forgot_password'),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Login',
                isLoading: state.status == AuthStatus.loading,
                onPressed: () async {
                  if (state.status == AuthStatus.loading) return;

                  final email = _emailController.text.trim();
                  final password = _passwordController.text;

                  if (email.isEmpty || password.isEmpty) {
                    setState(
                      () => _errorMessage =
                          'Please enter both email and password.',
                    );
                    return;
                  }

                  setState(() => _errorMessage = null);
                  final error = await state.login(email, password);
                  if (error != null && mounted) {
                    setState(() => _errorMessage = error);
                  }
                },
              ),
              if (widget.role == UserRole.official) ...[
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Official accounts are pre-authorized. If you do not have credentials, please contact your organization administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.role == UserRole.user)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      child: const Text('Register'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
