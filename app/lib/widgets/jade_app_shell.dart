import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/voice_commands.dart';
import '../views/home_view.dart';
import '../views/test_view.dart';
import '../views/result_view.dart';
import '../views/chat_view.dart';
import '../views/generate_view.dart';
import '../views/gallery_view.dart';
import '../views/me_view.dart';
import '../views/login_view.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../services/server_config.dart';
import 'jade_spirit_pet.dart';
import 'voice_command_bar.dart';

enum AppScreen {
  home,
  test,
  result,
  chat,
  generate,
  gallery,
  me,
  login,
}

class JadeAppShell extends StatefulWidget {
  const JadeAppShell({super.key});

  static JadeAppShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<JadeAppShellState>();
  }

  @override
  State<JadeAppShell> createState() => JadeAppShellState();
}

class JadeAppShellState extends State<JadeAppShell> with TickerProviderStateMixin {
  AppScreen _currentScreen = AppScreen.home;
  bool _isAnimating = false;
  bool _showServerWarning = false;

  @override
  void initState() {
    super.initState();
    _checkServerConfig();
  }

  Future<void> _checkServerConfig() async {
    final configured = await ServerConfig.isConfigured();
    if (!mounted) return;
    setState(() => _showServerWarning = !configured);
  }

  AppScreen get currentScreen => _currentScreen;

  void navigateTo(AppScreen screen) {
    if (_isAnimating || screen == _currentScreen) return;

    final userProvider = context.read<UserProvider>();
    final lockedScreens = [AppScreen.chat, AppScreen.generate, AppScreen.gallery];
    if (lockedScreens.contains(screen) && !userProvider.hasMatchedJade) {
      _showLockToast();
      return;
    }

    setState(() {
      _isAnimating = true;
      _currentScreen = screen;
    });

    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _isAnimating = false);
    });
  }

  void goBack() {
    if (_isAnimating) return;
    switch (_currentScreen) {
      case AppScreen.result:
      case AppScreen.generate:
      case AppScreen.chat:
      case AppScreen.gallery:
      case AppScreen.test:
      case AppScreen.login:
      case AppScreen.me:
        navigateTo(AppScreen.home);
        break;
      default:
        return;
    }
  }

  Future<void> _handleVoiceCommand(String input) async {
    final command = parseVoiceCommand(input);
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();

    switch (command.type) {
      case VoiceCommandType.startQuick:
        userProvider.setTestMode('quick');
        navigateTo(AppScreen.test);
        break;
      case VoiceCommandType.startDeep:
        userProvider.setTestMode('deep');
        navigateTo(AppScreen.test);
        break;
      case VoiceCommandType.submitTest:
        if (_currentScreen == AppScreen.test) {
          await userProvider.computeAndMatch();
          if (mounted) navigateTo(AppScreen.result);
        } else {
          _showVoiceHint('请先进入测试页再提交。');
        }
        break;
      case VoiceCommandType.sendChat:
        if (userProvider.hasMatchedJade) {
          navigateTo(AppScreen.chat);
        } else {
          _showLockToast();
        }
        break;
      case VoiceCommandType.goHome:
        navigateTo(AppScreen.home);
        break;
      case VoiceCommandType.openChat:
        if (userProvider.hasMatchedJade) {
          navigateTo(AppScreen.chat);
        } else {
          _showLockToast();
        }
        break;
      case VoiceCommandType.clearChat:
        chatProvider.clearMessages();
        if (userProvider.hasMatchedJade) {
          navigateTo(AppScreen.chat);
        }
        break;
      case VoiceCommandType.generateImage:
        if (userProvider.hasMatchedJade) {
          navigateTo(AppScreen.generate);
        } else {
          _showLockToast();
        }
        break;
      case VoiceCommandType.resetTest:
        userProvider.resetTest();
        navigateTo(AppScreen.home);
        break;
      case VoiceCommandType.selectOption:
      case VoiceCommandType.nextQuestion:
      case VoiceCommandType.previousQuestion:
      case VoiceCommandType.unknown:
        _showVoiceHint('已识别：${command.raw}');
        break;
    }
  }

  void _showVoiceHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
    );
  }

  Widget _buildServerWarningBanner() {
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warnGradientStart.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: AppColors.warnGradientStart.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.link_off, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '未配置服务器地址\n前往"我" → 服务器地址 → 输入电脑局域网IP',
                style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _showServerWarning = false);
              },
              child: const Icon(Icons.close, size: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  void dismissServerWarning() {
    if (mounted) setState(() => _showServerWarning = false);
  }

  void _showLockToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('请先完成照心测试，匹配你的本命玉'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
    );
  }

  bool get _showBottomNav {
    switch (_currentScreen) {
      case AppScreen.home:
      case AppScreen.test:
      case AppScreen.chat:
      case AppScreen.gallery:
      case AppScreen.me:
        return true;
      case AppScreen.result:
      case AppScreen.generate:
      case AppScreen.login:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final authProvider = context.watch<AuthProvider>();
    final hasJade = userProvider.hasMatchedJade;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F2E8), Color(0xFFF2F6EF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              _buildScreenStack(),
              if (_showServerWarning)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  child: _buildServerWarningBanner(),
                ),
              // 玉灵宠物始终保持悬浮，可全程交互
              Positioned(
                right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + (_showBottomNav ? 80 : 20),
                child: SizedBox(
                  width: 320,
                  child: VoiceCommandBar(
                    title: '玉灵童子',
                    hintText: '说出指令：开始照心、返回首页、打开对话',
                    petState: hasJade ? PetState.idle : PetState.thinking,
                    autoStartListening: true,
                    onCommand: _handleVoiceCommand,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _showBottomNav
            ? _AppBottomNav(
                currentScreen: _currentScreen,
                hasJade: hasJade,
                isLoggedIn: authProvider.isLoggedIn,
                onHomeTap: () => navigateTo(AppScreen.home),
                onTestTap: () => navigateTo(AppScreen.test),
                onChatTap: () => navigateTo(AppScreen.chat),
                onGalleryTap: () => navigateTo(AppScreen.gallery),
                onMeTap: () => navigateTo(AppScreen.me),
              )
            : null,
      ),
    );
  }

  Widget _buildScreenStack() {
    final userProvider = context.read<UserProvider>();

    return Stack(
      children: [
        _buildScreenPage(
          screen: AppScreen.home,
          builder: () => HomeView(
            onStartTest: () => navigateTo(AppScreen.test),
            onViewResult: () => navigateTo(AppScreen.result),
            onOpenChat: () => navigateTo(AppScreen.chat),
          ),
        ),
        _buildScreenPage(
          screen: AppScreen.test,
          builder: () => TestView(
            onComplete: () => navigateTo(AppScreen.result),
            onBack: () => goBack(),
          ),
        ),
        _buildScreenPage(
          screen: AppScreen.result,
          builder: () => ResultView(
            onBack: () => goBack(),
            onChat: () => navigateTo(AppScreen.chat),
            onGenerate: () => navigateTo(AppScreen.generate),
            onGallery: () => navigateTo(AppScreen.gallery),
            onRetest: () {
              userProvider.resetTest();
              navigateTo(AppScreen.home);
            },
          ),
        ),
        _buildScreenPage(
          screen: AppScreen.chat,
          builder: () => ChatView(onBack: () => goBack()),
        ),
        _buildScreenPage(
          screen: AppScreen.generate,
          builder: () => GenerateView(onBack: () => goBack()),
        ),
        _buildScreenPage(
          screen: AppScreen.gallery,
          builder: () => GalleryView(onBack: () => goBack()),
        ),
        _buildScreenPage(
          screen: AppScreen.me,
          builder: () => MeView(
            onBack: () => navigateTo(AppScreen.home),
            onLogin: () => navigateTo(AppScreen.login),
          ),
        ),
        _buildScreenPage(
          screen: AppScreen.login,
          builder: () => LoginView(
            onLoggedIn: () => navigateTo(AppScreen.me),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenPage({
    required AppScreen screen,
    required Widget Function() builder,
  }) {
    final isActive = _currentScreen == screen;
    final screenOrder = AppScreen.values.indexOf(screen);
    final currentOrder = AppScreen.values.indexOf(_currentScreen);
    final goingForward = screenOrder > currentOrder;

    final offset = isActive
        ? 0.0
        : goingForward
            ? 1.0
            : -1.0;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      offset: Offset(offset, 0),
      child: IgnorePointer(
        ignoring: !isActive,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isActive ? 1.0 : 0.0,
          child: builder(),
        ),
      ),
    );
  }
}

class _AppBottomNav extends StatelessWidget {
  final AppScreen currentScreen;
  final bool hasJade;
  final bool isLoggedIn;
  final VoidCallback onHomeTap;
  final VoidCallback onTestTap;
  final VoidCallback onChatTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onMeTap;

  const _AppBottomNav({
    required this.currentScreen,
    required this.hasJade,
    required this.isLoggedIn,
    required this.onHomeTap,
    required this.onTestTap,
    required this.onChatTap,
    required this.onGalleryTap,
    required this.onMeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              active: currentScreen == AppScreen.home,
              icon: Icons.home_outlined,
              label: '首页',
              onTap: onHomeTap,
            ),
            _NavItem(
              active: currentScreen == AppScreen.test,
              icon: Icons.auto_awesome,
              label: '照心',
              onTap: onTestTap,
            ),
            _NavItem(
              active: currentScreen == AppScreen.chat,
              icon: Icons.chat_bubble_outline,
              label: '对话',
              onTap: hasJade ? onChatTap : null,
            ),
            _NavItem(
              active: currentScreen == AppScreen.gallery,
              icon: Icons.museum_outlined,
              label: '展厅',
              onTap: hasJade ? onGalleryTap : null,
            ),
            _NavItem(
              active: currentScreen == AppScreen.me,
              icon: Icons.person_outline,
              label: '我',
              onTap: onMeTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  bool get _disabled => onTap == null;

  const _NavItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = _disabled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.jade200 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDisabled
                    ? AppColors.ink400.withValues(alpha: 0.4)
                    : (active ? AppColors.ink700 : AppColors.ink400),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDisabled
                      ? AppColors.ink400.withValues(alpha: 0.4)
                      : (active ? AppColors.ink700 : AppColors.ink400),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
