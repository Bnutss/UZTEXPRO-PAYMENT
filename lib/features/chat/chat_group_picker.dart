import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'chat_models.dart';

/// "New group", step one: pick the people. On iOS a native sheet that opens
/// almost to the top (system search field, back button, "Next"); elsewhere a
/// Flutter sheet with the same content.
///
/// What the person made in the sheet: the people, the name and the photo.
class GroupDraft {
  const GroupDraft({required this.ids, required this.name, this.photo});

  final List<int> ids;
  final String name;

  /// JPEG bytes of the photo picked from the gallery, if any.
  final Uint8List? photo;
}

/// What was changed in the "Edit group" sheet.
class GroupEdit {
  const GroupEdit({required this.name, this.photo, this.removePhoto = false});

  final String name;
  final Uint8List? photo;
  final bool removePhoto;
}

/// "Edit group": the card of the creation's second step (photo + name) in a
/// native sheet. Null when it was closed, or when there is no native sheet.
Future<GroupEdit?> editGroupNative(
  BuildContext context, {
  required String name,
  String? photo,
  List<ChatUser> members = const [],
}) async {
  if (!Platform.isIOS) return null;
  final s = S.of(context);
  try {
    final res = await const MethodChannel('uztexpro/native_sheet')
        .invokeMapMethod<String, dynamic>('editGroup', {
          'title': s.chatEditGroup,
          'save': s.save,
          'removePhoto': s.chatRemovePhoto,
          'namePlaceholder': s.chatGroupName,
          'name': name,
          'photo': photo ?? '',
          'membersTitle': s.chatMembers,
          'members': [
            for (final m in members)
              {
                'id': m.id,
                'name': m.surnameName,
                'status': m.online ? s.chatOnline : s.chatLastSeen(m.lastSeen),
                'photo': m.photo ?? '',
                'role': m.isOwner
                    ? s.chatRoleOwner
                    : m.role == 'admin'
                    ? s.chatRoleAdmin
                    : '',
              },
          ],
        });
    if (res == null) return null;
    return GroupEdit(
      name: (res['name'] as String?) ?? name,
      photo: res['photo'] as Uint8List?,
      removePhoto: res['removePhoto'] == true,
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

/// Returns the draft when "Create" was pressed, null when it was closed.
Future<GroupDraft?> pickGroupMembers(
  BuildContext context,
  List<ChatUser> contacts, {
  bool add = false,
}) async {
  final s = S.of(context);
  if (Platform.isIOS) {
    try {
      final res = await const MethodChannel('uztexpro/native_sheet')
          .invokeMapMethod<String, dynamic>('pickContacts', {
            'title': add ? s.chatAddMembersTitle : s.chatNewGroup,
            'searchPrompt': s.contactsSearchHint,
            'next': add ? s.chatAddMembers : s.chatNext,
            'addMode': add,
            'create': s.chatCreate,
            'namePlaceholder': s.chatGroupName,
            'contacts': [
              for (final u in contacts)
                {
                  'id': u.id,
                  'name': u.name,
                  'subtitle': u.subtitle,
                  // Under the name, like in Telegram: online / last seen.
                  'status': u.online
                      ? s.chatOnline
                      : s.chatLastSeen(u.lastSeen),
                  'photo': u.photo ?? '',
                },
            ],
          });
      final ids = res?['ids'] as List?;
      if (ids == null) return null;
      return GroupDraft(
        ids: ids.map((e) => (e as num).toInt()).toList(),
        name: (res?['name'] as String?) ?? '',
        photo: res?['photo'] as Uint8List?,
      );
    } on MissingPluginException {
      // Fall through to the Flutter sheet.
    } on PlatformException {
      // Fall through to the Flutter sheet.
    }
  }
  if (!context.mounted) return null;
  final ids = await showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PickerSheet(contacts: contacts),
  );
  // Android: only the people for now (the name step is iOS's native sheet).
  return ids == null ? null : GroupDraft(ids: ids, name: '');
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.contacts});

  final List<ChatUser> contacts;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _search = TextEditingController();
  final _selected = <int>[];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.contacts
        : widget.contacts
              .where(
                (u) =>
                    u.name.toLowerCase().contains(q) ||
                    u.subtitle.toLowerCase().contains(q),
              )
              .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
                Expanded(
                  child: Text(
                    s.chatNewGroup,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () =>
                            Navigator.of(context).pop(List<int>.of(_selected)),
                  child: Text(s.chatNext),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: s.contactsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final u = shown[i];
                final on = _selected.contains(u.id);
                return ListTile(
                  title: Text(u.name, maxLines: 1),
                  subtitle: u.subtitle.isEmpty ? null : Text(u.subtitle),
                  trailing: Icon(
                    on ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: on ? AppColors.brandOrange : Colors.grey,
                  ),
                  onTap: () => setState(
                    () => on ? _selected.remove(u.id) : _selected.add(u.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The system photo picker (the gallery); JPEG bytes, or null when cancelled.
Future<Uint8List?> pickGalleryPhoto() async {
  if (!Platform.isIOS) return null;
  try {
    final res = await const MethodChannel(
      'uztexpro/native_sheet',
    ).invokeMapMethod<String, dynamic>('pickPhoto', <String, dynamic>{});
    return res?['photo'] as Uint8List?;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
