import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/companion_provider.dart';
import '../utils/app_theme.dart';

/// 与 Web `CompanionSettings.vue` 对齐：声线、自动监听、播报、跳转、空闲闲聊等。
Future<void> showCompanionSettingsSheet(
  BuildContext context,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Consumer<CompanionProvider>(
        builder: (context, companion, _) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink900.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '玉灵童子设置',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink900,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.ink500),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _sectionTitle('语音交互'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动监听'),
                        subtitle: const Text(
                          '开启后玉灵会一直听你说，静音一段时间后会自动把这句话发给服务端。',
                          style: TextStyle(fontSize: 12, height: 1.35),
                        ),
                        value: companion.autoListenStt,
                        onChanged: (v) => unawaited(companion.setAutoListenStt(v)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动语音播报'),
                        value: companion.autoSpeak,
                        onChanged: (v) => unawaited(companion.setAutoSpeak(v)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动跳转到下一步'),
                        value: companion.autoGuide,
                        onChanged: (v) => unawaited(companion.setAutoGuide(v)),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('声线角色'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in const [
                            ('default', '默认声线'),
                            ('warm', '温润声线'),
                            ('bright', '清亮声线'),
                            ('deep', '低沉声线'),
                          ])
                            ChoiceChip(
                              label: Text(item.$2),
                              selected: companion.voicePersona == item.$1,
                              onSelected: (_) {
                                unawaited(companion.setVoicePersona(item.$1));
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('当前状态'),
                      _statusRow('情绪基调', companion.emotionalToneLabel),
                      _statusRow('当前阶段', companion.stage),
                      if (companion.lastReply.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          companion.lastReply.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.ink600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _sectionTitle('隐私与记忆'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('隐私模式（不保存记忆）'),
                        value: companion.privacyMode,
                        onChanged: (v) => unawaited(companion.setPrivacyMode(v)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('空闲时主动闲聊'),
                        value: companion.idleEnabled,
                        onChanged: (v) => unawaited(companion.setIdleEnabled(v)),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('监听参数'),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '静音判定时长 ${(companion.silenceThresholdMs / 1000).toStringAsFixed(1)} 秒',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.ink700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: companion.silenceThresholdMs.clamp(800, 3000).toDouble(),
                        min: 800,
                        max: 3000,
                        divisions: 22,
                        label: '${(companion.silenceThresholdMs / 1000).toStringAsFixed(1)} 秒',
                        onChanged: (v) {
                          unawaited(companion.setSilenceThresholdMs(v.round()));
                        },
                      ),
                      Text(
                        '超过此时长没有声音，即判定说完一句。建议 1.2～2.0 秒。',
                        style: TextStyle(fontSize: 11.5, color: AppColors.ink500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink700,
      ),
    ),
  );
}

Widget _statusRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.ink500)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.ink700,
            ),
          ),
        ),
      ],
    ),
  );
}
