import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/sync_service.dart';

enum _AuthMode { signIn, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider authProvider) async {
    authProvider.clearError();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = _mode == _AuthMode.signIn
        ? await authProvider.login(email: email, password: password)
        : await authProvider.register(email: email, password: password);

    if (!mounted || !success) {
      return;
    }

    await SyncService.instance.syncPendingData();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _mode == _AuthMode.signIn
              ? 'Signed in successfully.'
              : 'Account created and signed in.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Secure account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Protect report sync with a personal account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your disease reports can stay offline on the device, but backend sync now uses user sessions instead of one shared app token.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 20),
              if (authProvider.isAuthenticated && user != null)
                _SignedInCard(
                  email: user.email,
                  isLoading: authProvider.isLoading,
                  onRefresh: authProvider.refreshSession,
                  onLogout: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await authProvider.logout();
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Signed out.')),
                    );
                  },
                )
              else
                _buildAuthForm(authProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm(AuthProvider authProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment(
                    value: _AuthMode.signIn,
                    label: Text('Sign in'),
                    icon: Icon(Icons.login_rounded),
                  ),
                  ButtonSegment(
                    value: _AuthMode.register,
                    label: Text('Register'),
                    icon: Icon(Icons.person_add_alt_1_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mode = selection.first;
                  });
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'farmer@example.com',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Enter your email address.';
                  }
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 8 characters',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.length < 8) {
                    return 'Password must be at least 8 characters.';
                  }
                  return null;
                },
              ),
              if (_mode == _AuthMode.register) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (_mode != _AuthMode.register) {
                      return null;
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
              ],
              if (authProvider.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  authProvider.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB3261E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: authProvider.isLoading
                    ? null
                    : () => _submit(authProvider),
                icon: authProvider.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _mode == _AuthMode.signIn
                            ? Icons.lock_open_rounded
                            : Icons.verified_user_rounded,
                      ),
                label: Text(
                  _mode == _AuthMode.signIn
                      ? 'Sign in and enable secure sync'
                      : 'Create account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.email,
    required this.isLoading,
    required this.onRefresh,
    required this.onLogout,
  });

  final String email;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Color(0xFF2F8F46)),
                SizedBox(width: 10),
                Text(
                  'Secure sync is active',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              email,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reports will sync through your signed-in session instead of a shared app token.',
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh session'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isLoading ? null : onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
