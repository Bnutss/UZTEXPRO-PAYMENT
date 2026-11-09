import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uztexpro_payment/main.dart' show API;

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/fade_route.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/glass_text_button.dart';
import '../../core/widgets/ui_blocks.dart';
import '../chat/chat_api.dart' show ChatRest;
import '../chat/chat_models.dart';
import '../chat/chat_my_photo.dart';
import '../chat/chat_widgets.dart';
import 'chat_edit_profile_page.dart';
import 'island_pull_avatar.dart';

/// "My Profile", as in Telegram: my own card, a big round photo, the name and
/// "online", and white cards with the phone, @username, birthday, e-mail and
/// the work data. "Edit" (top right) opens the editor; a row tap copies it.
/// The phone, e-mail, birthday and picture are kept by the chat server, apart from
/// the employee's HR card.
class ChatMyProfilePage extends StatefulWidget {
  const ChatMyProfilePage({
    super.key,
    required this.api,
    required this.name,
    required this.email,
    this.photoUrl,
    this.token = '',
  });

  /// The chat's server; null when the chat is not connected (nothing to load
  /// or edit then).
  final ChatRest? api;

  /// What the settings screen already knows: shown at once, then filled in.
  final String name;
  final String email;
  final String? photoUrl;
  final String token;

  static const _bg = Color(0xFFF2F2F7);
  static const _blue = Color(0xFF3478F6);

  @override
  State<ChatMyProfilePage> createState() => _ChatMyProfilePageState();
}

class _ChatMyProfilePageState extends State<ChatMyProfilePage> {
  ChatMyProfile? _p;
  String? _photo;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _photo = widget.photoUrl;
    _token = widget.token;
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

  static String? _resolve(String? url) {
    if (url == null || url.isEmpty) return null;
    final origin = Uri.parse(API).origin;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$origin$url';
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final p = await api.myProfile();
      if (!mounted) return;
      final photo = _resolve(p.photo);
      setState(() {
        _p = p;
        if (photo != null) {
          _photo = photo;
          _token = api.apiToken;
        }
      });
    } catch (_) {
      // No network: what the settings knew stays.
    }
  }

  Future<void> _edit() async {
    final api = widget.api;
    if (api == null) return;
    // The card did not load yet (slow network): try once more, and if it still
    // does not come, edit what is known - saving then reports the problem.
    if (_p == null) await _load();
    if (!mounted) return;
    final p = _p ?? ChatMyProfile(name: widget.name, email: widget.email);
    final saved = await Navigator.push<ChatMyProfile>(
      context,
      InstantRoute(
        builder: (_) =>
            ChatEditProfilePage(api: api, profile: p, photoUrl: _photo),
      ),
    );
    if (saved != null && mounted) {
      final photo = _resolve(saved.photo);
      ChatMyPhoto.invalidate();
      setState(() {
        _p = saved;
        // The picture was dropped or changed: show what the server has now.
        _photo = photo;
        _token = api.apiToken;
      });
    }
  }

  void _copy(String value) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: value));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(S.of(context).myProfileCopied),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final p = _p;
    final name = (p?.name.isNotEmpty ?? false)
        ? p!.name
        : (widget.name.isNotEmpty ? widget.name : 'UZTEXPRO');
    final email = (p?.email.isNotEmpty ?? false) ? p!.email : widget.email;
    final rows = <_InfoRow>[
      if (p != null && p.phone.isNotEmpty)
        _InfoRow(
          s.attendancePhone,
          p.phone,
          color: ChatMyProfilePage._blue,
          onTap: () => _copy(p.phone),
        ),
      if (p != null && p.username.isNotEmpty)
        _InfoRow(
          s.myProfileUsername,
          '@${p.username}',
          onTap: () => _copy(p.username),
        ),
      if (p?.birthday != null)
        _InfoRow(s.myProfileBirthday, _date(p!.birthday!)),
      if (email.isNotEmpty)
        _InfoRow(s.myProfileEmail, email, onTap: () => _copy(email)),
    ];
    final work = <_InfoRow>[
      if (p != null && p.department.isNotEmpty)
        _InfoRow(s.attendanceDepartment, p.department),
      if (p != null && p.position.isNotEmpty)
        _InfoRow(s.attendancePosition, p.position),
      if (p != null && p.factory.isNotEmpty)
        _InfoRow(s.myProfileFactory, p.factory),
      if (p != null && p.reportCard.isNotEmpty)
        _InfoRow(s.attendanceTabel, p.reportCard),
    ];

    return Scaffold(
      backgroundColor: ChatMyProfilePage._bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              IslandPullAvatar.profileAvatarTop(context),
              16,
              32,
            ),
            children: [
              Center(
                child: ClipOval(
                  child: PersonAvatar(
                    name: name,
                    size: IslandPullAvatar.avatarSize,
                    sources: _photo == null
                        ? const []
                        : [
                            PhotoSource(
                              _photo!,
                              headers: {'Authorization': 'Bearer $_token'},
                            ),
                          ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.27,
                  color: kChatInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.myProfileOnline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.brandOrange,
                ),
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 24),
                _InfoCard(rows: rows),
              ],
              if (work.isNotEmpty) ...[
                const SizedBox(height: 16),
                _InfoCard(rows: work),
              ],
            ],
          ),
          Positioned(
            top: top,
            left: 0,
            width: 58,
            height: kFadingHeaderRowHeight,
            child: const AdaptiveBackButton(),
          ),
          if (widget.api != null)
            Positioned(
              top: top,
              right: 0,
              height: kFadingHeaderRowHeight,
              child: GlassTextButton(label: s.myProfileEdit, onPressed: _edit),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFE5E5EA)),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.color, this.onTap});

  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: kChatMuted),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(fontSize: 17, color: color ?? kChatInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
