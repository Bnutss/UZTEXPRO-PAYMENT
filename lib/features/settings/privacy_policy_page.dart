import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/stagger_in.dart';
import 'privacy_policy_data.dart';

const Color _kInk = Color(0xFF1C1C1E);
const Color _kBody = Color(0xFF3A3A3C);
const Color _kMuted = Color(0xFF6C6C70);
const Color _kBrand = AppColors.brandOrange;
const Color _kBrandDeep = AppColors.brandRed;

const Map<String, IconData> _clauseIcons = {
  'file': Icons.description_outlined,
  'list': Icons.list_alt_rounded,
  'ban': Icons.block_rounded,
  'sliders': Icons.tune_rounded,
  'sparkles': Icons.auto_awesome_rounded,
  'lock': Icons.lock_outline_rounded,
  'face': Icons.face_rounded,
  'share': Icons.ios_share_rounded,
  'database': Icons.storage_rounded,
  'userCheck': Icons.how_to_reg_rounded,
  'smile': Icons.child_care_rounded,
  'refresh': Icons.update_rounded,
};

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> _writeUs() async {
    HapticFeedback.selectionClick();
    await launchUrl(Uri(scheme: 'mailto', path: kPrivacyEmail));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final doc =
        kPrivacyPolicy[localeNotifier.value.languageCode] ??
        kPrivacyPolicy['ru']!;
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
          title: Text(
            s.privacyTitle,
            style: const TextStyle(
              color: _kInk,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
          backgroundColor: bg,
          foregroundColor: _kInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            StaggerIn(child: _Hero(doc: doc)),
            const SizedBox(height: 14),
            for (var i = 0; i < doc.clauses.length; i++) ...[
              StaggerIn(
                delay: Duration(milliseconds: 60 + (i < 6 ? i : 6) * 40),
                child: _ClauseCard(index: i + 1, clause: doc.clauses[i]),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            _ContactCard(label: doc.contactCta, onTap: _writeUs),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Hero extends StatelessWidget {
  final PolicyDoc doc;

  const _Hero({required this.doc});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kBrand, _kBrandDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kBrandDeep.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            doc.heroTitle,
            style: const TextStyle(
              color: _kInk,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            doc.heroSub,
            style: const TextStyle(color: _kMuted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kBrand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 14,
                  color: _kBrandDeep,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    doc.updated,
                    style: const TextStyle(
                      color: _kBrandDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClauseCard extends StatelessWidget {
  final int index;
  final PolicyClause clause;

  const _ClauseCard({required this.index, required this.clause});

  @override
  Widget build(BuildContext context) {
    final isBan = clause.icon == 'ban';
    final accent = isBan ? _kBrandDeep : _kBrand;

    final paragraphs = [
      for (final p in clause.paragraphs)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            p,
            style: const TextStyle(color: _kBody, fontSize: 14, height: 1.5),
          ),
        ),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _clauseIcons[clause.icon] ?? Icons.article_outlined,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  clause.title,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: _kMuted.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (clause.note) _NoteBox(children: paragraphs) else ...paragraphs,
          for (final item in clause.items) _Bullet(item: item, isBan: isBan),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final PolicyItem item;
  final bool isBan;

  const _Bullet({required this.item, required this.isBan});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: _kBody, fontSize: 14, height: 1.5);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: isBan
                ? const Icon(Icons.close_rounded, size: 16, color: _kBrandDeep)
                : Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _kBrand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (item.lead.isNotEmpty)
                    TextSpan(
                      text: item.lead,
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  TextSpan(text: item.text),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// Выделенный блок для важных примечаний (например, про ИИ-ассистента).
class _NoteBox extends StatelessWidget {
  final List<Widget> children;

  const _NoteBox({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: _kBrand.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _kBrand, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ContactCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kBrand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    color: _kBrand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: _kInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        kPrivacyEmail,
                        style: TextStyle(color: _kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB0B0B5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
