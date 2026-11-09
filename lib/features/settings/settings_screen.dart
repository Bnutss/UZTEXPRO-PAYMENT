import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:http/http.dart' as http;
import 'package:uztexpro_payment/main.dart';
import '../../core/storage/app_storage.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fade_route.dart';
import '../chat/chat_media.dart';
import '../../core/widgets/ui_blocks.dart';
import 'face_id_tile.dart';
import '../chat/chat_api.dart' show ChatRest;
import 'chat_appearance_page.dart';
import 'chat_data_page.dart';
import 'chat_devices_page.dart';
import 'chat_notifications_page.dart';
import 'island_pull_avatar.dart';
import 'settings_rows.dart';
import 'privacy_policy_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    Key? key,
    this.topInset = 0,
    this.chatOnly = false,
    this.islandActive = true,
    this.chatApi,
  }) : super(key: key);

  /// In the messenger: the chat's connection to the server (for the list of
  /// devices).
  final ChatRest? chatApi;

  /// In the messenger: whether this tab is the one on screen. The avatar that
  /// hangs from the Dynamic Island must not show over the other tabs.
  final bool islandActive;

  /// The settings tab inside the messenger: the profile and what belongs to
  /// the chat (its storage). The app settings live on the main screen.
  final bool chatOnly;

  /// Space the floating header takes above the first row (content still
  /// scrolls beneath it).
  final double topInset;

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final AppStorage _storage = const AppStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  String _displayName = '';
  String _email = '';
  String _login = '';
  String _version = '';
  // The photo of the employee linked to this user (same source as "My
  // timesheet"); empty until loaded or when the user has no employee.
  String? _photoUrl;
  String _apiToken = '';
  // What the chat's photos, videos and files take on this phone (null: not
  // counted yet).
  int? _chatBytes;
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;
  // Which biometric icon/label to show — detected per device instead of
  // hardcoding a fingerprint (iPhones with Face ID have no Touch ID sensor
  // at all, so "fingerprint" would be flatly wrong there).
  BiometricType? _biometricType;

  static const Color _gradientStart = AppColors.brandOrange;

  final List<Map<String, String>> _languages = [
    {'code': 'ru', 'name': 'Русский', 'desc': 'Русский язык'},
    {'code': 'en', 'name': 'English', 'desc': 'English language'},
    {'code': 'uz', 'name': "O'zbekcha", 'desc': "O'zbek tili"},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _loadUserData().then((_) => _loadPhoto());
    if (!widget.chatOnly) {
      _loadVersion();
      _checkBiometrics();
      _loadBiometricPreference();
    } else {
      _countChatStorage();
    }
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final available = await _auth.getAvailableBiometrics();
      BiometricType? type;
      if (available.contains(BiometricType.face)) {
        type = BiometricType.face;
      } else if (available.contains(BiometricType.fingerprint)) {
        type = BiometricType.fingerprint;
      } else if (available.isNotEmpty) {
        type = available.first;
      }
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck || isSupported;
          _biometricType = type;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _canCheckBiometrics = false);
    }
  }

  Future<void> _loadBiometricPreference() async {
    final useBiometrics = await _storage.read(key: 'useBiometrics');
    if (mounted) setState(() => _useBiometrics = useBiometrics == 'true');
  }

  /// Turning it on first checks the user, so it can't be switched on by
  /// someone who only holds an unlocked phone.
  Future<void> _toggleBiometricPreference(bool value) async {
    if (value) {
      try {
        final ok = await _auth.authenticate(
          localizedReason: S.of(context).authLoginReason,
          biometricOnly: true,
        );
        if (!ok) return;
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;
    setState(() => _useBiometrics = value);
    await _storage.write(key: 'useBiometrics', value: value.toString());
  }

  Future<void> _loadUserData() async {
    final jwtRaw = await _storage.read(key: 'jwt');
    if (jwtRaw != null) {
      try {
        final body = jsonDecode(jwtRaw) as Map<String, dynamic>;
        final user = body['user'] as Map<String, dynamic>?;
        if (user != null) {
          final firstName = (user['first_name'] as String?) ?? '';
          final lastName = (user['last_name'] as String?) ?? '';
          final fullName = '$firstName $lastName'.trim();
          setState(() {
            _displayName = fullName.isNotEmpty
                ? fullName
                : (user['username'] as String? ?? '');
            _email = (user['email'] as String?) ?? '';
            _login = (user['username'] as String?) ?? '';
          });
          return;
        }
      } catch (_) {}
    }
    final login = await _storage.read(key: 'username') ?? '';
    setState(() {
      _displayName = login;
      _login = login;
    });
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

  Future<void> _loadPhoto() async {
    try {
      final jwtRaw = await _storage.read(key: 'jwt');
      if (jwtRaw == null) return;
      final token = (jsonDecode(jwtRaw) as Map<String, dynamic>)['token'];
      if (token is! String) return;
      final now = DateTime.now();
      final res = await http
          .get(
            Uri.parse('$API/hr/mobile-timesheet/').replace(
              queryParameters: {'year': '${now.year}', 'month': '${now.month}'},
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final body =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final photo = _resolvePhoto(
        (body['employee'] as Map?)?['photo'] as String?,
      );
      if (mounted && photo != null) {
        setState(() {
          _photoUrl = photo;
          _apiToken = token;
        });
      }
    } catch (_) {
      // No employee linked or no network: the initials stay.
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = info.version);
  }

  @override
  void dispose() {
    _animationController.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  // No own Scaffold/AnnotatedRegion here: this screen is only ever mounted
  // as a tab body inside MenuPage's IndexedStack, which already paints the
  // shared background + status bar style for every tab.
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    // iPhones with a Dynamic Island, in the messenger: the avatar hangs from
    // the island (see IslandPullAvatar) and the page only leaves room for it.
    final island = widget.chatOnly && IslandPullAvatar.supported(context);

    Widget page = CustomScrollView(
      clipBehavior: Clip.none,
      physics: island
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : null,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16 + widget.topInset, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([_buildSettingsCard(s)]),
          ),
        ),
        // Room under the last card, clear of the tab bar.
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 114),
        ),
        // The avatar merges into the island as the page scrolls up, so there
        // must be that much to scroll even when the page is short.
        if (island) ...[
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: IslandPullAvatar.snapRange),
          ),
        ],
      ],
    );

    if (island) {
      page = IslandPullAvatar(
        name: _displayName,
        photoUrl: _photoUrl,
        photoHeaders: {'Authorization': 'Bearer $_apiToken'},
        active: widget.islandActive,
        background: AppColors.groupedBackground,
        child: page,
      );
    }

    // Scrolls under the (transparent) header: no clip edge, no block.
    return FadeTransition(opacity: _animation, child: page);
  }

  List<PhotoSource> get _photoSources => [
    if (_photoUrl != null)
      PhotoSource(_photoUrl!, headers: {'Authorization': 'Bearer $_apiToken'}),
  ];

  /// Telegram-style: the profile on the page itself, then groups of rows with
  /// colored icon tiles.
  Widget _buildSettingsCard(S s) {
    if (widget.chatOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileSection(s),
          const SizedBox(height: 20),
          SettingsGroup(
            children: [
              _buildNotificationsRow(s),
              _buildAppearanceRow(s),
              if (widget.chatApi != null) _buildDevicesRow(s),
              _buildStorageRow(s),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileSection(s),
        const SizedBox(height: 20),
        _buildLanguageGroup(s),
        const SizedBox(height: 20),
        SettingsGroup(
          children: [
            if (_canCheckBiometrics) _buildBiometricRow(s),
            _buildPrivacyRow(s),
            _buildVersionRow(s),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileSection(S s) {
    final initials = _displayName.isNotEmpty
        ? _displayName
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'U';

    final island = widget.chatOnly && IslandPullAvatar.supported(context);
    if (island) return _buildIslandProfile(s);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          PersonAvatar(
            name: _displayName.isNotEmpty ? _displayName : initials,
            size: 80,
            sources: _photoSources,
          ),
          const SizedBox(height: 16),
          Text(
            _displayName.isNotEmpty ? _displayName : 'UZTEXPRO',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.3,
            ),
          ),
          if (_email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF8A8A8E),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8A8A8E),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_login.isNotEmpty && _login != _displayName) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Color(0xFFB0B0B5),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  _login,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The profile under an avatar that hangs from the Dynamic Island, laid out
  /// the way davrtruck does it: the name starts right under the avatar, then
  /// the login and the e-mail in small gray lines.
  Widget _buildIslandProfile(S s) {
    // From the top of the page content to just under the avatar's foot.
    final room = math.max(
      0.0,
      IslandPullAvatar.restBottom(context) + 6 - (16 + widget.topInset),
    );
    return Column(
      children: [
        SizedBox(height: room),
        Text(
          _displayName.isNotEmpty ? _displayName : 'UZTEXPRO',
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontWeight: FontWeight.w700,
            fontSize: 22,
            height: 1.27,
          ),
        ),
        if (_login.isNotEmpty && _login != _displayName) ...[
          const SizedBox(height: 2),
          Text(
            '@$_login',
            style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
          ),
        ],
        if (_email.isNotEmpty)
          Text(
            _email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildLanguageGroup(S s) {
    final currentCode = localeNotifier.value.languageCode;
    final selectedIndex = _languages
        .indexWhere((lang) => lang['code'] == currentCode)
        .clamp(0, _languages.length - 1);

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: Icons.language_rounded,
          color: SettingsColors.blue,
          title: s.language,
          subtitle: s.languageDesc,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: _buildLanguageControl(selectedIndex),
        ),
      ],
    );
  }

  void _selectLanguage(int index) {
    HapticFeedback.selectionClick();
    final code = _languages[index]['code']!;
    localeNotifier.value = Locale(code);
    _storage.write(key: 'locale', value: code);
  }

  Widget _buildLanguageControl(int selectedIndex) {
    final labels = _languages
        .map((lang) => lang['code']!.toUpperCase())
        .toList();

    // A plain Flutter switch on every platform: the native one blinked while
    // a page slid over this screen.
    return _LanguageSegments(
      labels: labels,
      selectedIndex: selectedIndex,
      onChanged: _selectLanguage,
    );
  }

  Widget _buildBiometricRow(S s) {
    // An iPhone is always Face ID, even while it reports nothing (a simulator,
    // or Face ID not set up yet); other devices show what they report.
    final isFaceId =
        _biometricType == BiometricType.face ||
        (_biometricType == null && Platform.isIOS);

    return SettingsRow(
      leading: isFaceId
          ? const FaceIdTile()
          : const SettingsIconTile(
              icon: Icons.fingerprint,
              color: SettingsColors.green,
            ),
      title: s.biometricAuth,
      subtitle: isFaceId ? s.useFaceId : s.useFingerprint,
      onTap: () => _toggleBiometricPreference(!_useBiometrics),
      trailing: AdaptiveSwitch(
        value: _useBiometrics,
        onChanged: _toggleBiometricPreference,
        activeColor: _gradientStart,
      ),
    );
  }

  Future<void> _countChatStorage() async {
    await ChatMediaStore.init();
    final bytes = await ChatMediaStore.usedBytes();
    if (mounted) setState(() => _chatBytes = bytes);
  }

  /// "Notifications and sounds": the in-app sounds, vibration and banners.
  Widget _buildNotificationsRow(S s) {
    return SettingsRow(
      icon: Icons.notifications_rounded,
      color: const Color(0xFFFF3B30),
      title: s.notifTitle,
      onTap: () => Navigator.push(
        context,
        InstantRoute(builder: (_) => ChatNotificationsPage(api: widget.chatApi)),
      ),
    );
  }

  /// "Chat appearance": text size and wallpaper.
  Widget _buildAppearanceRow(S s) {
    return SettingsRow(
      icon: Icons.palette_rounded,
      color: SettingsColors.indigo,
      title: s.appearanceTitle,
      onTap: () => Navigator.push(
        context,
        InstantRoute(builder: (_) => const ChatAppearancePage()),
      ),
    );
  }

  /// "Devices": the phones that get my push notifications.
  Widget _buildDevicesRow(S s) {
    return SettingsRow(
      icon: Icons.devices_rounded,
      color: SettingsColors.green,
      title: s.devicesTitle,
      onTap: () => Navigator.push(
        context,
        FadeRoute(builder: (_) => ChatDevicesPage(api: widget.chatApi!)),
      ),
    );
  }

  /// "Data and storage": automatic downloads, how long files are kept, and how
  /// much they take now.
  Widget _buildStorageRow(S s) {
    final bytes = _chatBytes;
    return SettingsRow(
      icon: Icons.cleaning_services_rounded,
      color: SettingsColors.orange,
      title: s.dataTitle,
      value: bytes == null ? null : formatFileSize(bytes),
      onTap: () async {
        await Navigator.push(
          context,
          InstantRoute(builder: (_) => const ChatDataPage()),
        );
        if (mounted) _countChatStorage();
      },
    );
  }

  Widget _buildPrivacyRow(S s) {
    return SettingsRow(
      icon: Icons.shield_outlined,
      color: SettingsColors.blue,
      title: s.privacyPolicy,
      subtitle: s.privacyPolicyDesc,
      onTap: () => Navigator.push(
        context,
        FadeRoute(builder: (_) => const PrivacyPolicyPage()),
      ),
    );
  }

  /// App version: plain information, nothing opens on tap, so no dialog route
  /// is involved and the native tab bar and toolbar never disappear.
  Widget _buildVersionRow(S s) {
    final year = DateTime.now().year;
    final copyright = year > 2026 ? '© 2026–$year UztexPro' : '© 2026 UztexPro';
    return SettingsRow(
      icon: Icons.info_outline_rounded,
      color: SettingsColors.gray,
      title: s.appVersionLabel(_version),
      subtitle: copyright,
    );
  }
}

/// Android's stand-in for [AdaptiveSegmentedControl]: a plain pill-track
/// selector matching iOS's native segmented control look — light gray
/// track, white selected pill, brand-red selected label.
class _LanguageSegments extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _LanguageSegments({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? _SettingsScreenState._gradientStart
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
