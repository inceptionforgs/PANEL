import 'catalog_song.dart';

class CatalogDiff {
  final List<CatalogSong> alreadyInDb;
  final List<CatalogSong> missingInDb;
  final List<CatalogSong> scanned;

  const CatalogDiff({
    required this.alreadyInDb,
    required this.missingInDb,
    required this.scanned,
  });
}
