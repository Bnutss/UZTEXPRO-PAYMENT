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
import '../chat/chat_api.dart';
import '../chat/chat_models.dart' show ChatServerNotify;
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
  const ChatNotificationsPage({super.key, this.api});

  /// The chat's connection to the server: with it the page also shows the push
  /// settings (they live on the server).
  final ChatRest? api;

  @override
  State<ChatNotificationsPage> createState() => _ChatNotificationsPageState();
}

class _ChatNotificationsPageState extends State<ChatNotificationsPage> {
  final _settings = ChatNotifySettings.instance;
  late final ChatSounds _sounds = ChatSounds(
    AudioChatSoundPlayer(),
    settings: _settings,
  );

  ChatServerNotify? _server;
  bool _serverFailed = false;

  @override
  void initState() {
    super.initState();
    _settings.load();
    _settings.addListener(_changed);
    localeNotifier.addListener(_changed);
    _loadServer();
  }

  Future<void> _loadServer() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _serverFailed = false);
    try {
      final got = await api.notifySettings();
      if (mounted) setState(() => _server = got);
    } catch (_) {
      if (mounted) setState(() => _serverFailed = true);
    }
  }

  /// Applies a change at once and saves it; goes back if the server says no.
  Future<void> _saveServer(ChatServerNotify next) async {
    final api = widget.api;
    final before = _server;
    if (api == null || before == null) return;
    setState(() => _server = next);
    try {
      final saved = await api.saveNotifySettings(next);
      if (mounted) setState(() => _server = saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _server = before);
      final s = S.of(context);
      showNativeAlert(
        context: context,
        title: s.notifPushError,
        actions: [
          AlertAction(
            title: 'OK',
            style: AlertActionStyle.primary,
            onPressed: () {},
          ),
        ],
      );
    }
  }

  /// One kind of chat (personal / group): notifications, text, sound.
  Widget _serverGroup(S s, {required bool group}) {
    final v = _server!;
    final enabled = group ? v.groupEnabled : v.privateEnabled;
    final preview = group ? v.groupPreview : v.privatePreview;
    final sound = group ? v.groupSound : v.privateSound;

    Widget row({
      required IconData icon,
      required Color color,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
      bool dim = false,
    }) {
      final r = SettingsRow(
        icon: icon,
        color: color,
        title: title,
        onTap: dim ? null : () => onChanged(!value),
        trailing: AdaptiveSwitch(
          value: value,
          onChanged: dim ? null : onChanged,
          activeColor: AppColors.brandOrange,
        ),
      );
      return dim ? Opacity(opacity: 0.4, child: IgnorePointer(child: r)) : r;
    }

    return SettingsGroup(
      children: [
        row(
          icon: Icons.notifications_rounded,
          color: const Color(0xFFFF3B30),
          title: s.notifAlert,
          value: enabled,
          onChanged: (x) => _saveServer(v.with_(group: group, enabled: x)),
        ),
        row(
          icon: Icons.visibility_rounded,
          color: SettingsColors.blue,
          title: s.notifShowText,
          value: preview,
          dim: !enabled,
          onChanged: (x) => _saveServer(v.with_(group: group, preview: x)),
        ),
        // A silent notification on Android needs the app's own notifications
        // (not there yet): the switch is only offered where it works.
        if (Platform.isIOS)
          row(
            icon: Icons.volume_up_rounded,
            color: SettingsColors.green,
            title: s.notifPushSound,
            value: sound,
            dim: !enabled,
            onChanged: (x) => _saveServer(v.with_(group: group, sound: x)),
          ),
      ],
    );
  }

  Widget _serverSection(S s) {
    if (widget.api == null) return const SizedBox.shrink();
    if (_server == null) {
      if (!_serverFailed) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            Text(
              s.notifPushLoadError,
              style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
            ),
            TextButton(onPressed: _loadServer, child: Text(s.devicesRetry)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _caption(s.notifPrivateChats),
        _serverGroup(s, group: false),
        const SizedBox(height: 24),
        _caption(s.notifGroups),
        _serverGroup(s, group: true),
        _footer(s.notifPushHint),
        const SizedBox(height: 24),
      ],
    );
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
          _serverSection(s),
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
