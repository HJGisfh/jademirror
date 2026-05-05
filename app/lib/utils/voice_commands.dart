enum VoiceCommandType {
  startQuick,
  startDeep,
  selectOption,
  nextQuestion,
  previousQuestion,
  submitTest,
  sendChat,
  resetTest,
  openChat,
  clearChat,
  goHome,
  generateImage,
  unknown,
}

class VoiceCommandMatch {
  final VoiceCommandType type;
  final String raw;
  final String? option;

  const VoiceCommandMatch({
    required this.type,
    required this.raw,
    this.option,
  });
}

String normalizeVoiceText(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'[\s\u3000]+'), '')
      .toLowerCase();
}

VoiceCommandMatch parseVoiceCommand(String input) {
  final text = normalizeVoiceText(input);
  if (text.isEmpty) {
    return VoiceCommandMatch(type: VoiceCommandType.unknown, raw: input);
  }

  if (text.contains('开始快速映照') || text.contains('快速映照') || text.contains('快测') || text.contains('快速测试')) {
    return VoiceCommandMatch(type: VoiceCommandType.startQuick, raw: input);
  }

  if (text.contains('开始深度照心') || text.contains('深度照心') || text.contains('深度测试') || text.contains('拾陆问')) {
    return VoiceCommandMatch(type: VoiceCommandType.startDeep, raw: input);
  }

  if (text.contains('提交') || text.contains('完成测试') || text.contains('确认提交')) {
    return VoiceCommandMatch(type: VoiceCommandType.submitTest, raw: input);
  }

  if (text.contains('发送') || text.contains('发送消息') || text.contains('发出去') || text.contains('说完了')) {
    return VoiceCommandMatch(type: VoiceCommandType.sendChat, raw: input);
  }

  if (text.contains('下一题') || text.contains('下一步') || text.contains('继续')) {
    return VoiceCommandMatch(type: VoiceCommandType.nextQuestion, raw: input);
  }

  if (text.contains('上一题') || text.contains('返回上一题') || text.contains('后退')) {
    return VoiceCommandMatch(type: VoiceCommandType.previousQuestion, raw: input);
  }

  if (text.contains('重置') || text.contains('清除答案') || text.contains('重新测试')) {
    return VoiceCommandMatch(type: VoiceCommandType.resetTest, raw: input);
  }

  if (text.contains('返回照心') ||
      text.contains('回照心') ||
      text.contains('返回首页') ||
      text.contains('回首页') ||
      text.contains('回到首页')) {
    return VoiceCommandMatch(type: VoiceCommandType.goHome, raw: input);
  }

  if (text.contains('打开对话') || text.contains('去对话') || text.contains('与古玉对话') || text.contains('开始对话')) {
    return VoiceCommandMatch(type: VoiceCommandType.openChat, raw: input);
  }

  if (text.contains('清空对话') || text.contains('清空消息') || text.contains('清空聊天')) {
    return VoiceCommandMatch(type: VoiceCommandType.clearChat, raw: input);
  }

  if (text.contains('生成玉像') || text.contains('千问生成') || text.contains('生图')) {
    return VoiceCommandMatch(type: VoiceCommandType.generateImage, raw: input);
  }

  final optionMatch = RegExp(r'(?:选|选择|答案|第)?([abcd])').firstMatch(text);
  if (optionMatch != null) {
    final option = optionMatch.group(1)!.toUpperCase();
    return VoiceCommandMatch(
      type: VoiceCommandType.selectOption,
      raw: input,
      option: option,
    );
  }

  if (text == 'a' || text == 'b' || text == 'c' || text == 'd') {
    return VoiceCommandMatch(
      type: VoiceCommandType.selectOption,
      raw: input,
      option: text.toUpperCase(),
    );
  }

  return VoiceCommandMatch(type: VoiceCommandType.unknown, raw: input);
}
