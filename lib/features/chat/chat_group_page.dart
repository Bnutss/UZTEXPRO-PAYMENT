import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/routeless_alert.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_api.dart';
import 'chat_group_picker.dart';
import 'chat_models.dart';
import 'chat_socket.dart';
import 'chat_thread_controller.dart';
import 'chat_widgets.dart';

/// The group's card, as the person's one: the photo, the title, how many
/// people, action tiles (sound / add / edit / leave) and the members.
class ChatGroupPage extends StatefulWidget {
  const ChatGroupPage({
    super.key,
    required this.controller,
    required this.api,
    required this.link,
    required this.statusOf,
    this.onChanged,
  });

  final ChatThreadController controller;
  final ChatRest api;
  final ChatLink link;
  final String Function() statusOf;

  /// Something changed that the chat list should pick up.
  final VoidCallback? onChanged;

  @override
  State<ChatGroupPage> createState() => _ChatGroupPageState();
}

class _ChatGroupPageState extends State<ChatGroupPage> {
  static const _bg = Color(0xFFF2F2F7);
  static const _blue = Color(0xFF3478F6);
  static const _red = Color(0xFFFF3B30);

  ChatThreadController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.reloadGroup();
  }

  void _fail() {
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.chatActionFailed)));
  }

  Future<void> _run(Future<bool> Function() action) async {
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      widget.onChanged?.call();
    } else {
      _fail();
    }
  }

  // ── actions ──────────────────────────────────────────────────────────

  Future<void> _toggleMute() async {
    HapticFeedback.selectionClick();
    await _c.toggleMuted();
    widget.onChanged?.call();
  }

  Future<void> _rename() async {
    final s = S.of(context);
    HapticFeedback.selectionClick();
    final name = await AdaptiveAlertDialog.inputShow(
      context: context,
      title: s.chatRename,
      input: AdaptiveAlertDialogInput(
        placeholder: s.chatGroupName,
        initialValue: _c.peer.name,
        maxLength: 120,
      ),
      actions: [
        AlertAction(
          title: s.cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: s.save,
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
    final title = name?.trim() ?? '';
    if (title.isEmpty || title == _c.group?.peer.name || !mounted) return;
    await _run(() => _c.renameGroup(title));
  }

  Future<void> _photo() async {
    final s = S.of(context);
    HapticFeedback.selectionClick();
    final hasPhoto = (_c.group?.peer.photo ?? '').isNotEmpty;
    await showNativeAlert(
      context: context,
      title: s.chatChangePhoto,
      actions: [
        AlertAction(
          title: s.cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        if (hasPhoto)
          AlertAction(
            title: s.chatRemovePhoto,
            style: AlertActionStyle.destructive,
            onPressed: () => _run(_c.removeGroupPhoto),
          ),
        AlertAction(
          title: s.chatChangePhoto,
          style: AlertActionStyle.primary,
          onPressed: () async {
            final bytes = await pickGalleryPhoto();
            if (bytes != null && mounted) {
              await _run(() => _c.changeGroupPhoto(bytes));
            }
          },
        ),
      ],
    );
  }

  Future<void> _add() async {
    HapticFeedback.selectionClick();
    final List<ChatUser> all;
    try {
      all = await widget.api.contacts();
    } catch (_) {
      return _fail();
    }
    if (!mounted) return;
    final inGroup = {
      for (final m in _c.group?.members ?? const <ChatUser>[]) m.id,
    };
    final candidates = [
      for (final u in all)
        if (!inGroup.contains(u.id)) u,
    ];
    final draft = await pickGroupMembers(context, candidates, add: true);
    if (draft == null || draft.ids.isEmpty || !mounted) return;
    await _run(() => _c.addMembers(draft.ids));
  }

  void _leave() {
    final s = S.of(context);
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: s.chatLeaveTitle,
      actions: [
        AlertAction(
          title: s.cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: s.chatLeaveConfirm,
          style: AlertActionStyle.destructive,
          onPressed: () => _run(_c.leaveGroup),
        ),
      ],
    );
  }

  void _deleteGroup() {
    final s = S.of(context);
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: s.chatDeleteGroupTitle,
      actions: [
        AlertAction(
          title: s.cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: s.chatDeleteGroup,
          style: AlertActionStyle.destructive,
          onPressed: () => _run(_c.deleteGroup),
        ),
      ],
    );
  }

  /// A tap on a member (admins): make / unmake an admin, remove.
  void _memberMenu(ChatUser m) {
    final s = S.of(context);
    final me = widget.api.myId;
    if (!_c.isAdmin || m.id == me || m.isOwner) return;
    // An admin cannot touch another admin: only the owner can.
    final iAmOwner = _c.group?.myRole == 'owner';
    if (m.isAdmin && !iAmOwner) return;
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: m.name,
      actions: [
        AlertAction(
          title: s.cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        if (iAmOwner)
          AlertAction(
            title: m.isAdmin ? s.chatRemoveAdmin : s.chatMakeAdmin,
            style: AlertActionStyle.primary,
            onPressed: () =>
                _run(() => _c.setRole(m.id, m.isAdmin ? 'member' : 'admin')),
          ),
        AlertAction(
          title: s.chatRemoveFromGroup,
          style: AlertActionStyle.destructive,
          onPressed: () => _run(() => _c.removeMember(m.id)),
        ),
      ],
    );
  }

  // ── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: Listenable.merge([_c, widget.link.connected]),
      builder: (context, _) {
        // Left or deleted: the chat screen under this card closes everything
        // (it pops this card too), so nothing is popped from here.
        final g = _c.group;
        final admin = _c.isAdmin;
        final title = g?.peer.name ?? _c.peer.name;
        final photo = g?.peer.photo ?? _c.peer.photo;
        final members = g?.members ?? const <ChatUser>[];
        return Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(16, top + 20, 16, 32),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: admin ? _photo : null,
                      child: ClipOval(
                        child: PersonAvatar(
                          name: title,
                          size: 100,
                          sources: photo == null || photo.isEmpty
                              ? const []
                              : [PhotoSource(photo)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kChatInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.statusOf(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _Tile(
                          icon: _c.muted
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_rounded,
                          label: _c.muted ? s.chatSoundOff : s.chatSound,
                          onTap: _toggleMute,
                        ),
                      ),
                      if (admin) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Tile(
                            icon: Icons.person_add_alt_1_rounded,
                            label: s.chatAddShort,
                            onTap: _add,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Tile(
                            icon: Icons.edit_rounded,
                            label: s.chatEditGroup,
                            onTap: _rename,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Tile(
                          icon: Icons.logout_rounded,
                          label: s.chatLeave,
                          color: _red,
                          onTap: _leave,
                        ),
                      ),
                    ],
                  ),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Text(
                        s.chatMembers.toUpperCase(),
                        style: const TextStyle(fontSize: 13, color: kChatMuted),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < members.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 68,
                                color: Color(0xFFE5E5EA),
                              ),
                            _MemberRow(
                              user: members[i],
                              isMe: members[i].id == widget.api.myId,
                              roleLabel: members[i].isOwner
                                  ? s.chatRoleOwner
                                  : members[i].role == 'admin'
                                  ? s.chatRoleAdmin
                                  : null,
                              status: members[i].online
                                  ? s.chatOnline
                                  : s.chatLastSeen(members[i].lastSeen),
                              youLabel: s.chatYou,
                              onTap: () => _memberMenu(members[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_c.group?.myRole == 'owner') ...[
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _deleteGroup,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          s.chatDeleteGroup,
                          style: const TextStyle(fontSize: 17, color: _red),
                        ),
                      ),
                    ),
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
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _ChatGroupPageState._blue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.user,
    required this.isMe,
    required this.roleLabel,
    required this.status,
    required this.youLabel,
    required this.onTap,
  });

  final ChatUser user;
  final bool isMe;
  final String? roleLabel;
  final String status;
  final String youLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            ClipOval(
              child: PersonAvatar(
                name: user.name,
                size: 44,
                sources: user.photo == null
                    ? const []
                    : [PhotoSource(user.photo!)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${user.name} ($youLabel)' : user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: kChatInk),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: kChatMuted),
                  ),
                ],
              ),
            ),
            if (roleLabel != null)
              Text(
                roleLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.brandOrange,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
