import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';
import '../views/test_view.dart';
import '../views/result_view.dart';
import '../views/chat_view.dart';
import '../views/generate_view.dart';
import '../views/gallery_view.dart';

GoRouter createRouter(UserProvider userProvider) {
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/test',
      ),
      GoRoute(
        path: '/test',
        name: 'test',
        builder: (context, state) => TestView(
          onComplete: () => context.go('/result'),
          onBack: () => context.go('/test'),
          onViewResult: () => context.go('/result'),
          onOpenChat: () => context.go('/chat'),
        ),
      ),
      GoRoute(
        path: '/result',
        name: 'result',
        builder: (context, state) => ResultView(
          onBack: () => context.go('/test'),
          onChat: () => context.go('/chat'),
          onGenerate: () => context.go('/generate'),
          onGallery: () => context.go('/gallery'),
          onRetest: () {
            userProvider.resetTest();
            context.go('/test');
          },
        ),
        redirect: (context, state) {
          if (!userProvider.hasMatchedJade) return '/test';
          return null;
        },
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => ChatView(onBack: () => context.go('/test')),
        redirect: (context, state) {
          if (!userProvider.hasMatchedJade) return '/test';
          return null;
        },
      ),
      GoRoute(
        path: '/generate',
        name: 'generate',
        builder: (context, state) => GenerateView(onBack: () => context.go('/test')),
      ),
      GoRoute(
        path: '/gallery',
        name: 'gallery',
        builder: (context, state) => GalleryView(onBack: () => context.go('/test')),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('页面未找到', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/test'),
              child: const Text('返回照心'),
            ),
          ],
        ),
      ),
    ),
  );
}
