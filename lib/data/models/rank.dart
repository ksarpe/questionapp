/// One tier in the controversy-rank ladder.
///
/// The ladder is data-driven (the `ranks` table), so tiers can be added or
/// renamed without code changes. Names ship in both locales as plain columns
/// (a small fixed list, not a translations split); [nameFor] picks one.
class Rank {
  const Rank({
    required this.tier,
    required this.minStreak,
    required this.namePl,
    required this.nameEn,
    this.icon,
  });

  /// Order in the ladder (0 = the entry rank).
  final int tier;

  /// Current streak at which this rank unlocks.
  final int minStreak;

  final String namePl;
  final String nameEn;

  /// Optional icon key (e.g. 'flame', 'crown') for the client to map to a glyph.
  final String? icon;

  String nameFor(String languageCode) =>
      languageCode == 'pl' ? namePl : nameEn;

  factory Rank.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    return Rank(
      tier: asInt(json['tier']),
      minStreak: asInt(json['min_streak']),
      namePl: json['name_pl'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}

/// The default ladder, mirroring the `ranks` table seed. Used as the offline /
/// mock source so the rank sheet renders without a backend.
const List<Rank> kDefaultRanks = [
  Rank(tier: 0, minStreak: 0, namePl: 'Amator kontrowersji', nameEn: 'Controversy Amateur', icon: 'seedling'),
  Rank(tier: 1, minStreak: 3, namePl: 'Prowokator', nameEn: 'Provocateur', icon: 'spark'),
  Rank(tier: 2, minStreak: 7, namePl: 'Podżegacz', nameEn: 'Instigator', icon: 'flame'),
  Rank(tier: 3, minStreak: 14, namePl: 'Adwokat diabła', nameEn: "Devil's Advocate", icon: 'mask'),
  Rank(tier: 4, minStreak: 30, namePl: 'Mąciciel', nameEn: 'Troublemaker', icon: 'storm'),
  Rank(tier: 5, minStreak: 60, namePl: 'Wichrzyciel', nameEn: 'Agitator', icon: 'bolt'),
  Rank(tier: 6, minStreak: 100, namePl: 'Legenda kontrowersji', nameEn: 'Controversy Legend', icon: 'crown'),
];
