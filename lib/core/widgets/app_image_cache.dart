import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The app's one disk cache for pictures from the server (avatars, report and
/// attendance photos): they are downloaded once and then come from the phone,
/// also after a restart. A week keeps a changed profile photo from staying
/// stale for long, and the count keeps the folder from growing without end.
final CacheManager appImageCache = CacheManager(
  Config(
    'uztexpro_images',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 600,
  ),
);
