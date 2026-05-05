import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

class LoginView extends StatefulWidget {
  final VoidCallback? onLoggedIn;

  const LoginView({super.key, this.onLoggedIn});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _isRegister = false;
  final _usernameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isRegister = !_isRegister;
      _usernameController.clear();
      _nicknameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnack('请填写用户名和密码');
      return;
    }

    String? error;
    if (_isRegister) {
      final nickname = _nicknameController.text.trim();
      final confirm = _confirmPasswordController.text;
      if (password != confirm) {
        _showSnack('两次输入的密码不一致');
        return;
      }
      if (username.length < 3) {
        _showSnack('用户名至少 3 个字符');
        return;
      }
      if (password.length < 6) {
        _showSnack('密码至少 6 位');
        return;
      }
      error = await auth.register(
        username: username,
        password: password,
        nickname: nickname.isNotEmpty ? nickname : username,
      );
    } else {
      error = await auth.login(username: username, password: password);
    }

    if (error != null) {
      if (mounted) _showSnack(error);
    } else {
      if (mounted) {
        _showSnack(_isRegister ? '注册成功，欢迎来到玉镜' : '登录成功');
        widget.onLoggedIn?.call();
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return JadeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [AppColors.jade200, AppColors.primaryGradientStart],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGradientStart.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.diamond_outlined, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _isRegister ? '注册玉镜' : '进入玉镜',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _isRegister ? '创建账号，开启你的照心之旅' : '以玉为镜，照见本心',
                    style: TextStyle(fontSize: 14, color: AppColors.ink500),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _usernameController,
                          label: '用户名',
                          icon: Icons.person_outline,
                          textInputAction: _isRegister ? TextInputAction.next : TextInputAction.done,
                          onSubmitted: _isRegister ? null : _submit,
                        ),
                        if (_isRegister) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildTextField(
                            controller: _nicknameController,
                            label: '昵称（选填）',
                            icon: Icons.badge_outlined,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _passwordController,
                          label: '密码',
                          icon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                              color: AppColors.ink400,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          onSubmitted: !_isRegister ? _submit : null,
                        ),
                        if (_isRegister) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: '确认密码',
                            icon: Icons.lock_outline,
                            obscure: _obscurePassword,
                            onSubmitted: _submit,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: JadeButton(
                            label: _isRegister ? '注册' : '登录',
                            isPrimary: true,
                            isLoading: auth.isLoading,
                            onPressed: auth.isLoading ? null : _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _switchMode,
                    style: TextButton.styleFrom(foregroundColor: AppColors.ink500),
                    child: Text(
                      _isRegister ? '已有账号？去登录' : '没有账号？去注册',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction ?? TextInputAction.next,
      onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.ink400, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: AppColors.ink400),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.jade100.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.primaryGradientStart.withValues(alpha: 0.4)),
        ),
      ),
      style: TextStyle(fontSize: 15, color: AppColors.ink900),
    );
  }
}
