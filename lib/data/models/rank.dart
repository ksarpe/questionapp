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

  /// Mirrors the `ranks` row shape so a cached rank round-trips back through
  /// [Rank.fromJson] (used by the offline cache).
  Map<String, dynamic> toJson() => {
        'tier': tier,
        'min_streak': minStreak,
        'name_pl': namePl,
        'name_en': nameEn,
        'icon': icon,
      };
}

/// The default ladder, mirroring the `ranks` table seed. Used as the offline /
/// mock source so the rank sheet renders without a backend.
///
/// Keep in lockstep with the latest `ranks` re-seed migration
/// (20260625140000_expand_rank_ladder.sql): a dense, front-loaded 13-tier ladder
/// so early streaks promote every few days.
const List<Rank> kDefaultRanks = [
  Rank(tier: 0, minStreak: 0, namePl: 'Amator kontrowersji', nameEn: 'Controversy Amateur', icon: 'seedling'),
  Rank(tier: 1, minStreak: 2, namePl: 'Prowokator', nameEn: 'Provocateur', icon: 'spark'),
  Rank(tier: 2, minStreak: 4, namePl: 'Podżegacz', nameEn: 'Instigator', icon: 'flame'),
  Rank(tier: 3, minStreak: 7, namePl: 'Buntownik', nameEn: 'Rebel', icon: 'megaphone'),
  Rank(tier: 4, minStreak: 10, namePl: 'Adwokat diabła', nameEn: "Devil's Advocate", icon: 'mask'),
  Rank(tier: 5, minStreak: 14, namePl: 'Mąciciel', nameEn: 'Troublemaker', icon: 'storm'),
  Rank(tier: 6, minStreak: 20, namePl: 'Wichrzyciel', nameEn: 'Agitator', icon: 'bolt'),
  Rank(tier: 7, minStreak: 28, namePl: 'Burzyciel spokoju', nameEn: 'Peacebreaker', icon: 'whatshot'),
  Rank(tier: 8, minStreak: 40, namePl: 'Mistrz prowokacji', nameEn: 'Master Provocateur', icon: 'shield'),
  Rank(tier: 9, minStreak: 55, namePl: 'Ikona kontrowersji', nameEn: 'Controversy Icon', icon: 'star'),
  Rank(tier: 10, minStreak: 75, namePl: 'Wirtuoz skandalu', nameEn: 'Scandal Virtuoso', icon: 'diamond'),
  Rank(tier: 11, minStreak: 100, namePl: 'Legenda kontrowersji', nameEn: 'Controversy Legend', icon: 'crown'),
  Rank(tier: 12, minStreak: 140, namePl: 'Mit kontrowersji', nameEn: 'Controversy Myth', icon: 'rocket'),
];
