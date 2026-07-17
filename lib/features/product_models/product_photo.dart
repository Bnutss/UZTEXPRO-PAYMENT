import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// The backend returns a relative media path (or a "nofoto" placeholder when
// no photo was uploaded) — resolve it to an absolute URL, or null when
// there's nothing worth fetching.
String? resolveProductImageUrl(dynamic raw) {
  final path = raw?.toString().trim();
  if (path == null || path.isEmpty || path.contains('nofoto')) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return 'https://uztex.pro$path';
}

class ProductPhotoThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String heroTag;
  final bool isDark;
  final bool showRing;

  const ProductPhotoThumbnail({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.heroTag,
    required this.isDark,
    this.showRing = false,
  });

  void _openViewer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            ProductPhotoViewerPage(imageUrl: imageUrl!, heroTag: heroTag),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final radius = size * 0.28;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: url == null ? null : () => _openViewer(context),
        borderRadius: BorderRadius.circular(radius),
        child: Hero(
          tag: heroTag,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              border: showRing
                  ? Border.all(color: Colors.white.withOpacity(0.35), width: 1.2)
                  : null,
              boxShadow: showRing
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (_, __) => _placeholderIcon(),
                    errorWidget: (_, __, ___) => _placeholderIcon(),
                  )
                else
                  _placeholderIcon(),
                if (url != null)
                  Positioned(
                    right: size * 0.06,
                    bottom: size * 0.06,
                    child: Container(
                      padding: EdgeInsets.all(size * 0.06),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.zoom_in_rounded,
                        size: size * 0.24,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Center(
      child: Icon(
        Icons.checkroom_rounded,
        size: size * 0.42,
        color: isDark ? Colors.white24 : Colors.grey.shade400,
      ),
    );
  }
}

class ProductPhotoViewerPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String? title;

  const ProductPhotoViewerPage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: title == null
            ? null
            : Text(title!, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white54),
                  ),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
