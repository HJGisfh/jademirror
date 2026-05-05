import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../services/server_config.dart';

class MeView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLogin;

  const MeView({super.key, required this.onBack, required this.onLogin});

  @override
  State<MeView> createState() => _MeViewState();
}

class _MeViewState extends State<MeView> {
  bool _showPasswordForm = false;
  bool _showNicknameForm = false;
  bool _showServerForm = false;
  String _serverUrl = '';
  final _currentPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _serverController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    ServerConfig.loadUrl().then((url) {
      if (mounted) setState(() => _serverUrl = url);
    });
  }

  @override
  void dispose() {
    _currentPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    _nicknameController.dispose();
    _serverController.dispose();
    super.dispose();
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

  Future<void> _changePassword() async {
    final currentPwd = _currentPwdController.text;
    final newPwd = _newPwdController.text;
    final confirmPwd = _confirmPwdController.text;

    if (currentPwd.isEmpty || newPwd.isEmpty) {
      _showSnack('请填写完整');
      return;
    }
    if (newPwd.length < 6) {
      _showSnack('新密码至少 6 位');
      return;
    }
    if (newPwd != confirmPwd) {
      _showSnack('两次输入的新密码不一致');
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.updatePassword(
      currentPassword: currentPwd,
      newPassword: newPwd,
    );

    if (error != null) {
      _showSnack(error);
    } else {
      _showSnack('密码修改成功');
      setState(() {
        _showPasswordForm = false;
        _currentPwdController.clear();
        _newPwdController.clear();
        _confirmPwdController.clear();
      });
    }
  }

  Future<void> _changeNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showSnack('请输入昵称');
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.updateNickname(nickname);

    if (error != null) {
      _showSnack(error);
    } else {
      _showSnack('昵称修改成功');
      setState(() {
        _showNicknameForm = false;
        _nicknameController.clear();
      });
    }
  }

  Future<void> _saveServerUrl() async {
    final url = _serverController.text.trim();
    if (url.isEmpty) {
      _showSnack('请输入服务器地址');
      return;
    }
    await ServerConfig.saveUrl(url);
    final loaded = await ServerConfig.loadUrl();
    if (mounted) {
      setState(() {
        _serverUrl = loaded;
        _showServerForm = false;
      });

      try {
        final auth = context.read<AuthProvider>();
        final chat = context.read<ChatProvider>();
        await auth.refreshServerUrl(loaded);
        await chat.refreshServerUrl(loaded);
        _showSnack('连接至 $loaded');
      } catch (e) {
        _showSnack('已保存，请重启应用以生效');
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final hasJade = userProvider.hasMatchedJade;
    final jade = userProvider.matchedJade;

    if (!auth.isLoggedIn) {
      return JadeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 72, color: AppColors.ink400.withValues(alpha: 0.3)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '尚未登录',
                      style: TextStyle(fontSize: 18, color: AppColors.ink500, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '登录后享受完整的玉镜体验',
                      style: TextStyle(fontSize: 14, color: AppColors.ink400),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    JadeButton(
                      label: '去登录',
                      isPrimary: true,
                      icon: Icons.login,
                      onPressed: widget.onLogin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return JadeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                _buildProfileHeader(auth),
                const SizedBox(height: AppSpacing.lg),
                _buildJadeInfoCard(hasJade, jade, userProvider),
                const SizedBox(height: AppSpacing.lg),
                _buildNicknameCard(auth),
                const SizedBox(height: AppSpacing.md),
                _buildPasswordCard(auth),
                const SizedBox(height: AppSpacing.md),
                _buildServerCard(auth),
                const SizedBox(height: AppSpacing.lg),
                _buildLogoutButton(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AuthProvider auth) {
    return JadeCard(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
              ),
            ),
            child: Center(
              child: Text(
                auth.currentUser?.displayName[0].toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            auth.displayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink900),
          ),
          const SizedBox(height: 4),
          Text(
            '@${auth.currentUser?.username ?? ""}',
            style: TextStyle(fontSize: 13, color: AppColors.ink500),
          ),
        ],
      ),
    );
  }

  Widget _buildJadeInfoCard(bool hasJade, dynamic jade, UserProvider userProvider) {
    if (!hasJade || jade == null) {
      return JadeCard(
        child: Column(
          children: [
            Icon(Icons.diamond_outlined, size: 32, color: AppColors.ink400.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '尚未完成照心测试',
              style: TextStyle(fontSize: 14, color: AppColors.ink400),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '完成测试后匹配你的本命玉',
              style: TextStyle(fontSize: 12, color: AppColors.ink400.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return JadeCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.jade200, AppColors.jade300.withValues(alpha: 0.5)],
                  ),
                ),
                child: const Icon(Icons.diamond_outlined, size: 20, color: AppColors.ink700),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '我的本命玉',
                      style: TextStyle(fontSize: 12, color: AppColors.ink500),
                    ),
                    Text(
                      jade.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink900),
                    ),
                  ],
                ),
              ),
              StatusPill(label: '${(userProvider.matchScore * 100).round()}%'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusPill(label: userProvider.mbtiType),
              const SizedBox(width: 8),
              StatusPill(label: userProvider.archetype?.label ?? ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameCard(AuthProvider auth) {
    return JadeCard(
      onTap: () => setState(() => _showNicknameForm = !_showNicknameForm),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text('修改昵称', style: TextStyle(fontSize: 14, color: AppColors.ink700, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(
                _showNicknameForm ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: AppColors.ink400,
              ),
            ],
          ),
          if (_showNicknameForm) ...[
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              controller: _nicknameController,
              hint: '输入新昵称',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: JadeButton(
                label: '保存昵称',
                isPrimary: false,
                isLoading: auth.isLoading,
                onPressed: auth.isLoading ? null : _changeNickname,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordCard(AuthProvider auth) {
    return JadeCard(
      onTap: () => setState(() => _showPasswordForm = !_showPasswordForm),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              Text('修改密码', style: TextStyle(fontSize: 14, color: AppColors.ink700, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(
                _showPasswordForm ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: AppColors.ink400,
              ),
            ],
          ),
          if (_showPasswordForm) ...[
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              controller: _currentPwdController,
              hint: '当前密码',
              icon: Icons.lock_outline,
              obscure: _obscureCurrent,
              suffix: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.ink400),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildTextField(
              controller: _newPwdController,
              hint: '新密码（至少6位）',
              icon: Icons.lock_reset,
              obscure: _obscureNew,
              suffix: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.ink400),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildTextField(
              controller: _confirmPwdController,
              hint: '确认新密码',
              icon: Icons.lock_reset,
              obscure: _obscureConfirm,
              suffix: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.ink400),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: JadeButton(
                label: '修改密码',
                isPrimary: false,
                isLoading: auth.isLoading,
                onPressed: auth.isLoading ? null : _changePassword,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServerCard(AuthProvider auth) {
    return JadeCard(
      onTap: () => setState(() => _showServerForm = !_showServerForm),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined, size: 18, color: AppColors.ink600),
              const SizedBox(width: 8),
              const Text('服务器地址', style: TextStyle(fontSize: 14, color: AppColors.ink700, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                _serverUrl.replaceAll('http://', '').replaceAll(':5000/api', ''),
                style: TextStyle(fontSize: 11, color: AppColors.ink400),
              ),
              const SizedBox(width: 4),
              Icon(
                _showServerForm ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: AppColors.ink400,
              ),
            ],
          ),
          if (_showServerForm) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '当前: $_serverUrl',
              style: TextStyle(fontSize: 11, color: AppColors.ink400),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (kReleaseMode) ...[
              Text(
                '正式版已内置云端 API，无需填写地址。换服务器请使用带 --dart-define=JADEMIRROR_API_BASE=… 的调试/定制构建。',
                style: TextStyle(fontSize: 11, color: AppColors.ink500, height: 1.35),
              ),
            ] else ...[
              _buildTextField(
                controller: _serverController,
                hint: '如 ${ServerConfig.productionHost.replaceAll('http://', '')}/api',
                icon: Icons.link,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '调试时可改成本机或局域网；默认同云端。',
                style: TextStyle(fontSize: 10, color: AppColors.ink400.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: JadeButton(
                  label: '保存地址',
                  isPrimary: false,
                  onPressed: _saveServerUrl,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return JadeButton(
      label: '退出登录',
      isPrimary: false,
      isWarn: true,
      onPressed: _logout,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.ink400, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: AppColors.ink400),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.jade100.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.primaryGradientStart.withValues(alpha: 0.4)),
        ),
      ),
      style: TextStyle(fontSize: 14, color: AppColors.ink900),
    );
  }
}
