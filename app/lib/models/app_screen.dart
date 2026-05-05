/// 主壳层当前展示的页面（底部导航 + 栈内页）。
enum AppScreen {
  test,
  result,
  chat,
  generate,
  gallery,
  me,
  login,
}

/// 与 Web `assistantStore` 中 `normalizeStage` 一致，供 `/assistant/turn` 等接口使用。
String assistantStageForAppScreen(AppScreen screen) {
  switch (screen) {
    case AppScreen.test:
      return 'test';
    case AppScreen.result:
      return 'result';
    case AppScreen.chat:
      return 'chat';
    case AppScreen.generate:
      return 'generate';
    case AppScreen.gallery:
      return 'gallery';
    case AppScreen.me:
      return 'home';
    case AppScreen.login:
      return 'login';
  }
}
