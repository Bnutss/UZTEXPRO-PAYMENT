import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uztexpro_payment/main.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/search_toggle.dart';
import '../../core/widgets/ui_blocks.dart';
import '../auth/widgets/logo_stroke_loader.dart';

const _kInk = Color(0xFF1C1C1E);
const _kMuted = Color(0xFF8A8A8E);
const _kOnline = Color(0xFF34C759);

class _AttendanceFactory {
  const _AttendanceFactory(this.id, this.name, this.inTerritory);
  final int id;
  final String name;
  final int inTerritory;
}

class _AttendanceEntry {
  const _AttendanceEntry({
    required this.id,
    required this.name,
    required this.position,
    required this.department,
    required this.factory,
    required this.reportCard,
    required this.phone,
    required this.employmentDate,
    required this.photoUrl,
    required this.isIn,
    required this.place,
    required this.time,
    required this.firstIn,
  });

  final int id;
  final String name;
  final String position;
  final String department;
  final String factory;
  final int? reportCard;
  final String phone;
  final DateTime? employmentDate;
  final String? photoUrl;
  final bool isIn;
  final String place;
  final String time;
  final String? firstIn;

  /// Photo links may come back relative or with a plain-http scheme behind
  /// the proxy; iOS blocks cleartext, so always resolve against the API host.
  static String? _resolvePhoto(String? url) {
    if (url == null || url.isEmpty) return null;
    final origin = Uri.parse(API).origin;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$origin$url';
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
  }

  factory _AttendanceEntry.fromJson(Map<String, dynamic> json) =>
      _AttendanceEntry(
        id: (json['employee_id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        position: json['position'] as String? ?? '',
        department: json['department'] as String? ?? '',
        factory: json['factory'] as String? ?? '',
        reportCard: (json['report_card'] as num?)?.toInt(),
        phone: json['phone'] as String? ?? '',
        employmentDate: DateTime.tryParse(
          json['employment_date'] as String? ?? '',
        ),
        photoUrl: _resolvePhoto(json['photo'] as String?),
        isIn: json['access_type'] == 'in',
        place: json['place'] as String? ?? '',
        time: json['time'] as String? ?? '',
        firstIn: json['first_in'] as String?,
      );
}

/// Окно посещаемости: кто сейчас на территории / кто пришёл сегодня.
/// Данные отдаёт `/hr/mobile-attendance/`; доступ (суперпользователь,
/// AI_Permission/full или группа `mobile_hr`) проверяется на бэкенде,
/// а на главной странице блок «На территории» кликабелен только для этих групп.
class AttendancePage extends StatefulWidget {
  final String jwtToken;

  const AttendancePage({super.key, required this.jwtToken});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  bool _onlyToday = false;
  int? _factoryId;

  List<_AttendanceFactory> _factories = [];
  List<_AttendanceEntry> _entries = [];
  int _inTerritory = 0;
  int _todayEnter = 0;
  int _totalEmployees = 0;

  bool _loading = true;
  String? _error;
  int _requestSeq = 0;

  String get _apiToken {
    try {
      return jsonDecode(widget.jwtToken)['token'] as String;
    } catch (_) {
      return widget.jwtToken;
    }
  }

  Map<String, String> get _photoHeaders => {
    'Authorization': 'Bearer $_apiToken',
  };

  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_onLocaleChanged);
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), _load);
    });
    _startAfterTransition();
  }

  void _onLocaleChanged() => setState(() {});

  // Данные, пришедшие посреди fade-перехода маршрута, заставляют мигать
  // app bar при первом открытии — ждём окончания анимации.
  void _startAfterTransition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anim = ModalRoute.of(context)?.animation;
      if (anim == null || anim.isCompleted) {
        _load();
        return;
      }
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          anim.removeStatusListener(listener);
          if (mounted) _load();
        }
      }

      anim.addStatusListener(listener);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchController.clear();
    });
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final s = S.of(context);
    try {
      final params = <String, String>{
        'status': _onlyToday ? 'today' : 'in',
        if (_factoryId != null) 'factory': '$_factoryId',
        if (_searchController.text.trim().isNotEmpty)
          'search': _searchController.text.trim(),
      };
      final res = await http
          .get(
            Uri.parse(
              '$API/hr/mobile-attendance/',
            ).replace(queryParameters: params),
            headers: {'Authorization': 'Bearer $_apiToken'},
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted || seq != _requestSeq) return;
      if (res.statusCode != 200) {
        setState(() {
          _error = res.statusCode == 403
              ? s.attendanceNoAccess
              : s.attendanceLoadError;
          _loading = false;
        });
        return;
      }
      final body =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      setState(() {
        _factories = ((body['factories'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (f) => _AttendanceFactory(
                (f['id'] as num).toInt(),
                f['name'] as String? ?? '',
                (f['in_territory'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList();
        _entries = ((body['results'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => _AttendanceEntry.fromJson(e.cast<String, dynamic>()))
            .toList();
        _inTerritory = (body['in_territory'] as num?)?.toInt() ?? 0;
        _todayEnter = (body['today_enter'] as num?)?.toInt() ?? 0;
        _totalEmployees = (body['total_employees'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = s.attendanceLoadError;
        _loading = false;
      });
    }
  }

  void _openDetail(_AttendanceEntry entry) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EmployeeSheet(entry: entry, photoHeaders: _photoHeaders),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const bg = AppColors.groupedBackground;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          leadingWidth: kBackButtonLeadingWidth,
          leading: const AdaptiveBackButton(),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.attendanceTitle,
                style: const TextStyle(
                  color: _kInk,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topLeft,
                child: _selectedFactory == null
                    ? const SizedBox(width: double.infinity)
                    : Text(
                        _selectedFactory!.name,
                        style: const TextStyle(
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
              ),
            ],
          ),
          centerTitle: false,
          backgroundColor: bg,
          foregroundColor: _kInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            if (_factories.length > 1)
              _FilterButton(
                active: _factoryId != null,
                onPressed: () => _openFactorySheet(s),
              ),
            SearchToggleButton(active: _searching, onPressed: _toggleSearch),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSearchSlot(
                    open: _searching,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSearch(s),
                    ),
                  ),
                  _buildSummary(s),
                  const SizedBox(height: 12),
                  AppSegmentedControl(
                    labels: [s.dashboardInTerritory, s.attendanceCameToday],
                    selectedIndex: _onlyToday ? 1 : 0,
                    onChanged: (i) {
                      if ((i == 1) == _onlyToday) return;
                      HapticFeedback.selectionClick();
                      setState(() => _onlyToday = i == 1);
                      _load();
                    },
                    minSegmentWidth: 0,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: AppRefresh(onRefresh: _load, child: _buildList(s)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(S s) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, color: _kInk),
      decoration: InputDecoration(
        hintText: s.attendanceSearchHint,
        hintStyle: const TextStyle(color: _kMuted, fontSize: 15),
        prefixIcon: const Icon(Icons.search_rounded, color: _kMuted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (_, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: _kMuted),
                  onPressed: _searchController.clear,
                ),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSummary(S s) {
    final share = _totalEmployees > 0
        ? (_inTerritory / _totalEmployees).clamp(0.0, 1.0)
        : 0.0;

    Widget stat(String label, String value, {bool accent = false}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: accent ? AppColors.brandRed : _kInk,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );

    Widget divider() => Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFEDEDED),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              stat(s.dashboardInTerritory, '$_inTerritory', accent: true),
              divider(),
              stat(s.attendanceCameToday, '$_todayEnter'),
              divider(),
              stat(s.attendanceTotalEmployees, '$_totalEmployees'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: share),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Stack(
                children: [
                  Container(height: 6, color: const Color(0xFFEDEDED)),
                  FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.brandOrange, AppColors.brandRed],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectFactory(int? id) {
    if (_factoryId == id) return;
    HapticFeedback.selectionClick();
    setState(() => _factoryId = id);
    _load();
  }

  _AttendanceFactory? get _selectedFactory {
    for (final f in _factories) {
      if (f.id == _factoryId) return f;
    }
    return null;
  }

  Future<void> _openFactorySheet(S s) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<_FactoryPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FactorySheet(
        title: s.attendanceFilterFactory,
        allLabel: s.attendanceAllFactories,
        onSiteLabel: s.dashboardInTerritory,
        factories: _factories,
        selectedId: _factoryId,
      ),
    );
    if (picked != null) _selectFactory(picked.id);
  }

  Widget _buildList(S s) {
    if (_loading && _entries.isEmpty) {
      return const Center(child: LogoStrokeLoader(size: 80));
    }
    if (_error != null) {
      return _centeredMessage(
        Icons.error_outline_rounded,
        _error!,
        color: const Color(0xFFD32F2F),
      );
    }
    if (_entries.isEmpty) {
      return _centeredMessage(Icons.people_outline_rounded, s.attendanceEmpty);
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _entryTile(_entries[i]),
    );
  }

  Widget _centeredMessage(IconData icon, String text, {Color color = _kMuted}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(icon, size: 34, color: color.withOpacity(0.7)),
              ),
              const SizedBox(height: 14),
              Text(text, style: TextStyle(color: color, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entryTile(_AttendanceEntry e) {
    final subtitle = [
      e.position,
      e.department,
    ].where((t) => t.isNotEmpty).join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetail(e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _StatusAvatar(
                entry: e,
                size: 48,
                headers: _photoHeaders,
                heroTag: 'attendance_photo_${e.id}',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    e.time,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (e.place.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 104),
                      child: Text(
                        e.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _kMuted),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFC7C7CC)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar with a small online/offline dot in the corner.
class _StatusAvatar extends StatelessWidget {
  final _AttendanceEntry entry;
  final double size;
  final Map<String, String> headers;
  final String? heroTag;

  const _StatusAvatar({
    required this.entry,
    required this.size,
    required this.headers,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = PersonAvatar(
      name: entry.name,
      size: size,
      sources: entry.photoUrl == null
          ? const []
          : [PhotoSource(entry.photoUrl!, headers: headers)],
    );
    if (heroTag != null) avatar = Hero(tag: heroTag!, child: avatar);
    final dot = size * 0.3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.isIn ? _kOnline : const Color(0xFFC7C7CC),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result wrapper so "all factories" (id == null) can be told apart from a
/// dismissed sheet (which returns null).
class _FactoryPick {
  final int? id;
  const _FactoryPick(this.id);
}

/// Round app-bar button matching [SearchToggleButton]; shows a brand-colour
/// dot while a factory filter is applied.
class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;

  const _FilterButton({required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const icon = Icons.tune_rounded;
    final Widget button;
    if (Platform.isIOS) {
      button = SizedBox(
        width: 46,
        height: 46,
        child: AdaptiveButton.icon(
          onPressed: onPressed,
          icon: icon,
          iconColor: _kInk,
          color: _kInk,
          style: AdaptiveButtonStyle.glass,
          size: AdaptiveButtonSize.medium,
          useSmoothRectangleBorder: false,
          minSize: const Size(46, 46),
        ),
      );
    } else {
      button = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(icon, color: _kInk, size: 22),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            button,
            if (active)
              Positioned(
                top: 2,
                right: 2,
                child: IgnorePointer(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandRed,
                      border: Border.all(
                        color: AppColors.groupedBackground,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with one row per factory: icon, name, how many are on site
/// right now, and a check mark on the current choice.
class _FactorySheet extends StatelessWidget {
  final String title;
  final String allLabel;
  final String onSiteLabel;
  final List<_AttendanceFactory> factories;
  final int? selectedId;

  const _FactorySheet({
    required this.title,
    required this.allLabel,
    required this.onSiteLabel,
    required this.factories,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final total = factories.fold<int>(0, (sum, f) => sum + f.inTerritory);
    final rows = <_FactoryRowData>[
      _FactoryRowData(null, allLabel, total, Icons.apps_rounded),
      for (final f in factories)
        _FactoryRowData(f.id, f.name, f.inTerritory, Icons.factory_rounded),
    ];
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.groupedBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kInk.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                physics: const BouncingScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _row(context, rows[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _FactoryRowData r) {
    final selected = r.id == selectedId;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop(_FactoryPick(r.id));
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.brandOrange : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? const LinearGradient(
                        colors: [AppColors.brandOrange, AppColors.brandRed],
                      )
                    : null,
                color: selected
                    ? null
                    : AppColors.brandOrange.withOpacity(0.14),
              ),
              child: Icon(
                r.icon,
                size: 19,
                color: selected ? Colors.white : AppColors.brandRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${r.count} · $onSiteLabel',
                    style: const TextStyle(fontSize: 12, color: _kMuted),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandRed,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _FactoryRowData {
  final int? id;
  final String name;
  final int count;
  final IconData icon;
  const _FactoryRowData(this.id, this.name, this.count, this.icon);
}

/// iOS-style frosted-glass close button drawn entirely in Flutter. A native
/// `AdaptiveButton` is a platform view: inside a bottom sheet or a fading
/// route it ignores clipping/opacity and renders on top of everything, so
/// overlays use this instead (same reasoning as `AppButton`).
class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).closeButtonLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final _AttendanceEntry entry;
  final Map<String, String> headers;

  const _PhotoViewer({required this.entry, required this.headers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: Hero(
                  tag: 'attendance_photo_${entry.id}_big',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      entry.photoUrl!,
                      headers: headers,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _CloseButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22, left: 24, right: 24),
                child: Text(
                  entry.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Employee card: sized to its content so it fits on screen without
/// scrolling (the scroll view is only a safety net for tiny screens or
/// huge text scale).
class _EmployeeSheet extends StatelessWidget {
  final _AttendanceEntry entry;
  final Map<String, String> photoHeaders;

  const _EmployeeSheet({required this.entry, required this.photoHeaders});

  Future<void> _call() async {
    HapticFeedback.selectionClick();
    final number = entry.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (number.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: number));
  }

  void _openPhoto(BuildContext context) {
    if (entry.photoUrl == null) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, anim, _) => FadeTransition(
          opacity: anim,
          child: _PhotoViewer(entry: entry, headers: photoHeaders),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final subtitle = [
      entry.position,
      entry.department,
    ].where((t) => t.isNotEmpty).join(' · ');
    final hired = entry.employmentDate == null
        ? null
        : DateFormat('dd.MM.yyyy').format(entry.employmentDate!);
    final lastMark = [
      entry.time,
      entry.place,
    ].where((t) => t.isNotEmpty).join(' · ');

    final tiles = <_InfoTile>[
      if (entry.factory.isNotEmpty)
        _InfoTile(Icons.factory_rounded, s.attendanceFilterFactory, entry.factory),
      if (entry.department.isNotEmpty)
        _InfoTile(
          Icons.account_tree_rounded,
          s.attendanceDepartment,
          entry.department,
        ),
      if (entry.reportCard != null)
        _InfoTile(Icons.tag_rounded, s.attendanceTabel, '${entry.reportCard}'),
      if (hired != null)
        _InfoTile(Icons.event_available_rounded, s.attendanceHired, hired),
      if (entry.firstIn != null)
        _InfoTile(Icons.login_rounded, s.attendanceFirstIn, entry.firstIn!),
      if (lastMark.isNotEmpty)
        _InfoTile(
          entry.isIn ? Icons.my_location_rounded : Icons.logout_rounded,
          s.attendanceLastMark,
          lastMark,
        ),
    ];

    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.groupedBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: 92,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandOrange, AppColors.brandRed],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 10,
                  child: _CloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: 92 - 46,
                  child: GestureDetector(
                    onTap: () => _openPhoto(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.groupedBackground,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'attendance_photo_${entry.id}_big',
                        child: PersonAvatar(
                          name: entry.name,
                          size: 84,
                          sources: entry.photoUrl == null
                              ? const []
                              : [
                                  PhotoSource(
                                    entry.photoUrl!,
                                    headers: photoHeaders,
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 52),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    entry.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: _kMuted),
                    ),
                  ],
                  const SizedBox(height: 10),
                  StatusTag(
                    entry.isIn
                        ? s.dashboardInTerritory
                        : s.attendanceStatusOut,
                    color: entry.isIn ? _kOnline : _kMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InfoGrid(tiles: tiles),
            ),
            if (entry.phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CallButton(phone: entry.phone, onTap: _call),
              ),
            ],
            SizedBox(height: 18 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _InfoTile {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(this.icon, this.label, this.value);
}

/// Two-column grid of compact info cards (keeps the sheet short).
class _InfoGrid extends StatelessWidget {
  final List<_InfoTile> tiles;

  const _InfoGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (_, c) {
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(t.icon, size: 15, color: AppColors.brandRed),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        t.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CallButton extends StatelessWidget {
  final String phone;
  final VoidCallback onTap;

  const _CallButton({required this.phone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.brandOrange, AppColors.brandRed],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandRed.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              phone,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
