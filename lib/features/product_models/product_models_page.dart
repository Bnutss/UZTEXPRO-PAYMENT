import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:uztexpro_payment/main.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import 'product_model_detail_page.dart';

const _kProductModelListPath = 'sewing/product-model-list';
const _kConfirmPricePath = 'sewing/product-model';
const _kPageLimit = 30;

class _Page {
  final List<dynamic> items;
  final bool hasMore;
  final int count;

  const _Page(this.items, this.hasMore, this.count);
}

_Page _parsePage(dynamic body) {
  final List items = body is List
      ? body
      : (body['results'] ?? body['data'] ?? []);
  final next = body is Map ? body['next'] : null;
  final count = body is Map ? (body['count'] ?? items.length) : items.length;
  return _Page(items, next != null, count is int ? count : items.length);
}

class ProductModelsPage extends StatefulWidget {
  final String jwtToken;

  const ProductModelsPage({Key? key, required this.jwtToken}) : super(key: key);

  @override
  State<ProductModelsPage> createState() => _ProductModelsPageState();
}

class _ProductModelsPageState extends State<ProductModelsPage>
    with SingleTickerProviderStateMixin {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  static final Map<String, _Page> _memCache = {};
  static final Map<String, DateTime> _memCacheTime = {};
  static const Duration _kCacheTTL = Duration(minutes: 5);

  List<dynamic> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String? _error;
  String _query = '';
  int _count = 0;
  final Set<String> _knownFirms = {};
  bool _skipNextSearchEvent = false;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  String get _token {
    try {
      return jsonDecode(widget.jwtToken)['token'] as String;
    } catch (_) {
      return widget.jwtToken;
    }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  // Cache is namespaced per account so switching users on the same device
  // never shows a previous account's cached list.
  String get _userKey {
    try {
      final body = jsonDecode(widget.jwtToken) as Map<String, dynamic>;
      final user = body['user'];
      if (user is Map) {
        final id = user['pk'] ?? user['id'] ?? user['username'];
        if (id != null) return id.toString();
      }
    } catch (_) {}
    return _token;
  }

  String get _cacheKey => 'product_models_v1_$_userKey';

  bool get _canConfirmPrice {
    try {
      final body = jsonDecode(widget.jwtToken) as Map<String, dynamic>;
      final user = body['user'];
      if (user is Map && user['is_super'] == true) return true;
      final raw = user is Map ? user['groups'] : body['groups'];
      final groups = raw is List
          ? raw.map((e) => e.toString()).toSet()
          : <String>{};
      return groups.contains('price_permission');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _searchCtrl.addListener(() {
      if (_skipNextSearchEvent) {
        _skipNextSearchEvent = false;
        return;
      }
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _query = _searchCtrl.text.trim();
        _load(reset: true);
      });
    });
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
    localeNotifier.addListener(_onLocale);
  }

  void _onLocale() => setState(() {});

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _selectFirm(String firm) {
    _debounce?.cancel();
    final newQuery = _query == firm ? '' : firm;
    _skipNextSearchEvent = true;
    _searchCtrl.text = newQuery;
    _searchCtrl.selection = TextSelection.collapsed(offset: newQuery.length);
    _query = newQuery;
    _load(reset: true);
  }

  void _mergeKnownFirms(List items) {
    for (final item in items) {
      final firm = (item as Map)['firm_name']?.toString();
      if (firm != null && firm.isNotEmpty) _knownFirms.add(firm);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _debounce?.cancel();
    localeNotifier.removeListener(_onLocale);
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Uri _pageUri(int offset) {
    final params = {
      'limit': '$_kPageLimit',
      'offset': '$offset',
      if (_query.isNotEmpty) 'search': _query,
    };
    return Uri.parse(
      '$API/$_kProductModelListPath/',
    ).replace(queryParameters: params);
  }

  // Only the default (unfiltered) first page is cached — it's the one users
  // hit on every open, and at 30 rows it's cheap to keep around. Search and
  // firm-filtered results always go straight to the network.
  bool get _isDefaultQuery => _query.isEmpty;

  void _applyPage(
    _Page page, {
    required bool isLoading,
    required bool refreshing,
  }) {
    _mergeKnownFirms(page.items);
    setState(() {
      _items = List.from(page.items);
      _hasMore = page.hasMore;
      _count = page.count;
      _isLoading = isLoading;
      _refreshing = refreshing;
      _error = null;
    });
  }

  Future<void> _load({required bool reset}) async {
    if (reset && _isDefaultQuery) {
      final cached = _memCache[_cacheKey];
      final cachedAt = _memCacheTime[_cacheKey];
      if (cached != null && cachedAt != null) {
        _applyPage(cached, isLoading: false, refreshing: false);
        _animCtrl.forward(from: 0);
        if (DateTime.now().difference(cachedAt) < _kCacheTTL) return;
        setState(() => _refreshing = true);
        await _fetchPage(0, silent: true);
        return;
      }
      try {
        final raw = await storage.read(key: _cacheKey);
        if (raw != null && mounted) {
          _applyPage(
            _parsePage(json.decode(raw)),
            isLoading: false,
            refreshing: true,
          );
          _animCtrl.forward(from: 0);
          await _fetchPage(0, silent: true);
          return;
        }
      } catch (_) {}
    }

    if (reset) {
      setState(() {
        _isLoading = true;
        _refreshing = false;
        _error = null;
        _items = [];
        _hasMore = true;
      });
    }
    await _fetchPage(0, silent: false);
  }

  Future<void> _fetchPage(int offset, {required bool silent}) async {
    try {
      final resp = await http
          .get(_pageUri(offset), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final raw = utf8.decode(resp.bodyBytes);
        final page = _parsePage(json.decode(raw));
        if (offset == 0 && _isDefaultQuery) {
          _memCache[_cacheKey] = page;
          _memCacheTime[_cacheKey] = DateTime.now();
          storage.write(key: _cacheKey, value: raw);
        }
        _applyPage(page, isLoading: false, refreshing: false);
        if (!silent) _animCtrl.forward(from: 0);
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        if (silent) {
          setState(() => _refreshing = false);
        } else {
          setState(() {
            _error = S.of(context).signError;
            _isLoading = false;
            _refreshing = false;
          });
        }
      } else {
        if (silent) {
          setState(() => _refreshing = false);
        } else {
          setState(() {
            _error = '${S.of(context).loadDataError} (${resp.statusCode})';
            _isLoading = false;
            _refreshing = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        setState(() => _refreshing = false);
      } else {
        setState(() {
          _error = '${S.of(context).connectionError}\n$e';
          _isLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final resp = await http
          .get(_pageUri(_items.length), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final page = _parsePage(json.decode(utf8.decode(resp.bodyBytes)));
        _mergeKnownFirms(page.items);
        setState(() {
          _items = [..._items, ...page.items];
          _hasMore = page.hasMore;
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _load(reset: false);
  }

  void _invalidateCache() {
    _memCache.remove(_cacheKey);
    _memCacheTime.remove(_cacheKey);
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _onToggleConfirm(Map<String, dynamic> item) async {
    final confirmed = item['price_confirmed'] == true;
    final ok = await _confirmDialog(
      icon: confirmed
          ? Icons.remove_circle_outline_rounded
          : Icons.check_circle_outline_rounded,
      iconColor: confirmed ? Colors.red.shade600 : const Color(0xFF43A047),
      title: confirmed
          ? S.of(context).unconfirmPriceTitle
          : S.of(context).confirmPriceTitle,
      message: confirmed
          ? S.of(context).unconfirmPriceDesc
          : S.of(context).confirmPriceDesc,
      confirmLabel: confirmed
          ? S.of(context).unconfirmPriceBtn
          : S.of(context).confirmPriceBtn,
      confirmColor: confirmed ? Colors.red.shade600 : const Color(0xFF43A047),
    );
    if (!ok) return;
    setState(() => item['_busy'] = true);
    try {
      final id = item['id'];
      final uri = Uri.parse('$API/$_kConfirmPricePath/$id/confirm-price/');
      final resp = confirmed
          ? await http
                .delete(uri, headers: _headers)
                .timeout(const Duration(seconds: 15))
          : await http
                .post(uri, headers: _headers)
                .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          item['price_confirmed'] = data['price_confirmed'] ?? !confirmed;
          item['price_confirmed_by_name'] = data['price_confirmed_by_name'];
          item['price_confirmed_at'] = data['price_confirmed_at'];
          item['_busy'] = false;
        });
        _invalidateCache();
        _snack(
          confirmed
              ? S.of(context).unconfirmPriceSuccess
              : S.of(context).confirmPriceSuccess,
          true,
        );
      } else if (resp.statusCode == 403) {
        _snack(S.of(context).noPricePermission, false);
        setState(() => item['_busy'] = false);
      } else {
        _snack(S.of(context).updateError, false);
        setState(() => item['_busy'] = false);
      }
    } catch (_) {
      if (!mounted) return;
      _snack(S.of(context).connectionError, false);
      setState(() => item['_busy'] = false);
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  Future<bool> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: onSurface.withOpacity(0.2)),
                      ),
                      child: Text(
                        S.of(context).cancel,
                        style: TextStyle(
                          color: onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_g1, _g2];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            s.productModelsTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_refreshing)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white70),
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _isLoading ? null : _onRefresh,
              ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Row(
                    children: [
                      const Spacer(),
                      if (!_isLoading && _error == null)
                        _CountBadge(count: _count),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _SearchBar(
                controller: _searchCtrl,
                hintText: s.productModelSearchHint,
                isDark: isDark,
              ),
            ),
            if (_knownFirms.isNotEmpty)
              Container(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                padding: const EdgeInsets.only(bottom: 10),
                child: _FirmFilterRow(
                  firms: _knownFirms.toList()..sort(),
                  selected: _query,
                  isDark: isDark,
                  allLabel: s.filterAll,
                  onSelect: _selectFirm,
                ),
              ),
            Expanded(
              child: Container(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : const Color(0xFFF4F4F4),
                child: _buildBody(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final s = S.of(context);
    if (_isLoading) return _shimmer(isDark);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: isDark ? Colors.white38 : Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(s.refresh),
                style: FilledButton.styleFrom(
                  backgroundColor: _g1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                        ),
                      ],
              ),
              child: Icon(
                Icons.checkroom_rounded,
                size: 38,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.productModelsEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: _g1,
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
          itemCount: _items.length + (_hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFFF8C00)),
                    ),
                  ),
                ),
              );
            }
            final item = _items[i] as Map<String, dynamic>;
            return _ProductModelCard(
              item: item,
              isDark: isDark,
              canConfirm: _canConfirmPrice,
              onToggleConfirm: () => _onToggleConfirm(item),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductModelDetailPage(
                    modelId: item['id'] as int,
                    jwtToken: widget.jwtToken,
                    canConfirm: _canConfirmPrice,
                    onActionDone: () {
                      _invalidateCache();
                      _load(reset: true);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _shimmer(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Container(
            height: 128,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Product Model Card ────────────────────────────────────────────────────────

class _ProductModelCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final bool canConfirm;
  final VoidCallback onToggleConfirm;
  final VoidCallback onTap;

  const _ProductModelCard({
    required this.item,
    required this.isDark,
    required this.canConfirm,
    required this.onToggleConfirm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;

    final vendorCode = item['vendor_code']?.toString() ?? '—';
    final name = item['name']?.toString() ?? '—';
    final firm = item['firm_name']?.toString() ?? '—';
    final cost = item['cost']?.toString() ?? '—';
    final confirmed = item['price_confirmed'] == true;
    final confirmedBy = item['price_confirmed_by_name']?.toString() ?? '';
    final confirmedAt = item['price_confirmed_at']?.toString() ?? '';
    final busy = item['_busy'] == true;

    final statusColor = confirmed
        ? const Color(0xFF43A047)
        : const Color(0xFFFF8C00);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: statusColor, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withOpacity(isDark ? 0.2 : 0.12),
                      ),
                      child: Icon(
                        Icons.checkroom_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendorCode,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withOpacity(0.55),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          cost,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF8C00),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusBadge(
                          confirmed: confirmed,
                          label: confirmed
                              ? s.priceConfirmed
                              : s.priceNotConfirmed,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.storefront_outlined,
                  label: s.firmLabel,
                  text: firm,
                  onSurface: onSurface,
                ),
                if (confirmed &&
                    (confirmedBy.isNotEmpty || confirmedAt.isNotEmpty)) ...[
                  const SizedBox(height: 5),
                  _InfoRow(
                    icon: Icons.verified_outlined,
                    label: s.confirmedByLabel,
                    text: [
                      confirmedBy,
                      confirmedAt,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    onSurface: onSurface,
                  ),
                ],
                if (canConfirm) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  const SizedBox(height: 10),
                  if (busy)
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFFF8C00)),
                        ),
                      ),
                    )
                  else
                    _ActionBtn(
                      label: confirmed
                          ? s.unconfirmPriceBtn
                          : s.confirmPriceBtn,
                      icon: confirmed
                          ? Icons.remove_circle_outline_rounded
                          : Icons.check_rounded,
                      color: confirmed
                          ? const Color(0xFFE53935)
                          : const Color(0xFF43A047),
                      bgColor: confirmed
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE8F5E9),
                      isDark: isDark,
                      onTap: onToggleConfirm,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool confirmed;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.confirmed,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed
                ? Icons.check_circle_rounded
                : Icons.hourglass_empty_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color onSurface;
  final bool highlight;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.onSurface,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 13,
          color: highlight
              ? const Color(0xFFFF8C00)
              : onSurface.withOpacity(0.35),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.45)),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight
                  ? const Color(0xFFFF8C00)
                  : onSurface.withOpacity(0.85),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isDark;

  const _SearchBar({
    required this.controller,
    required this.hintText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: '$hintText...',
          hintStyle: TextStyle(
            color: onSurface.withOpacity(0.38),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: onSurface.withOpacity(0.38),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: onSurface.withOpacity(0.4),
                    ),
                    onPressed: controller.clear,
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ─── Count badge ──────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Firm filter chips ─────────────────────────────────────────────────────────

class _FirmFilterRow extends StatelessWidget {
  final List<String> firms;
  final String selected;
  final bool isDark;
  final String allLabel;
  final ValueChanged<String> onSelect;

  const _FirmFilterRow({
    required this.firms,
    required this.selected,
    required this.isDark,
    required this.allLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _FirmChip(
            label: allLabel,
            selected: selected.isEmpty,
            isDark: isDark,
            onTap: () => onSelect(''),
          ),
          for (final firm in firms) ...[
            const SizedBox(width: 6),
            _FirmChip(
              label: firm,
              selected: selected == firm,
              isDark: isDark,
              onTap: () => onSelect(firm),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirmChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FirmChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF8C00);
    const color2 = Color(0xFFCC1500);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        constraints: const BoxConstraints(maxWidth: 160),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [color, color2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected
              ? null
              : (isDark ? Colors.white.withOpacity(0.07) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!selected)
              Icon(
                Icons.storefront_outlined,
                size: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
              ),
            if (!selected) const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
