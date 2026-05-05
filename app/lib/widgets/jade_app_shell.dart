import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_screen.dart';
import '../providers/companion_provider.dart';
import '../providers/voice_shell_controller.dart';
import '../utils/app_theme.dart';
import '../utils/voice_commands.dart';
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
import 'jade_spirit_pet.dart';
import 'voice_command_bar.dart';

class JadeAppShell extends StatefulWidget {
  const JadeAppShell({super.key});

  static JadeAppShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<JadeAppShellState>();
  }

  @override
  State<JadeAppShell> createState() => JadeAppShellState();
}

class JadeAppShellState extends State<JadeAppShell> with TickerProviderStateMixin {
  AppScreen _currentScreen = AppScreen.test;
  bool _isAnimating = false;
  /// 玉灵童子悬浮条相对默认锚点的平移（像素）。
  Offset _voiceBarPanOffset = Offset.zero;
  /// 字幕面板展开时占位更高，便于拖动边界计算。
  bool _voiceCaptionsExpanded = false;

  AppScreen get currentScreen => _currentScreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_wireCompanion()));
  }

  Future<void> _wireCompanion() async {
    if (!mounted) return;
    final companion = context.read<CompanionProvider>();
    companion.onNavigate = _onAssistantNavigate;
    companion.onLegacyVoiceFallback = _handleVoiceCommand;
    await companion.loadPersistedSettings();
    if (!mounted) return;
    companion.syncStageFromAppScreen(_currentScreen);
    await companion.welcomeIfNeeded();
  }

  void _onAssistantNavigate(CompanionNavigateEvent e) {
    if (!mounted) return;
    final companion = context.read<CompanionProvider>();
    if (!companion.autoGuide) return;

    var route = e.suggestedRoute;
    if (route.isEmpty) {
      switch (e.nextAction) {
        case 'start_test':
        case 'continue_test':
          route = '/test';
          break;
        case 'show_result':
          route = '/result';
          break;
        case 'go_chat':
        case 'free_chat':
          route = '/chat';
          break;
        case 'go_generate':
        case 'generate_jade':
        case 'save_work':
          route = '/generate';
          break;
        case 'go_gallery':
        case 'delete_work':
        case 'open_work':
        case 'start_gallery_tour':
        case 'next_gallery_item':
        case 'prev_gallery_item':
        case 'stop_gallery_tour':
          route = '/gallery';
          break;
        default:
          return;
      }
    }

    final userProvider = context.read<UserProvider>();
    final locked = !userProvider.hasMatchedJade;

    switch (route) {
      case '/test':
        navigateTo(AppScreen.test);
        break;
      case '/result':
        if (userProvider.hasMatchedJade) {
          navigateTo(AppScreen.result);
        } else {
          navigateTo(AppScreen.test);
        }
        break;
      case '/chat':
        if (locked) {
          _showLockToast();
        } else {
          navigateTo(AppScreen.chat);
        }
        break;
      case '/generate':
        if (locked) {
          _showLockToast();
        } else {
          navigateTo(AppScreen.generate);
        }
        break;
      case '/gallery':
        if (locked) {
          _showLockToast();
        } else {
          navigateTo(AppScreen.gallery);
        }
        break;
      default:
        break;
    }
  }

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

    if (mounted) {
      context.read<CompanionProvider>().syncStageFromAppScreen(screen);
    }

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
        navigateTo(AppScreen.test);
        break;
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
        navigateTo(AppScreen.test);
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
        navigateTo(AppScreen.test);
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

  void _clampVoiceBarPan(MediaQueryData mq) {
    const barW = 340.0;
    final barH = _voiceCaptionsExpanded ? 420.0 : 200.0;
    final s = mq.size;
    final pad = mq.padding;
    final bottomAnchor = mq.viewInsets.bottom + (_showBottomNav ? 80.0 : 20.0);
    _voiceBarPanOffset = Offset(
      _voiceBarPanOffset.dx.clamp(-(s.width - barW - 16), 16),
      _voiceBarPanOffset.dy.clamp(-(s.height - bottomAnchor - barH - pad.top - 8), 24),
    );
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
          child: Builder(
            builder: (context) {
              final mq = MediaQuery.of(context);
              final voiceShell = context.watch<VoiceShellController>();
              final companion = context.watch<CompanionProvider>();
              return Stack(
                children: [
                  _buildScreenStack(),
                  Positioned(
                    right: 12,
                    bottom: mq.viewInsets.bottom + (_showBottomNav ? 80 : 20),
                    child: Transform.translate(
                      offset: _voiceBarPanOffset,
                      child: VoiceCommandBar(
                        companion: companion,
                        voiceShell: voiceShell,
                        title: '玉灵童子',
                        hintText: '自动监听时，说完话静音片刻即发送；点小动物打开设置。',
                        petState: hasJade ? PetState.idle : PetState.thinking,
                        onVoiceShellSuppressChanged: (suppressed) {
                          context.read<CompanionProvider>().setListeningSuppressed(suppressed);
                        },
                        onCaptionsExpandedChanged: (expanded) {
                          setState(() => _voiceCaptionsExpanded = expanded);
                          _clampVoiceBarPan(mq);
                        },
                        onUserSpeech: (text) => companion.handleUserText(text),
                        onPetPanUpdate: (details) {
                          setState(() {
                            _voiceBarPanOffset += details.delta;
                            _clampVoiceBarPan(mq);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: _showBottomNav
            ? _AppBottomNav(
                currentScreen: _currentScreen,
                hasJade: hasJade,
                isLoggedIn: authProvider.isLoggedIn,
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
          screen: AppScreen.test,
          builder: () => TestView(
            onComplete: () => navigateTo(AppScreen.result),
            onBack: () => goBack(),
            onViewResult: () => navigateTo(AppScreen.result),
            onOpenChat: () => navigateTo(AppScreen.chat),
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
              navigateTo(AppScreen.test);
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
            onBack: () => navigateTo(AppScreen.test),
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
  final VoidCallback onTestTap;
  final VoidCallback onChatTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onMeTap;

  const _AppBottomNav({
    required this.currentScreen,
    required this.hasJade,
    required this.isLoggedIn,
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
