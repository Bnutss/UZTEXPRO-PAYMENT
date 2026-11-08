import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_group_picker.dart' show GroupDraft;
import 'chat_models.dart';

/// "New group" / "Add members" on Android: the same two steps as the native
/// iOS sheets, in Material. Step one picks the people (chips on top, search,
/// the list with statuses), step two sets the photo and the name.
///
/// Returns the draft, or null when it was closed.
Future<GroupDraft?> pickGroupMembersMaterial(
  BuildContext context,
  List<ChatUser> contacts, {
  bool add = false,
}) => Navigator.of(context).push<GroupDraft>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _GroupFlowPage(contacts: contacts, add: add),
  ),
);

class _GroupFlowPage extends StatefulWidget {
  const _GroupFlowPage({required this.contacts, required this.add});

  final List<ChatUser> contacts;
  final bool add;

  @override
  State<_GroupFlowPage> createState() => _GroupFlowPageState();
}

class _GroupFlowPageState extends State<_GroupFlowPage> {
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF6D6D72);
  static const _line = Color(0xFFE6E6EA);

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _name = TextEditingController();
  final _selected = <int>[];
  bool _searching = false;
  bool _namingStep = false;
  Uint8List? _photo;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _name.dispose();
    super.dispose();
  }

  ChatUser _byId(int id) => widget.contacts.firstWhere((u) => u.id == id);

  void _toggle(ChatUser u) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected.contains(u.id) ? _selected.remove(u.id) : _selected.add(u.id);
    });
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
    if (_searching) _searchFocus.requestFocus();
  }

  Future<void> _pickPhoto() async {
    HapticFeedback.selectionClick();
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {}
  }

  void _next() {
    if (_selected.isEmpty) return;
    if (widget.add) {
      Navigator.of(context).pop(GroupDraft(ids: List.of(_selected), name: ''));
      return;
    }
    setState(() {
      _searching = false;
      _search.clear();
      _namingStep = true;
    });
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty || _selected.isEmpty) return;
    Navigator.of(
      context,
    ).pop(GroupDraft(ids: List.of(_selected), name: name, photo: _photo));
  }

  void _back() {
    if (_namingStep) {
      setState(() => _namingStep = false);
    } else if (_searching) {
      _toggleSearch();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final title = widget.add ? s.chatAddMembersTitle : s.chatNewGroup;
    final showFab = _namingStep || _selected.isNotEmpty;
    final canCreate = _name.text.trim().isNotEmpty;
    return PopScope(
      canPop: !_namingStep && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            // Explicit dark ink: the app theme paints bars white.
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: const IconThemeData(color: _ink),
            actionsIconTheme: const IconThemeData(color: _ink),
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _back,
            ),
            titleSpacing: 0,
            title: _searching && !_namingStep
                ? TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 17, color: _ink),
                    cursorColor: AppColors.brandOrange,
                    decoration: InputDecoration(
                      hintText: s.contactsSearchHint,
                      hintStyle: const TextStyle(color: _muted),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      Text(
                        s.chatMembersCount(_selected.length),
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
            actions: [
              if (!_namingStep)
                IconButton(
                  tooltip: s.contactsSearchHint,
                  icon: Icon(
                    _searching ? Icons.close_rounded : Icons.search_rounded,
                  ),
                  onPressed: _toggleSearch,
                ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: _line),
            ),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _namingStep ? _namingBody(s) : _pickBody(s),
          ),
          floatingActionButton: AnimatedScale(
            scale: showFab ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: FloatingActionButton(
              heroTag: null,
              tooltip: _namingStep
                  ? s.chatCreate
                  : (widget.add ? s.chatAddMembers : s.chatNext),
              onPressed: showFab && (!_namingStep || canCreate)
                  ? (_namingStep ? _create : _next)
                  : null,
              backgroundColor: _namingStep && !canCreate
                  ? const Color(0xFFBDBDC2)
                  : AppColors.brandOrange,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: Icon(
                _namingStep
                    ? Icons.check_rounded
                    : (widget.add
                          ? Icons.person_add_alt_1_rounded
                          : Icons.arrow_forward_rounded),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── step one: the people ──────────────────────────────────────────────

  Widget _pickBody(S s) {
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
    return Column(
      key: const ValueKey('pick'),
      children: [
        // Picked people: pills that wrap, tap to take one out (as in Telegram).
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _selected.isEmpty
              ? const SizedBox(width: double.infinity)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 132),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in _selected)
                            _Pill(
                              user: _byId(id),
                              onRemove: () => _toggle(_byId(id)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    s.chatNothingFound,
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _PersonRow(
                    user: shown[i],
                    selected: _selected.contains(shown[i].id),
                    status: shown[i].online
                        ? s.chatOnline
                        : s.chatLastSeen(shown[i].lastSeen),
                    onTap: () => _toggle(shown[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ── step two: photo and name ──────────────────────────────────────────

  Widget _namingBody(S s) {
    final members = _selected.map(_byId).toList();
    return ListView(
      key: const ValueKey('name'),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: s.chatChangePhoto,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.brandOrange,
                          backgroundImage: _photo == null
                              ? null
                              : MemoryImage(_photo!),
                          child: _photo == null
                              ? const Icon(
                                  Icons.photo_camera_rounded,
                                  size: 28,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        if (_photo != null)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: GestureDetector(
                              onTap: () => setState(() => _photo = null),
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 120,
                  style: const TextStyle(fontSize: 18, color: _ink),
                  cursorColor: AppColors.brandOrange,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _create(),
                  decoration: InputDecoration(
                    hintText: s.chatGroupName,
                    hintStyle: const TextStyle(color: _muted),
                    counterText: '',
                    // The app theme fills inputs with a grey box: not here.
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: _line, width: 1.5),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: _line, width: 1.5),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.brandOrange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 10, color: AppColors.groupedBackground),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            s.chatMembersCount(members.length),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.brandOrange,
            ),
          ),
        ),
        for (final u in members)
          _PersonRow(
            user: u,
            selected: false,
            showCheck: false,
            status: u.online ? s.chatOnline : s.chatLastSeen(u.lastSeen),
            onTap: () {},
          ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.user,
    required this.selected,
    required this.status,
    required this.onTap,
    this.showCheck = true,
  });

  final ChatUser user;
  final bool selected;
  final bool showCheck;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: user.surnameName,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (showCheck) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.brandOrange
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.brandOrange
                          : const Color(0xFFB8B8BE),
                      width: 1.8,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
              ],
              PersonAvatar(
                name: user.name,
                size: 48,
                sources: user.photo == null
                    ? const []
                    : [PhotoSource(user.photo!)],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.surnameName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: user.online
                            ? AppColors.brandOrange
                            : const Color(0xFF6D6D72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A picked person above the list: avatar + first name + a cross; a tap takes
/// them out. At least 40dp tall, like Telegram's.
class _Pill extends StatelessWidget {
  const _Pill({required this.user, required this.onRemove});

  final ChatUser user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: user.surnameName,
    child: InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(
              name: user.name,
              size: 32,
              sources: user.photo == null
                  ? const []
                  : [PhotoSource(user.photo!)],
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                user.name.trim().split(RegExp(r'\s+')).take(2).join(' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111111),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6D6D72)),
          ],
        ),
      ),
    ),
  );
}
