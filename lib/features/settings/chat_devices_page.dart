import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show AlertAction, AlertActionStyle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/routeless_alert.dart';
import '../chat/chat_api.dart';
import '../chat/chat_models.dart';
import '../chat/chat_push.dart' show ChatPushService;
import 'settings_rows.dart';

/// "Devices": my phones that get push notifications, with a way to
/// disconnect the ones I no longer use.
class ChatDevicesPage extends StatefulWidget {
  const ChatDevicesPage({super.key, required this.api});

  final ChatRest api;

  @override
  State<ChatDevicesPage> createState() => _ChatDevicesPageState();
}

class _ChatDevicesPageState extends State<ChatDevicesPage> {
  List<ChatDeviceInfo>? _devices;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_changed);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final list = await widget.api.devices(
        current: ChatPushService.lastToken,
      );
      if (mounted) setState(() => _devices = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _error(String text) {
    showNativeAlert(
      context: context,
      title: text,
      actions: [
        AlertAction(title: 'OK', style: AlertActionStyle.primary, onPressed: () {}),
      ],
    );
  }

  void _confirmRemove(S s, ChatDeviceInfo d) {
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: s.devicesRemoveTitle,
      message: s.devicesRemoveMessage(_nameOf(s, d)),
      actions: [
        AlertAction(
          title: s.devicesRemove,
          style: AlertActionStyle.destructive,
          onPressed: () async {
            try {
              await widget.api.deleteDevice(d.id);
              if (mounted) await _load();
            } catch (_) {
              if (mounted) _error(s.devicesRemoveError);
            }
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

  static String _nameOf(S s, ChatDeviceInfo d) {
    if (d.name.isNotEmpty) return d.name;
    return switch (d.platform) {
      'ios' => 'iPhone',
      'android' => 'Android',
      _ => s.devicesUnknown,
    };
  }

  String _date(S s, DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
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

  Widget _row(S s, ChatDeviceInfo d) {
    final ios = d.platform == 'ios';
    return SettingsRow(
      icon: ios ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
      color: ios ? SettingsColors.blue : SettingsColors.green,
      title: _nameOf(s, d),
      subtitle: d.current
          ? s.devicesActive(_date(s, d.updatedAt))
          : '${s.devicesAdded(_date(s, d.createdAt))}\n${s.devicesActive(_date(s, d.updatedAt))}',
      onTap: d.current ? null : () => _confirmRemove(s, d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final list = _devices;
    final current = list?.where((d) => d.current).toList() ?? const [];
    final others = list?.where((d) => !d.current).toList() ?? const [];

    return FadingHeaderScaffold(
      title: s.devicesTitle,
      background: AppColors.groupedBackground,
      body: (context, topInset) => ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 40),
        children: [
          if (list == null && !_failed)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_failed && list == null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Text(
                    s.devicesLoadError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8A8A8E),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: Text(s.devicesRetry)),
                ],
              ),
            )
          else ...[
            if (current.isNotEmpty) ...[
              _caption(s.devicesThis),
              SettingsGroup(children: [for (final d in current) _row(s, d)]),
              const SizedBox(height: 24),
            ],
            if (others.isNotEmpty) ...[
              _caption(s.devicesOthers),
              SettingsGroup(children: [for (final d in others) _row(s, d)]),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                s.devicesHint,
                style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
