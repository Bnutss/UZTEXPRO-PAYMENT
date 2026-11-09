import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show AdaptiveSwitch, AlertAction, AlertActionStyle;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fade_route.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/routeless_alert.dart';
import '../chat/chat_notify_settings.dart';
import '../chat/chat_sounds.dart';
import 'settings_rows.dart';

String chatSoundLabel(S s, ChatSoundChoice c) => switch (c) {
  ChatSoundChoice.standard => s.notifSoundStandard,
  ChatSoundChoice.telegram => s.notifSoundTelegram,
  ChatSoundChoice.dice => s.notifSoundDice,
  ChatSoundChoice.system => s.notifSoundSystem,
  ChatSoundChoice.none => s.notifSoundNone,
};

/// "Notifications and sounds", as in Telegram: what the messenger does by
/// itself while the app is open, and which sounds it makes.
class ChatNotificationsPage extends StatefulWidget {
  const ChatNotificationsPage({super.key});

  @override
  State<ChatNotificationsPage> createState() => _ChatNotificationsPageState();
}

class _ChatNotificationsPageState extends State<ChatNotificationsPage> {
  final _settings = ChatNotifySettings.instance;
  late final ChatSounds _sounds = ChatSounds(
    AudioChatSoundPlayer(),
    settings: _settings,
  );

  @override
  void initState() {
    super.initState();
    _settings.load();
    _settings.addListener(_changed);
    localeNotifier.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_changed);
    localeNotifier.removeListener(_changed);
    super.dispose();
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF8A8A8E),
        fontSize: 13,
        letterSpacing: 0.2,
      ),
    ),
  );

  Widget _footer(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 13),
    ),
  );

  Widget _switchRow({
    required IconData icon,
    required Color color,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SettingsRow(
      icon: icon,
      color: color,
      title: title,
      onTap: () => onChanged(!value),
      trailing: AdaptiveSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.brandOrange,
      ),
    );
  }

  void _pick({
    required String title,
    required ChatSoundChoice current,
    required ValueChanged<ChatSoundChoice> onPicked,
  }) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      FadeRoute(
        builder: (_) => _SoundPickerPage(
          title: title,
          current: current,
          sounds: _sounds,
          onPicked: onPicked,
        ),
      ),
    );
  }

  void _confirmReset(S s) {
    showNativeAlert(
      context: context,
      title: s.notifReset,
      message: s.notifResetMessage,
      actions: [
        AlertAction(
          title: s.notifResetBtn,
          style: AlertActionStyle.destructive,
          onPressed: _settings.reset,
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FadingHeaderScaffold(
      title: s.notifTitle,
      background: AppColors.groupedBackground,
      body: (context, topInset) => ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 40),
        children: [
          _caption(s.notifInApp),
          SettingsGroup(
            children: [
              _switchRow(
                icon: Icons.volume_up_rounded,
                color: SettingsColors.green,
                title: s.notifInAppSounds,
                value: _settings.inAppSounds,
                onChanged: (v) => _settings.update(sounds: v),
              ),
              _switchRow(
                icon: Icons.vibration_rounded,
                color: SettingsColors.indigo,
                title: s.notifInAppVibrate,
                value: _settings.inAppVibrate,
                onChanged: (v) => _settings.update(vibrate: v),
              ),
              _switchRow(
                icon: Icons.chat_bubble_rounded,
                color: SettingsColors.blue,
                title: s.notifInAppPreview,
                value: _settings.inAppPreview,
                onChanged: (v) => _settings.update(preview: v),
              ),
            ],
          ),
          _footer(s.notifInAppPreviewHint),
          const SizedBox(height: 24),
          _caption(s.notifSounds),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.south_west_rounded,
                color: SettingsColors.orange,
                title: s.notifSoundIncoming,
                value: chatSoundLabel(s, _settings.incomingSound),
                onTap: () => _pick(
                  title: s.notifSoundIncoming,
                  current: _settings.incomingSound,
                  onPicked: (c) => _settings.update(incoming: c),
                ),
              ),
              SettingsRow(
                icon: Icons.north_east_rounded,
                color: SettingsColors.blue,
                title: s.notifSoundSent,
                value: chatSoundLabel(s, _settings.sentSound),
                onTap: () => _pick(
                  title: s.notifSoundSent,
                  current: _settings.sentSound,
                  onPicked: (c) => _settings.update(sent: c),
                ),
              ),
            ],
          ),
          _footer(s.notifSoundsHint),
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _confirmReset(s);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Text(
                      s.notifReset,
                      style: const TextStyle(
                        color: Color(0xFFFF3B30),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A list of sounds with a check on the current one; tapping one plays it.
class _SoundPickerPage extends StatefulWidget {
  const _SoundPickerPage({
    required this.title,
    required this.current,
    required this.sounds,
    required this.onPicked,
  });

  final String title;
  final ChatSoundChoice current;
  final ChatSounds sounds;
  final ValueChanged<ChatSoundChoice> onPicked;

  @override
  State<_SoundPickerPage> createState() => _SoundPickerPageState();
}

class _SoundPickerPageState extends State<_SoundPickerPage> {
  late ChatSoundChoice _current = widget.current;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FadingHeaderScaffold(
      title: widget.title,
      background: AppColors.groupedBackground,
      body: (context, topInset) => ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 40),
        children: [
          SettingsGroup(
            indent: 16,
            children: [
              // Android has no system alert sound to play from the app.
              for (final c in ChatSoundChoice.values.where(
                (c) => !(Platform.isAndroid && c == ChatSoundChoice.system),
              ))
                SettingsRow(
                  leading: const SizedBox(width: 0),
                  title: chatSoundLabel(s, c),
                  onTap: () {
                    setState(() => _current = c);
                    widget.onPicked(c);
                    widget.sounds.preview(c);
                  },
                  trailing: _current == c
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.brandOrange,
                        )
                      : const SizedBox(width: 24),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
