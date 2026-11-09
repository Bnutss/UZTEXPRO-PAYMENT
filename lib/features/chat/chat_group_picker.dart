import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_strings.dart';
import 'chat_group_android.dart';
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
  // Android (and iOS without the native sheet): the Material two-step flow.
  return pickGroupMembersMaterial(context, contacts, add: add);
}

/// The system photo picker (the gallery); JPEG bytes, or null when cancelled.
Future<Uint8List?> pickGalleryPhoto(
  BuildContext context, {
  int maxSide = 1024,
}) async {
  if (!Platform.isIOS) {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: maxSide.toDouble(),
        maxHeight: maxSide.toDouble(),
        imageQuality: 85,
      );
      return f == null ? null : await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }
  final s = S.of(context);
  try {
    final res = await const MethodChannel('uztexpro/native_sheet')
        .invokeMapMethod<String, dynamic>('pickPhoto', <String, dynamic>{
          'recents': s.chatRecents,
          'preparing': s.chatPreparing,
          'denied': s.chatPhotosDenied,
          'settings': s.chatOpenSettings,
        });
    return res?['photo'] as Uint8List?;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
