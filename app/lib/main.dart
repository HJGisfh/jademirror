import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'utils/app_theme.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/jade_app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  final chatProvider = ChatProvider();

  await authProvider.loadSession();
  await chatProvider.initHttp();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF7F2E8),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(JadeMirrorApp(
    authProvider: authProvider,
    chatProvider: chatProvider,
  ));
}

class JadeMirrorApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ChatProvider chatProvider;

  const JadeMirrorApp({
    super.key,
    required this.authProvider,
    required this.chatProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'JadeMirror',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const JadeAppShell(),
      ),
    );
  }
}
