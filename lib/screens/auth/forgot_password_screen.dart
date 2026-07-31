import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.resetPassword(_emailController.text.trim());
      setState(() => _emailSent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Forgot Password',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  // ─── Form View ───────────────────────────────────────────────
  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Icon
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.lock_reset,
                size: 50,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Title
          const Text(
            'Reset Password 🔑',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter your registered email address and we\'ll send you a link to reset your password.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 36),

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 32),

          // Send Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetLink,
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : const Text('Send Reset Link'),
            ),
          ),

          const SizedBox(height: 16),

          // Back to Login
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Back to Login',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Success View (after email sent) ─────────────────────────
  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success Icon
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 60,
            color: AppColors.success,
          ),
        ),

        const SizedBox(height: 32),

        const Text(
          'Email Sent! ✅',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'A password reset link has been sent to\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Check your inbox and click the link to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 48),

        // Back to Login Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Login'),
          ),
        ),

        const SizedBox(height: 16),

        // Resend
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text(
            'Resend Email',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}