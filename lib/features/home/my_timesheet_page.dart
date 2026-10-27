import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:http/http.dart' as http;
import 'package:uztexpro_payment/main.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/app_refresh.dart';
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
            Uri.parse('$API/hr/mobile-timesheet/').replace(
              queryParameters: {'year': '$_year', 'month': '$_month'},
            ),
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
                s.timesheetTitle,
                style: const TextStyle(
                  color: _kInk,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                '${s.monthName(_month)} $_year',
                style: const TextStyle(
                  color: AppColors.brandRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.2,
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
          actions: [_buildMonthMenu(s)],
        ),
        body: AppRefresh(onRefresh: _load, child: _buildBody(s)),
      ),
    );
  }

  Widget _buildBody(S s) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
          const SizedBox(height: 14),
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

  /// Compact card: avatar, name, small position line and the month totals.
  Widget _buildHero(S s) {
    Widget stat(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: _kMuted),
          ),
        ],
      ),
    );

    Widget divider() => Container(
      width: 1,
      height: 28,
      color: _kInk.withOpacity(0.08),
    );

    return BlockCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              PersonAvatar(
                name: _name,
                size: 48,
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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
                            fontSize: 11,
                            height: 1.25,
                            color: _kMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
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
        ],
      ),
    );
  }

  Widget _buildCalendar(S s) {
    final lead = _days.isEmpty ? 0 : _days.first.weekday;
    final selected = _days.where((d) => d.day == _selectedDay).firstOrNull;

    return BlockCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      s.weekdayShort(i),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: i >= 5 ? _kAbsent.withOpacity(0.8) : _kMuted,
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
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
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
            color: isSelected ? AppColors.brandRed : Colors.transparent,
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            if (d.total != null)
              Text(
                d.total!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
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
          Text(label, style: const TextStyle(fontSize: 11, color: _kMuted)),
          const SizedBox(height: 2),
          Text(
            value ?? '—',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BlockDivider(gap: 0),
          const SizedBox(height: 12),
          Text(
            '${d.day} ${s.monthName(_month)}, ${s.weekdayShort(d.weekday)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              item(s.timesheetEntry, d.firstIn),
              item(s.timesheetExit, d.lastOut),
              item(s.timesheetHours, d.total),
            ],
          ),
          if (d.total != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                item(s.timesheetDayShift, d.dayHours),
                item(s.timesheetNight, d.nightHours),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(S s) {
    Widget dot(Color c, String text) => Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              text,
              maxLines: 1,
              style: const TextStyle(fontSize: 10.5, color: _kMuted),
            ),
          ],
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        dot(_kWorked, s.timesheetLegendWorked),
        const SizedBox(width: 8),
        dot(_kPresent, s.timesheetLegendPresent),
        const SizedBox(width: 8),
        dot(_kAbsent, s.timesheetLegendAbsent),
        const SizedBox(width: 8),
        dot(_kOff, s.timesheetLegendOff),
      ],
    );
  }
}
