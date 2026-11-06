import '../../core/localization/app_strings.dart';
import 'chat_models.dart';

/// The text of a service line of a group ("X added Y"), in the app's language,
/// with "You" for me. Falls back to the server's own line.
String chatSystemText(ChatMessage m, S s, int? myId) {
  final p = m.payload ?? const <String, dynamic>{};
  final actorId = (p['actor'] as num?)?.toInt();
  final userId = (p['user'] as num?)?.toInt();
  return s.chatSystemLine(
    event: m.event,
    actor: (p['actor_name'] as String?) ?? '',
    actorIsMe: myId != null && actorId == myId,
    user: (p['user_name'] as String?) ?? '',
    userIsMe: myId != null && userId == myId,
    title: (p['title'] as String?) ?? '',
    fallback: m.text,
  );
}
