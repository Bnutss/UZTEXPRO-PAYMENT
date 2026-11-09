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

/// "Devices", as in Telegram: this phone, a button that ends every other
/// session, and the active sessions with the model, the app and system version,
/// the address and the last time each was seen. A session is ended by a swipe
/// or from its details; the phone then signs out.
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
      if (mounted && _devices == null) setState(() => _failed = true);
    }
  }

  void _error(String text) {
    showNativeAlert(
      context: context,
      title: text,
      actions: [
        AlertAction(
          title: 'OK',
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
  }

  Future<void> _terminate(ChatDeviceInfo d) async {
    final s = S.of(context);
    try {
      await widget.api.deleteDevice(d.id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) _error(s.devicesRemoveError);
    }
  }

  /// The sheet that opens from a row: what is known of the session, and "End
  /// session".
  void _details(S s, ChatDeviceInfo d) {
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: d.title,
      message: [
        if (d.software.isNotEmpty) d.software,
        if (d.ip.isNotEmpty) s.devicesIp(d.ip),
        s.devicesActive(_date(s, d.updatedAt)),
      ].join('\n'),
      actions: [
        AlertAction(
          title: s.devicesRemove,
          style: AlertActionStyle.destructive,
          onPressed: () => _confirmTerminate(s, d),
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  void _confirmTerminate(S s, ChatDeviceInfo d) {
    showNativeAlert(
      context: context,
      title: s.devicesRemoveTitle,
      message: s.devicesRemoveMessage(d.title),
      actions: [
        AlertAction(
          title: s.devicesRemove,
          style: AlertActionStyle.destructive,
          onPressed: () => _terminate(d),
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  void _confirmTerminateAll(S s) {
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: s.devicesTerminateAllTitle,
      message: s.devicesTerminateAllMessage,
      actions: [
        AlertAction(
          title: s.devicesTerminateAll,
          style: AlertActionStyle.destructive,
          onPressed: () async {
            try {
              await widget.api.terminateOtherDevices();
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

  Widget _icon(ChatDeviceInfo d) {
    final ios = d.platform == 'ios';
    return SettingsIconTile(
      icon: ios ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
      color: ios ? SettingsColors.blue : SettingsColors.green,
    );
  }

  /// This phone: the model, the app and the system, and that it is online.
  Widget _thisDevice(S s, ChatDeviceInfo d) {
    return SettingsRow(
      leading: _icon(d),
      title: d.title,
      subtitle: [
        if (d.software.isNotEmpty) d.software,
        s.devicesOnline,
      ].join(' · '),
    );
  }

  Widget _session(S s, ChatDeviceInfo d) {
    final row = SettingsRow(
      leading: _icon(d),
      title: d.title,
      subtitle: [
        if (d.software.isNotEmpty) d.software,
        [
          if (d.ip.isNotEmpty) s.devicesIp(d.ip),
          _date(s, d.updatedAt),
        ].join(' · '),
      ].join('\n'),
      onTap: () => _details(s, d),
    );
    // A swipe to the left ends the session (after the same question).
    return Dismissible(
      key: ValueKey('device-${d.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _confirmTerminate(s, d);
        return false; // the row goes when the list reloads, not before
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFFF3B30),
        child: Text(
          s.devicesSwipe,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Container(color: Colors.white, child: row),
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
              SettingsGroup(
                children: [for (final d in current) _thisDevice(s, d)],
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _confirmTerminateAll(s),
                        child: Container(
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Text(
                            s.devicesTerminateAll,
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
              const SizedBox(height: 24),
            ],
            if (others.isNotEmpty) ...[
              _caption(s.devicesOthers),
              SettingsGroup(children: [for (final d in others) _session(s, d)]),
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
