import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:http/http.dart' as http;
import 'package:uztexpro_payment/main.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/ui_blocks.dart';

const _kInk = Color(0xFF1C1C1E);
const _kMuted = Color(0xFF8A8A8E);
const _kWorked = Color(0xFF34C759);
const _kPresent = Color(0xFFFF9500);
const _kAbsent = Color(0xFFFF3B30);
const _kOff = Color(0xFFD1D1D6);

class _Day {
  const _Day({
    required this.day,
    required this.weekday,
    required this.state,
    this.total,
    this.dayHours,
    this.nightHours,
    this.firstIn,
    this.lastOut,
  });

  final int day;
  final int weekday;

  /// worked | present | absent | off | future
  final String state;
  final String? total;
  final String? dayHours;
  final String? nightHours;
  final String? firstIn;
  final String? lastOut;

  factory _Day.fromJson(Map<String, dynamic> j) => _Day(
    day: (j['day'] as num).toInt(),
    weekday: (j['weekday'] as num).toInt(),
    state: j['state'] as String? ?? 'future',
    total: j['total'] as String?,
    dayHours: j['day_hours'] as String?,
    nightHours: j['night_hours'] as String?,
    firstIn: j['first_in'] as String?,
    lastOut: j['last_out'] as String?,
  );

  Color get color => switch (state) {
    'worked' => _kWorked,
    'present' => _kPresent,
    'absent' => _kAbsent,
    'off' => _kOff,
    _ => Colors.transparent,
  };
}

class MyTimesheetPage extends StatefulWidget {
  const MyTimesheetPage({super.key, required this.jwtToken});

  final String jwtToken;

  @override
  State<MyTimesheetPage> createState() => _MyTimesheetPageState();
}

class _MyTimesheetPageState extends State<MyTimesheetPage> {
  late int _year;
  late int _month;

  String _name = '';
  String _subtitle = '';
  String? _photoUrl;
  int _totalHours = 0;
  int _totalDays = 0;
  int _absentDays = 0;
  List<_Day> _days = [];
  int? _selectedDay;

  bool _canEdit = false;

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

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  /// Photo links may come back relative or with plain http behind the proxy.
  static String? _resolvePhoto(String? url) {
    if (url == null || url.isEmpty) return null;
    final origin = Uri.parse(API).origin;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$origin$url';
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    localeNotifier.addListener(_onLocaleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  /// Last 12 months, newest first.
  List<DateTime> get _months {
    final now = DateTime.now();
    return [for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i)];
  }

  void _pickMonth(DateTime m) {
    if (m.year == _year && m.month == _month) return;
    HapticFeedback.selectionClick();
    setState(() {
      _year = m.year;
      _month = m.month;
      _selectedDay = null;
    });
    _load();
  }

  /// Native month menu (iOS 26 glass / Material popup) in the app bar.
  Widget _buildMonthMenu(S s) {
    final native = PlatformInfo.isIOS26OrHigher();
    final months = _months;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AdaptivePopupMenuButton.icon<DateTime>(
              icon: native ? 'calendar' : Icons.calendar_month_rounded,
              size: 46,
              tint: _kInk,
              items: [
                for (final m in months)
                  AdaptivePopupMenuItem<DateTime>(
                    label: '${s.monthName(m.month)} ${m.year}',
                    icon: (m.year == _year && m.month == _month)
                        ? (native ? 'checkmark' : Icons.check_rounded)
                        : null,
                    value: m,
                  ),
              ],
              onSelected: (i, item) {
                final m = item.value;
                if (m != null) _pickMonth(m);
              },
            ),
            if (!_isCurrentMonth)
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

  Future<void> _load() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final s = S.of(context);
    try {
      final res = await http
          .get(
            Uri.parse(
              '$API/hr/mobile-timesheet/',
            ).replace(queryParameters: {'year': '$_year', 'month': '$_month'}),
            headers: {'Authorization': 'Bearer $_apiToken'},
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted || seq != _requestSeq) return;
      if (res.statusCode != 200) {
        setState(() {
          _error = res.statusCode == 404
              ? s.timesheetNoEmployee
              : s.attendanceLoadError;
          _loading = false;
        });
        return;
      }
      final body =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final emp = (body['employee'] as Map).cast<String, dynamic>();
      setState(() {
        _name = emp['name'] as String? ?? '';
        _subtitle = [
          emp['position'],
          emp['department'],
        ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
        _photoUrl = _resolvePhoto(emp['photo'] as String?);
        _totalHours = (body['total_hours'] as num?)?.toInt() ?? 0;
        _totalDays = (body['total_days'] as num?)?.toInt() ?? 0;
        _absentDays = (body['absent_days'] as num?)?.toInt() ?? 0;
        _canEdit = body['can_edit'] == true;
        _days = ((body['days'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => _Day.fromJson(e.cast<String, dynamic>()))
            .toList();
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

  static TimeOfDay? _parseHm(String? v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v ?? '');
    if (m == null) return null;
    return TimeOfDay(
      hour: int.parse(m.group(1)!),
      minute: int.parse(m.group(2)!),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Strict HH:MM parser for typed input; null when incomplete/invalid.
  static TimeOfDay? _parseTyped(String v) {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(v);
    if (m == null) return null;
    final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    return TimeOfDay(hour: h, minute: mi);
  }

  /// Bottom sheet with entry/exit times for one day; saves both in one request.
  Future<void> _openEditSheet(_Day d) async {
    HapticFeedback.selectionClick();
    final s = S.of(context);
    final origIn = _parseHm(d.firstIn);
    final origOut = _parseHm(d.lastOut);
    var saving = false;
    String? error;

    // iOS: native sheet with system time pickers.
    if (Platform.isIOS) {
      try {
        final res = await const MethodChannel(
          'uztexpro/native_sheet',
        ).invokeMapMethod<String, dynamic>('editTimes', {
          'title': s.timesheetEditTitle,
          'subtitle':
              '${d.day} ${s.monthName(_month)} $_year, ${s.weekdayShort(d.weekday)}',
          'save': s.timesheetSave,
          'entry': s.timesheetEntry,
          'exit': s.timesheetExit,
          'error': s.timesheetExitBeforeEntry,
          'in': origIn == null ? '' : _fmt(origIn),
          'out': origOut == null ? '' : _fmt(origOut),
        });
        if (res == null || !mounted) return;
        final err = await _saveDay(
          d,
          _parseHm(res['in'] as String?),
          _parseHm(res['out'] as String?),
          origIn,
          origOut,
        );
        if (!mounted) return;
        if (err == null) {
          HapticFeedback.mediumImpact();
          await _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
        return;
      } on MissingPluginException {
        // fall through to the Flutter sheet
      } on PlatformException {
        // fall through to the Flutter sheet
      }
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ControllersScope(
        initialIn: origIn == null ? '' : _fmt(origIn),
        initialOut: origOut == null ? '' : _fmt(origOut),
        builder: (ctx, cIn, cOut) => StatefulBuilder(
          builder: (ctx, setSheet) {
            final tIn = _parseTyped(cIn.text);
            final tOut = _parseTyped(cOut.text);
            // a non-empty but incomplete field blocks saving
            final partial =
                (cIn.text.isNotEmpty && tIn == null) ||
                (cOut.text.isNotEmpty && tOut == null);
            bool same(TimeOfDay? a, TimeOfDay? b) =>
                (a == null && b == null) ||
                (a != null && b != null && _mins(a) == _mins(b));
            final changed = !same(tIn, origIn) || !same(tOut, origOut);
            final invalid =
                tIn != null && tOut != null && _mins(tOut) <= _mins(tIn);
            final canSave =
                changed &&
                !invalid &&
                !partial &&
                !saving &&
                (tIn != null || tOut != null);

            Widget tile(String label, TextEditingController c, IconData icon) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  decoration: BoxDecoration(
                    color: AppColors.groupedBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 16, color: _kMuted),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kMuted,
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: c,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_TimeInputFormatter()],
                        onChanged: (_) => setSheet(() => error = null),
                        cursorColor: AppColors.brandRed,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        decoration: const InputDecoration(
                          hintText: '--:--',
                          hintStyle: TextStyle(color: _kMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kOff,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.timesheetEditTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day} ${s.monthName(_month)} $_year, ${s.weekdayShort(d.weekday)}',
                    style: const TextStyle(fontSize: 13, color: _kMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      tile(s.timesheetEntry, cIn, Icons.login_rounded),
                      const SizedBox(width: 12),
                      tile(s.timesheetExit, cOut, Icons.logout_rounded),
                    ],
                  ),
                  if (invalid || partial || error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error ??
                          (invalid
                              ? s.timesheetExitBeforeEntry
                              : s.timesheetTimeFormat),
                      style: const TextStyle(fontSize: 12.5, color: _kAbsent),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: !canSave
                          ? null
                          : () async {
                              setSheet(() {
                                saving = true;
                                error = null;
                              });
                              final err = await _saveDay(
                                d,
                                tIn,
                                tOut,
                                origIn,
                                origOut,
                              );
                              if (err == null) {
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } else {
                                setSheet(() {
                                  saving = false;
                                  error = err;
                                });
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              s.timesheetSave,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (saved == true && mounted) {
      HapticFeedback.mediumImpact();
      await _load();
    }
  }

  /// Returns an error message, or null on success. Sends only changed marks.
  Future<String?> _saveDay(
    _Day d,
    TimeOfDay? tIn,
    TimeOfDay? tOut,
    TimeOfDay? origIn,
    TimeOfDay? origOut,
  ) async {
    final s = S.of(context);
    final date =
        '$_year-${_month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    bool diff(TimeOfDay? a, TimeOfDay? b) =>
        a != null && (b == null || _mins(a) != _mins(b));
    try {
      final res = await http
          .post(
            Uri.parse('$API/hr/mobile-timesheet/edit/'),
            headers: {
              'Authorization': 'Bearer $_apiToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'date': date,
              if (diff(tIn, origIn)) 'check_in': _fmt(tIn!),
              if (diff(tOut, origOut)) 'check_out': _fmt(tOut!),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      try {
        return json.decode(utf8.decode(res.bodyBytes))['error'] as String? ??
            s.timesheetSaveError;
      } catch (_) {
        return s.timesheetSaveError;
      }
    } catch (_) {
      return s.timesheetSaveError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const bg = AppColors.groupedBackground;

    return FadingHeaderScaffold(
      title: s.timesheetTitle,
      subtitle: '${s.monthName(_month)} $_year',
      background: bg,
      // Month picker: the native calendar menu, left in the title row.
      trailing: [_buildMonthMenu(s)],
      body: (context, topInset) => AppRefresh(
        topOffset: topInset,
        onRefresh: _load,
        child: _buildBody(s, topInset),
      ),
    );
  }

  Widget _buildBody(S s, double topInset) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 32),
      children: [
        if (_error != null)
          _buildError()
        else if (_loading && _days.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _buildHero(s),
          const SizedBox(height: 16),
          _buildCalendar(s),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 44, color: _kMuted),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }

  /// Header card: avatar, name, position and the three month totals in
  /// equal columns.
  Widget _buildHero(S s) {
    Widget stat(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _kMuted),
          ),
        ],
      ),
    );

    Widget divider() =>
        Container(width: 1, height: 32, color: _kInk.withOpacity(0.08));

    return BlockCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PersonAvatar(
                name: _name,
                size: 52,
                sources: [
                  if (_photoUrl != null)
                    PhotoSource(
                      _photoUrl!,
                      headers: {'Authorization': 'Bearer $_apiToken'},
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: _kInk,
                      ),
                    ),
                    if (_subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: _kMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const BlockDivider(gap: 0),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                stat(s.timesheetHours, '$_totalHours', _kInk),
                divider(),
                stat(s.timesheetDays, '$_totalDays', _kWorked),
                divider(),
                stat(
                  s.timesheetAbsent,
                  '$_absentDays',
                  _absentDays > 0 ? _kAbsent : _kInk,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(S s) {
    final lead = _days.isEmpty ? 0 : _days.first.weekday;
    final selected = _days.where((d) => d.day == _selectedDay).firstOrNull;

    return BlockCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      s.weekdayShort(i),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.92,
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (final d in _days) _buildCell(d),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: selected == null || selected.state == 'future'
                ? const SizedBox(width: double.infinity)
                : _buildDayDetail(s, selected),
          ),
          const SizedBox(height: 16),
          _buildLegend(s),
        ],
      ),
    );
  }

  Widget _buildCell(_Day d) {
    final isSelected = d.day == _selectedDay;
    final future = d.state == 'future';
    final off = d.state == 'off';
    final Color fill = (future || off)
        ? Colors.transparent
        : d.color.withOpacity(0.14);
    final Color textColor = future
        ? _kMuted.withOpacity(0.45)
        : off
        ? _kMuted
        : d.color == _kWorked
        ? const Color(0xFF1E8E3E)
        : d.color == _kPresent
        ? const Color(0xFFC76E00)
        : const Color(0xFFD62E24);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: future
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDay = isSelected ? null : d.day);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kInk : Colors.transparent,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: textColor,
              ),
            ),
            if (d.total != null)
              Text(
                d.total!,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: textColor.withOpacity(0.85),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetail(S s, _Day d) {
    Widget item(String label, String? value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 2),
          Text(
            value ?? '—',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _kInk,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.groupedBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${d.day} ${s.monthName(_month)}, ${s.weekdayShort(d.weekday)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
                      ),
                    ),
                  ),
                  if (_canEdit)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: AdaptiveButton.icon(
                            onPressed: () => _openEditSheet(d),
                            icon: Icons.edit_rounded,
                            iconColor: _kInk,
                            color: _kInk,
                            style: AdaptiveButtonStyle.glass,
                            size: AdaptiveButtonSize.small,
                            useSmoothRectangleBorder: false,
                            padding: EdgeInsets.zero,
                            minSize: const Size(36, 36),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  item(s.timesheetEntry, d.firstIn),
                  item(s.timesheetExit, d.lastOut),
                  item(s.timesheetHours, d.total),
                ],
              ),
            ),
            if (d.total != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    item(s.timesheetDayShift, d.dayHours),
                    item(s.timesheetNight, d.nightHours),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(S s) {
    Widget dot(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: _kMuted)),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        dot(_kWorked, s.timesheetLegendWorked),
        dot(_kPresent, s.timesheetLegendPresent),
        dot(_kAbsent, s.timesheetLegendAbsent),
        dot(_kOff, s.timesheetLegendOff),
      ],
    );
  }
}

/// Types digits only and inserts the colon: "905" -> "09:05" once complete.
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = d.length > 2 ? '${d.substring(0, 2)}:${d.substring(2)}' : d;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Owns the two time controllers for the edit sheet so they are disposed
/// only after the sheet's closing animation has finished.
class _ControllersScope extends StatefulWidget {
  const _ControllersScope({
    required this.initialIn,
    required this.initialOut,
    required this.builder,
  });

  final String initialIn;
  final String initialOut;
  final Widget Function(
    BuildContext context,
    TextEditingController cIn,
    TextEditingController cOut,
  )
  builder;

  @override
  State<_ControllersScope> createState() => _ControllersScopeState();
}

class _ControllersScopeState extends State<_ControllersScope> {
  late final TextEditingController _in = TextEditingController(
    text: widget.initialIn,
  );
  late final TextEditingController _out = TextEditingController(
    text: widget.initialOut,
  );

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _in, _out);
}
