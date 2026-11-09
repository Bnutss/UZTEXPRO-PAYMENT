import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show AdaptiveSwitch, AlertAction, AlertActionStyle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fade_route.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/routeless_alert.dart';
import '../chat/chat_data_settings.dart';
import '../chat/chat_media.dart' show ChatMediaStore, formatFileSize;
import 'settings_rows.dart';

String keepLabel(S s, ChatKeepMedia k) => switch (k) {
  ChatKeepMedia.forever => s.dataKeepForever,
  ChatKeepMedia.days3 => s.dataKeep3Days,
  ChatKeepMedia.week => s.dataKeepWeek,
  ChatKeepMedia.month => s.dataKeepMonth,
};

/// "Data and storage": which files are downloaded by themselves, how long the
/// saved ones are kept, and how much they take.
class ChatDataPage extends StatefulWidget {
  const ChatDataPage({super.key});

  @override
  State<ChatDataPage> createState() => _ChatDataPageState();
}

class _ChatDataPageState extends State<ChatDataPage> {
  final _settings = ChatDataSettings.instance;
  int? _bytes;

  @override
  void initState() {
    super.initState();
    _settings.load();
    _settings.addListener(_changed);
    localeNotifier.addListener(_changed);
    _count();
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

  Future<void> _count() async {
    await ChatMediaStore.init();
    final bytes = await ChatMediaStore.usedBytes();
    if (mounted) setState(() => _bytes = bytes);
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

  Widget _autoGroup(S s, {required bool onWifi}) {
    final table = onWifi ? _settings.wifi : _settings.mobile;
    Widget row(String kind, IconData icon, Color color, String title) {
      final on = table[kind] ?? false;
      void set(bool v) => _settings.setAuto(onWifi: onWifi, kind: kind, on: v);
      return SettingsRow(
        icon: icon,
        color: color,
        title: title,
        onTap: () => set(!on),
        trailing: AdaptiveSwitch(
          value: on,
          onChanged: set,
          activeColor: AppColors.brandOrange,
        ),
      );
    }

    return SettingsGroup(
      children: [
        row('image', Icons.photo_rounded, SettingsColors.blue, s.dataPhotos),
        row(
          'video',
          Icons.videocam_rounded,
          const Color(0xFFFF3B30),
          s.dataVideos,
        ),
        row(
          'file',
          Icons.insert_drive_file_rounded,
          SettingsColors.orange,
          s.dataFiles,
        ),
      ],
    );
  }

  void _pickKeep() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      FadeRoute(
        builder: (_) => _KeepPickerPage(
          current: _settings.keep,
          onPicked: (k) {
            _settings.setKeep(k);
            // A shorter time takes effect at once.
            _settings.pruneMedia().then((_) => _count());
          },
        ),
      ),
    );
  }

  void _confirmClear(S s) {
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: s.chatStorageClearTitle,
      message: s.chatStorageClearMessage,
      actions: [
        AlertAction(
          title: s.chatStorageClear,
          style: AlertActionStyle.destructive,
          onPressed: () async {
            await ChatMediaStore.clear();
            // No toast: the size above simply drops to 0, as in Telegram.
            if (mounted) setState(() => _bytes = 0);
          },
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
    final bytes = _bytes;
    return FadingHeaderScaffold(
      title: s.dataTitle,
      background: AppColors.groupedBackground,
      body: (context, topInset) => ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 40),
        children: [
          _caption(s.dataMobile),
          _autoGroup(s, onWifi: false),
          const SizedBox(height: 24),
          _caption(s.dataWifi),
          _autoGroup(s, onWifi: true),
          _footer(s.dataAutoHint),
          const SizedBox(height: 24),
          _caption(s.dataStorage),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.schedule_rounded,
                color: SettingsColors.indigo,
                title: s.dataKeep,
                value: keepLabel(s, _settings.keep),
                onTap: _pickKeep,
              ),
              SettingsRow(
                icon: Icons.sd_storage_rounded,
                color: SettingsColors.gray,
                title: s.dataUsed,
                value: bytes == null ? '…' : formatFileSize(bytes),
              ),
            ],
          ),
          _footer(s.dataKeepHint),
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _confirmClear(s),
                  child: Container(
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Text(
                      s.dataClear,
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

class _KeepPickerPage extends StatefulWidget {
  const _KeepPickerPage({required this.current, required this.onPicked});

  final ChatKeepMedia current;
  final ValueChanged<ChatKeepMedia> onPicked;

  @override
  State<_KeepPickerPage> createState() => _KeepPickerPageState();
}

class _KeepPickerPageState extends State<_KeepPickerPage> {
  late ChatKeepMedia _current = widget.current;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FadingHeaderScaffold(
      title: s.dataKeep,
      background: AppColors.groupedBackground,
      body: (context, topInset) => ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 40),
        children: [
          SettingsGroup(
            indent: 16,
            children: [
              for (final k in ChatKeepMedia.values)
                SettingsRow(
                  leading: const SizedBox(width: 0),
                  title: keepLabel(s, k),
                  onTap: () {
                    setState(() => _current = k);
                    widget.onPicked(k);
                  },
                  trailing: _current == k
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.brandOrange,
                        )
                      : const SizedBox(width: 24),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              s.dataKeepHint,
              style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
