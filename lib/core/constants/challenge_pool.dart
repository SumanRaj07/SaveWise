/// What a daily challenge asks of you. The engine uses this to decide how to
/// score the challenge against real spending data.
enum ChallengeKind {
  /// Move a specific amount into savings today.
  saveAmount,

  /// Log nothing in a given category today.
  noSpendCategory,

  /// Keep today's total spending under a cap.
  capSpend,

  /// A habit with no amount attached — self-reported.
  habit,
}

/// A daily challenge template.
///
/// Note what is *not* here: rupee amounts. The brief listed challenges like
/// "Save ₹50 today", but the app is locale-driven, so amounts are expressed as
/// a fraction of the user's daily discretionary budget and rounded to a clean
/// number in their own currency. Someone on a small income gets a small nudge;
/// someone on a large one gets a meaningful nudge. Same lesson either way.
class ChallengeTemplate {
  const ChallengeTemplate({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    this.amountFactor = 0,
    this.categoryId,
    this.coins = 10,
    this.xp = 25,
  });

  final String id;
  final ChallengeKind kind;

  /// May contain `{amount}`, replaced with formatted money by the engine.
  final String title;
  final String detail;

  /// Fraction of one day's discretionary budget this challenge involves.
  final double amountFactor;

  /// For [ChallengeKind.noSpendCategory].
  final String? categoryId;

  final int coins;
  final int xp;
}

/// Twenty-one templates: three weeks of variety before anything repeats.
abstract final class ChallengePool {
  static const List<ChallengeTemplate> all = <ChallengeTemplate>[
    ChallengeTemplate(
      id: 'save_small',
      kind: ChallengeKind.saveAmount,
      title: 'Save {amount} today',
      detail:
          'Move it out of spending money before the day starts. Saving first is '
          'the only version of this habit that survives a busy week.',
      amountFactor: 0.35,
      coins: 10,
      xp: 25,
    ),
    ChallengeTemplate(
      id: 'save_round_up',
      kind: ChallengeKind.saveAmount,
      title: 'Round up and save {amount}',
      detail:
          'Take the change left over from today and put it away. Small amounts '
          'compound; the habit compounds faster.',
      amountFactor: 0.2,
      coins: 8,
      xp: 20,
    ),
    ChallengeTemplate(
      id: 'save_double',
      kind: ChallengeKind.saveAmount,
      title: 'Double up: save {amount}',
      detail: 'Twice your usual daily set-aside. Pick a day you are staying in.',
      amountFactor: 0.7,
      coins: 18,
      xp: 40,
    ),
    ChallengeTemplate(
      id: 'no_delivery',
      kind: ChallengeKind.noSpendCategory,
      title: 'No food delivery today',
      detail:
          'Delivery is the single easiest line to cut without feeling poorer. '
          'Cook, or eat what is already in the fridge.',
      categoryId: 'food',
      coins: 12,
      xp: 30,
    ),
    ChallengeTemplate(
      id: 'no_shopping',
      kind: ChallengeKind.noSpendCategory,
      title: 'Buy nothing online today',
      detail:
          'No carts, no checkouts. If you still want it tomorrow, it was a real '
          'want and it will still be there.',
      categoryId: 'shopping',
      coins: 12,
      xp: 30,
    ),
    ChallengeTemplate(
      id: 'no_entertainment',
      kind: ChallengeKind.noSpendCategory,
      title: 'Free fun only today',
      detail:
          'Walk, library, a friend, a film you already own. Entertainment is a '
          'want with a lot of zero-cost substitutes.',
      categoryId: 'entertainment',
      coins: 12,
      xp: 30,
    ),
    ChallengeTemplate(
      id: 'no_transport',
      kind: ChallengeKind.noSpendCategory,
      title: 'Walk or cycle instead',
      detail: 'Skip the fare today. Cheaper, and it counts as the other kind of health.',
      categoryId: 'transport',
      coins: 10,
      xp: 25,
    ),
    ChallengeTemplate(
      id: 'cap_day',
      kind: ChallengeKind.capSpend,
      title: 'Spend under {amount} today',
      detail: 'One hard ceiling for the whole day. Log everything so it counts.',
      amountFactor: 0.6,
      coins: 15,
      xp: 35,
    ),
    ChallengeTemplate(
      id: 'cap_tight',
      kind: ChallengeKind.capSpend,
      title: 'Tight day: stay under {amount}',
      detail:
          'A deliberately uncomfortable cap. Doing this once a week is worth more '
          'than a month of vague intentions.',
      amountFactor: 0.35,
      coins: 20,
      xp: 45,
    ),
    ChallengeTemplate(
      id: 'zero_day',
      kind: ChallengeKind.capSpend,
      title: 'Zero-spend day',
      detail: 'Nothing leaves your account today. Bills already paid do not count.',
      amountFactor: 0,
      coins: 25,
      xp: 60,
    ),
    ChallengeTemplate(
      id: 'log_everything',
      kind: ChallengeKind.habit,
      title: 'Log every expense today',
      detail:
          'Every single one, including the small ones. You cannot budget what you '
          'never wrote down.',
      coins: 10,
      xp: 25,
    ),
    ChallengeTemplate(
      id: 'review_subs',
      kind: ChallengeKind.habit,
      title: 'Audit one subscription',
      detail:
          'Open your list of recurring charges and cancel one you had forgotten '
          'about. This is the highest-return five minutes in personal finance.',
      coins: 20,
      xp: 50,
    ),
    ChallengeTemplate(
      id: 'price_check',
      kind: ChallengeKind.habit,
      title: 'Price-check before you buy',
      detail:
          'One comparison before any purchase today. Knowing the range is what '
          'turns a purchase into a decision.',
      coins: 10,
      xp: 25,
    ),
    ChallengeTemplate(
      id: 'cook_twice',
      kind: ChallengeKind.habit,
      title: 'Cook once, eat twice',
      detail: 'Make enough for tomorrow. Tomorrow-you will not order in.',
      coins: 12,
      xp: 30,
    ),
    ChallengeTemplate(
      id: 'wait_24',
      kind: ChallengeKind.habit,
      title: 'Put one want on a 24-hour hold',
      detail:
          'Add it to a list instead of a cart. Most wants do not survive a day of '
          'waiting, and the ones that do are worth buying.',
      coins: 12,
      xp: 30,
    ),
    ChallengeTemplate(
      id: 'cash_only',
      kind: ChallengeKind.habit,
      title: 'Cash or one card only today',
      detail:
          'A single payment method makes the day\'s total visible instead of '
          'scattered across three apps.',
      coins: 10,
      xp: 25,
    ),
    ChallengeTemplate(
      id: 'check_balance',
      kind: ChallengeKind.habit,
      title: 'Read your budget before you spend',
      detail:
          'Open the planner first thing. Thirty seconds of looking changes what '
          'you do for the rest of the day.',
      coins: 8,
      xp: 20,
    ),
    ChallengeTemplate(
      id: 'goal_top_up',
      kind: ChallengeKind.saveAmount,
      title: 'Top up your top goal by {amount}',
      detail: 'Straight into the goal you care most about. Progress you can see.',
      amountFactor: 0.5,
      coins: 15,
      xp: 35,
    ),
    ChallengeTemplate(
      id: 'emergency_top_up',
      kind: ChallengeKind.saveAmount,
      title: 'Add {amount} to your emergency fund',
      detail:
          'The fund that stops a bad week from becoming a bad year. Feed it before '
          'anything fun.',
      amountFactor: 0.5,
      coins: 15,
      xp: 35,
    ),
    ChallengeTemplate(
      id: 'no_impulse_snack',
      kind: ChallengeKind.noSpendCategory,
      title: 'Skip the checkout extras',
      detail:
          'No snacks, drinks or add-ons bought on impulse today. These are the '
          'purchases that never make it into anyone\'s mental budget.',
      categoryId: 'food',
      coins: 10,
      xp: 25,
    ),
    ChallengeTemplate(
      id: 'plan_tomorrow',
      kind: ChallengeKind.habit,
      title: 'Plan tomorrow\'s spending tonight',
      detail:
          'Write down what tomorrow actually costs before it starts. Planned '
          'spending almost never becomes overspending.',
      coins: 12,
      xp: 30,
    ),
  ];

  static ChallengeTemplate byId(String id) => all.firstWhere(
        (ChallengeTemplate t) => t.id == id,
        orElse: () => all.first,
      );
}
