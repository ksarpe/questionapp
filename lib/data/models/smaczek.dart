/// A single "smaczek" — a discussion prompt that nudges the conversation about
/// a question deeper.
///
/// Whether a smaczek is unlocked is decided on the SERVER by the
/// `get_question_smaczki` RPC: a free user gets the first one readable plus the
/// rest flagged [isLocked], premium users get them all. Locked smaczki arrive
/// with a null [text] — the real wording never leaves the database — so the UI
/// only ever blurs a client-side placeholder, never hidden content. The client
/// is intentionally "dumb": it renders purely from [isLocked], it does not
/// re-decide entitlement.
class Smaczek {
  final int position;
  final bool isLocked;
  final String? text;

  const Smaczek({
    required this.position,
    required this.isLocked,
    this.text,
  });

  /// Builds a [Smaczek] from a `get_question_smaczki` row. Locked rows come
  /// back without text, so [text] stays null.
  factory Smaczek.fromJson(Map<String, dynamic> json) => Smaczek(
        position: (json['position'] as num?)?.toInt() ?? 0,
        isLocked: json['is_locked'] as bool? ?? true,
        text: json['text'] as String?,
      );

  /// Mirrors the `get_question_smaczki` row shape so a cached smaczek round-trips
  /// back through [Smaczek.fromJson] (used by the offline cache). A locked
  /// smaczek serialises its null [text] — no hidden content is ever stored.
  Map<String, dynamic> toJson() => {
        'position': position,
        'is_locked': isLocked,
        'text': text,
      };
}
