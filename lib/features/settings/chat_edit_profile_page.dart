import 'dart:io' show Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show AlertAction, AlertActionStyle;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/fade_route.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/glass_text_button.dart';
import '../../core/widgets/routeless_alert.dart';
import '../chat/chat_api.dart';
import '../chat/chat_group_picker.dart' show pickGalleryPhoto;
import '../../core/widgets/ui_blocks.dart';
import '../chat/chat_models.dart';
import '../chat/chat_my_photo.dart';
import '../chat/chat_widgets.dart';
import 'island_pull_avatar.dart';

/// Opens "Edit profile" for my own card (Telegram's "Edit" on the settings
/// screen): loads the card, shows the editor, and tells the rest of the app
/// when something was saved. Null when nothing was saved.
Future<ChatMyProfile?> openEditMyProfile(
  BuildContext context,
  ChatRest api,
) async {
  ChatMyProfile? profile;
  try {
    profile = await api.myProfile();
  } catch (_) {
    return null;
  }
  if (!context.mounted) return null;
  final saved = await Navigator.push<ChatMyProfile>(
    context,
    InstantRoute(
      builder: (_) => ChatEditProfilePage(
        api: api,
        profile: profile!,
        photoUrl: ChatMyPhoto.resolve(profile.photo),
      ),
    ),
  );
  if (saved != null) ChatMyPhoto.invalidate();
  return saved;
}

/// "Edit profile", as in Telegram: the phone, the date of birth and the
/// username (the login, read-only), saved on the chat server ("Done"). Pops with the saved card.
class ChatEditProfilePage extends StatefulWidget {
  const ChatEditProfilePage({
    super.key,
    required this.api,
    required this.profile,
    this.photoUrl,
  });

  final ChatRest api;
  final ChatMyProfile profile;

  /// The current picture, as a link that opens.
  final String? photoUrl;

  @override
  State<ChatEditProfilePage> createState() => _ChatEditProfilePageState();
}

class _ChatEditProfilePageState extends State<ChatEditProfilePage> {
  late final TextEditingController _phone = TextEditingController(
    text: widget.profile.phone,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.profile.email,
  );
  late DateTime? _birthday = widget.profile.birthday;
  // A new picture picked but not saved yet / the picture dropped.
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  void _alert(String text) {
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

  Future<void> _pickBirthday() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final initial = _birthday ?? DateTime(now.year - 25, now.month, now.day);
    if (Platform.isIOS) {
      var picked = initial;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    onPressed: () {
                      setState(() => _birthday = picked);
                      Navigator.pop(ctx);
                    },
                    child: Text(S.of(ctx).myProfileDone),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initial,
                    minimumYear: 1900,
                    maximumDate: now,
                    onDateTimeChanged: (d) => picked = d,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final d = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: now,
      );
      if (d != null && mounted) setState(() => _birthday = d);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final s = S.of(context);
    setState(() => _saving = true);
    try {
      final b = _birthday;
      final saved = await widget.api.saveMyProfile(
        {
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'birthday': b == null
              ? ''
              : '${b.year.toString().padLeft(4, '0')}-'
                    '${b.month.toString().padLeft(2, '0')}-'
                    '${b.day.toString().padLeft(2, '0')}',
        },
        photo: _newPhoto,
        removePhoto: _removePhoto && _newPhoto == null,
      );
      if (mounted) Navigator.pop(context, saved);
    } on ChatApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _alert(switch (e.code) {
        'invalid_phone' => s.myProfileInvalidPhone,
        'invalid_email' => s.myProfileInvalidEmail,
        'invalid_photo' => s.myProfileInvalidPhoto,
        'invalid_birthday' => s.myProfileInvalidBirthday,
        _ => '${s.myProfileSaveError} (${e.statusCode ?? '—'})',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              IslandPullAvatar.profileAvatarTop(context),
              16,
              32,
            ),
            children: [
              _photoBlock(s),
              const SizedBox(height: 20),
              _Card(
                children: [
                  _Field(
                    label: s.attendancePhone,
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.right,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s\-()]'),
                        ),
                      ],
                      decoration: _decoration(s.myProfilePhoneHint),
                      style: _style,
                    ),
                  ),
                  _Field(
                    label: s.myProfileEmail,
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textAlign: TextAlign.right,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: _decoration('name@example.com'),
                      style: _style,
                    ),
                  ),
                  _Field(
                    label: s.myProfileBirthday,
                    onTap: _pickBirthday,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            _birthday == null
                                ? s.myProfileNotSet
                                : _date(_birthday!),
                            textAlign: TextAlign.right,
                            style: _birthday == null
                                ? _style.copyWith(
                                    color: const Color(0xFFC7C7CC),
                                  )
                                : _style,
                          ),
                        ),
                        if (_birthday != null) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => setState(() => _birthday = null),
                            child: const Icon(
                              Icons.cancel_rounded,
                              size: 20,
                              color: Color(0xFFC7C7CC),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                children: [
                  _Field(
                    label: s.myProfileUsername,
                    child: Text(
                      '@${widget.profile.username}',
                      textAlign: TextAlign.right,
                      style: _style.copyWith(color: kChatMuted),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  s.myProfileUsernameHint,
                  style: const TextStyle(fontSize: 13, color: kChatMuted),
                ),
              ),
            ],
          ),
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: kFadingHeaderRowHeight,
            child: Row(
              children: [
                const SizedBox(width: 58, child: AdaptiveBackButton()),
                const Spacer(),
                GlassIconButton(
                  icon: Icons.check_rounded,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final bytes = await pickGalleryPhoto(context);
    if (bytes != null && mounted) {
      setState(() {
        _newPhoto = bytes;
        _removePhoto = false;
      });
    }
  }

  /// The big round picture with "Set New Photo" (and "Remove Photo") under it.
  Widget _photoBlock(S s) {
    final p = widget.profile;
    final hasPhoto =
        _newPhoto != null || (!_removePhoto && widget.photoUrl != null);
    return Column(
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: ClipOval(
            child: _newPhoto != null
                ? Image.memory(
                    _newPhoto!,
                    width: IslandPullAvatar.avatarSize,
                    height: IslandPullAvatar.avatarSize,
                    fit: BoxFit.cover,
                  )
                : PersonAvatar(
                    name: p.name,
                    size: IslandPullAvatar.avatarSize,
                    sources: _removePhoto || widget.photoUrl == null
                        ? const []
                        : [
                            PhotoSource(
                              widget.photoUrl!,
                              headers: {
                                'Authorization':
                                    'Bearer ${widget.api.apiToken}',
                              },
                            ),
                          ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickPhoto,
          child: Text(
            s.myProfileSetPhoto,
            style: const TextStyle(fontSize: 17, color: Color(0xFF3478F6)),
          ),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _newPhoto = null;
              _removePhoto = true;
            }),
            child: Text(
              s.myProfileRemovePhoto,
              style: const TextStyle(fontSize: 15, color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ],
    );
  }

  static const _style = TextStyle(fontSize: 17, color: kChatInk);

  static InputDecoration _decoration(String hint) => InputDecoration(
    isDense: true,
    // The app theme fills text fields gray: here the value sits plainly on the
    // white card.
    filled: false,
    fillColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 17, color: Color(0xFFC7C7CC)),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

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
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFE5E5EA)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 17, color: kChatInk)),
            const SizedBox(width: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
