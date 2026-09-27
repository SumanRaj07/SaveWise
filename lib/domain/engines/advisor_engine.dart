import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/challenge.dart';
import '../../data/models/goal.dart';
import '../../data/models/user_profile.dart';
import 'advice.dart';
import 'budget_engine.dart';
import 'calculator_engine.dart';
import 'emergency_fund_engine.dart';
import 'goal_engine.dart';
import 'health_score_engine.dart';
import 'reminder_engine.dart';

/// One turn in the advisor conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    required this.at,
    this.bullets = const <String>[],
    this.action = AdviceAction.none,
  });

  final String id;
  final String text;
  final bool fromUser;
  final DateTime at;

  /// Supporting numbers, rendered as a small list under the reply.
  final List<String> bullets;

  /// Optional button on the reply.
  final AdviceAction action;
}

/// Everything the advisor is allowed to know: the user's own stored data, and
/// nothing else. No network, no external model, no data leaving the device.
class AdvisorSnapshot {
  const AdvisorSnapshot({
    required this.profile,
    required this.budget,
    required this.emergency,
    required this.score,
    required this.goals,
    required this.plans,
    required this.bills,
    required this.challenge,
    required this.now,
  });

  final UserProfile profile;
  final BudgetSummary budget;
  final EmergencyPlan emergency;
  final HealthScore score;
  final List<Goal> goals;
  final List<GoalPlan> plans;
  final List<BillReminder> bills;
  final DailyChallenge? challenge;
  final DateTime now;

  double get income => profile.monthlySalary;

  /// What the plan says should go into savings each month.
  double get monthlyCapacity {
    final double planned = budget.savingsTarget;
    if (planned > 0) return planned;
    return math.max(0.0, income * profile.savingsRateTarget);
  }

  double get billsOutstanding => ReminderEngine.outstanding(bills);

  /// Money genuinely free to spend before payday: what is left of the plan,
  /// minus bills that have not been paid yet.
  double get freeCash =>
      math.max(0.0, budget.remaining - billsOutstanding);

  double get discretionaryLeft {
    double sum = 0;
    for (final CategoryUsage u in budget.usage) {
      if (u.category.isDiscretionary) sum += u.remaining;
    }
    return sum < 0 ? 0 : sum;
  }

  Goal? get topGoal => GoalEngine.active(goals);

  GoalPlan? planFor(Goal goal) {
    for (final GoalPlan p in plans) {
      if (p.goal.id == goal.id) return p;
    }
    return null;
  }
}

abstract final class AdvisorEngine {
  static int _seq = 0;

  static String _id() {
    _seq++;
    return 'm${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  static ChatMessage userMessage(String text, DateTime at) => ChatMessage(
        id: _id(),
        text: text.trim(),
        fromUser: true,
        at: at,
      );

  static ChatMessage _reply(
    String text, {
    required DateTime at,
    List<String> bullets = const <String>[],
    AdviceAction action = AdviceAction.none,
  }) =>
      ChatMessage(
        id: _id(),
        text: text,
        fromUser: false,
        at: at,
        bullets: bullets,
        action: action,
      );

  /// Opening message. Sets expectations about what this thing actually is.
  static ChatMessage greeting(AdvisorSnapshot s) {
    final String name = s.profile.greetingName;
    final String hello = name.isEmpty ? 'Hello.' : 'Hello, $name.';
    return _reply(
      '$hello I am your SaveWise coach. I work entirely offline — every answer '
      'comes from the numbers you have entered on this phone, and nothing is '
      'sent anywhere. Ask me about affording something, how much to save, '
      'whether you are overspending, or how to raise your score.',
      at: s.now,
      bullets: <String>[
        'Income ${Money.format(s.income)} a month, paid on day ${s.profile.salaryDay}',
        'Health score ${s.score.total}/100 — ${s.score.grade.label}',
        '${s.budget.cycle.daysLeft} days until your next payday',
      ],
    );
  }

  /// Chips under the input. They change with the user's situation, so they are
  /// always worth tapping.
  static List<String> suggestedQuestions(AdvisorSnapshot s) {
    final List<String> out = <String>[];
    if (s.budget.totalLimit <= 0) out.add('Help me set a budget');
    out.add('Am I overspending?');
    out.add('How much should I save?');
    if (!s.emergency.hasMinimum) out.add('How is my emergency fund?');
    final Goal? g = s.topGoal;
    if (g != null) {
      out.add('Can I reach ${g.name} faster?');
    } else {
      out.add('What goal should I start?');
    }
    out.add('How can I improve my score?');
    if (s.bills.isNotEmpty) out.add('What bills are coming up?');
    out.add('Can I afford something?');
    return out.take(6).toList(growable: false);
  }

  /// Short standalone facts for the insights strip.
  static List<String> insights(AdvisorSnapshot s) {
    final List<String> out = <String>[];
    if (s.income > 0) {
      out.add('You are saving ${Money.percent(s.budget.savingsRate)} of income '
          'this cycle against a ${Money.percent(s.profile.savingsRateTarget)} target.');
    }
    if (s.budget.totalLimit > 0) {
      out.add('${Money.format(s.budget.safeDailySpend)} a day keeps you inside '
          'the plan for the ${s.budget.cycle.daysLeft} days left.');
    }
    final CategoryUsage? biggest = s.budget.largestSpend;
    if (biggest != null) {
      out.add('${biggest.category.label} is your largest category at '
          '${Money.format(biggest.spent)}.');
    }
    out.add(s.emergency.balance <= 0
        ? 'You have no emergency fund yet. Three months of essentials is '
            '${Money.format(s.emergency.minTarget)}.'
        : 'Your fund covers ${s.emergency.coverageMonths.toStringAsFixed(1)} '
            'months of essential spending.');
    if (s.profile.streak > 0) {
      out.add('${s.profile.streak}-day challenge streak. '
          '${ChallengeStreakCopy.next(s.profile.streak)}');
    }
    final BillReminder? next = ReminderEngine.next(s.bills);
    if (next != null) {
      out.add('${next.bill.name} is ${next.dueLabel.toLowerCase()} — '
          '${Money.format(next.bill.amount)}.');
    }
    return out;
  }

  /// Answer a question. Pure keyword routing over ten intents — no model, no
  /// network, fully deterministic and therefore testable.
  static ChatMessage answer(String question, AdvisorSnapshot s) {
    final String q = question.toLowerCase().trim();
    if (q.isEmpty) return _fallback(s);

    if (_hits(q, const <String>['hi', 'hello', 'hey', 'what can you do', 'help me with']) > 0 &&
        q.length < 24) {
      return greeting(s);
    }
    if (_hits(q, const <String>['afford', 'should i buy', 'can i buy', 'worth buying']) > 0) {
      return _affordability(q, s);
    }
    if (_hits(q, const <String>['emi', 'loan', 'borrow', 'interest rate', 'instalment', 'installment']) > 0) {
      return _loan(q, s);
    }
    if (_hits(q, const <String>['emergency', 'rainy day', 'safety net', 'cushion']) > 0) {
      return _emergency(s);
    }
    if (_hits(q, const <String>['score', 'health', 'improve my rating']) > 0) {
      return _score(s);
    }
    if (_hits(q, const <String>['overspend', 'spending too much', 'where is my money', 'where does my money', 'am i spending']) > 0) {
      return _overspending(s);
    }
    if (_hits(q, const <String>['goal', 'faster', 'sooner', 'target date']) > 0) {
      return _goals(q, s);
    }
    if (_hits(q, const <String>['save', 'saving', 'savings rate', 'put aside']) > 0) {
      return _howMuchToSave(s);
    }
    if (_hits(q, const <String>['bill', 'rent', 'due', 'electricity', 'recharge', 'subscription']) > 0) {
      return _bills(s);
    }
    if (_hits(q, const <String>['budget', 'plan', 'limit', 'category', 'categories']) > 0) {
      return _budgetReview(s);
    }
    if (_hits(q, const <String>['invest', 'deposit', 'fd', 'mutual', 'stock', 'sip']) > 0) {
      return _investing(s);
    }
    return _fallback(s);
  }

  // ---------------------------------------------------------------- intents

  static ChatMessage _affordability(String q, AdvisorSnapshot s) {
    final double? amount = _amountIn(q);
    if (amount == null || amount <= 0) {
      return _reply(
        'Tell me the price and I will check it against your actual position. '
        'Right now you have ${Money.format(s.freeCash)} of genuinely free money '
        'left this cycle, and your plan puts ${Money.format(s.monthlyCapacity)} '
        'a month into savings.',
        at: s.now,
        bullets: <String>[
          'Try: "can I afford 40000"',
          '${Money.format(s.discretionaryLeft)} left in shopping and entertainment',
        ],
      );
    }

    final double free = s.freeCash;
    final double capacity = s.monthlyCapacity;
    final List<String> bullets = <String>[
      'Free this cycle: ${Money.format(free)}',
      'Monthly savings capacity: ${Money.format(capacity)}',
      if (s.billsOutstanding > 0)
        'Bills still to pay: ${Money.format(s.billsOutstanding)}',
    ];

    final String fundWarning = s.emergency.hasMinimum
        ? ''
        : ' Before anything optional, note your emergency fund is '
            '${Money.format(s.emergency.remainingToMin)} short of three months '
            'of cover — that gap costs more than this purchase saves you.';

    if (amount <= free * 0.5) {
      return _reply(
        'Yes. ${Money.format(amount)} fits comfortably — it is under half of '
        'the ${Money.format(free)} you have free before payday, so it does not '
        'touch your savings or your bills.$fundWarning',
        at: s.now,
        bullets: bullets,
        action: AdviceAction.logExpense,
      );
    }
    if (amount <= free) {
      return _reply(
        'Yes, but it uses most of your slack. ${Money.format(amount)} against '
        '${Money.format(free)} free leaves ${Money.format(free - amount)} for '
        'the remaining ${s.budget.cycle.daysLeft} days. That works only if '
        'nothing unexpected turns up.$fundWarning',
        at: s.now,
        bullets: bullets,
        action: AdviceAction.openPlanner,
      );
    }

    final int months = capacity <= 0
        ? -1
        : CalculatorEngine.monthsToTarget(
            target: amount,
            monthlyContribution: capacity,
          );

    if (amount <= capacity) {
      return _reply(
        'Not out of this cycle — but yes if you wait. ${Money.format(amount)} '
        'is roughly one month of your savings capacity. Buying it now means '
        'borrowing from money already promised to your future. Buying it next '
        'payday costs you nothing.$fundWarning',
        at: s.now,
        bullets: bullets,
        action: AdviceAction.openGoals,
      );
    }

    return _reply(
      months < 0
          ? 'Not yet. ${Money.format(amount)} is beyond your free money and you '
              'have no savings capacity set, so there is no honest path to it '
              'this month. Set a savings rate in the planner first.$fundWarning'
          : 'Not yet — and here is the real number. At '
              '${Money.format(capacity)} a month, ${Money.format(amount)} takes '
              'about $months ${months == 1 ? 'month' : 'months'}. Make it a goal '
              'with a date and the app will track it instead of you '
              'guessing.$fundWarning',
      at: s.now,
      bullets: <String>[
        ...bullets,
        if (months > 0)
          'Saving ${Money.format(Money.niceRound(amount / math.max(1, months)))} '
              'a month reaches it in $months',
      ],
      action: AdviceAction.openGoals,
    );
  }

  static ChatMessage _howMuchToSave(AdvisorSnapshot s) {
    final double target = s.income * s.profile.savingsRateTarget;
    final double saved = s.budget.saved;
    final double gap = math.max(0.0, target - saved);

    return _reply(
      s.income <= 0
          ? 'Add your monthly income in the profile screen and I can give you a '
              'real number rather than a platitude.'
          : 'Aim for ${Money.format(target)} a month — that is '
              '${Money.percent(s.profile.savingsRateTarget)} of your income. You '
              'have put away ${Money.format(saved)} this cycle, so '
              '${gap <= 0 ? 'you are already there' : '${Money.format(gap)} to go'}. '
              'Move it on payday, not at month end: whatever is left over at the '
              'end is never the same as what you meant to save.',
      at: s.now,
      bullets: <String>[
        'Weekly: ${Money.format(target * 12 / 52)}',
        'Daily: ${Money.format(target * 12 / 365)}',
        if (!s.emergency.hasMinimum)
          'Send it to the emergency fund first — ${Money.format(s.emergency.remainingToMin)} to the floor',
        if (s.emergency.hasMinimum && s.topGoal != null)
          'Then to ${s.topGoal!.name}, your highest-priority goal',
      ],
      action: AdviceAction.openPlanner,
    );
  }

  static ChatMessage _overspending(AdvisorSnapshot s) {
    if (s.budget.totalLimit <= 0) {
      return _reply(
        'I cannot tell you yet, because there are no limits to compare against. '
        'Generate a plan from your salary in the planner — it takes one tap — '
        'and from then on this question has a real answer.',
        at: s.now,
        action: AdviceAction.openPlanner,
      );
    }

    final List<CategoryUsage> over = s.budget.overspent;
    final List<CategoryUsage> watch = s.budget.watchlist;
    final double pace = s.budget.cycle.progress;
    final double used = s.budget.utilisation;

    final String verdict;
    if (over.isNotEmpty) {
      verdict = 'Yes, in ${over.length == 1 ? 'one category' : '${over.length} categories'}.';
    } else if (used > pace + 0.15) {
      verdict = 'You are ahead of pace, though nothing has broken yet.';
    } else {
      verdict = 'No. You are inside the plan.';
    }

    return _reply(
      '$verdict You have used ${Money.format(s.budget.totalSpent)} of '
      '${Money.format(s.budget.totalLimit)} — ${Money.percent(used)} of the plan '
      'with ${Money.percent(pace)} of the cycle gone. '
      '${Money.format(s.budget.safeDailySpend)} a day holds the line until payday.',
      at: s.now,
      bullets: <String>[
        for (final CategoryUsage u in over)
          '${u.category.label}: ${Money.format(u.spent)} of ${Money.format(u.limit)} — over by ${Money.format(u.overspend)}',
        for (final CategoryUsage u in watch.take(2))
          '${u.category.label} is running hot: ${Money.format(u.spent)} of ${Money.format(u.limit)}',
        if (s.budget.discretionarySpent > 0)
          'Wants so far: ${Money.format(s.budget.discretionarySpent)} — the part you can actually cut',
      ],
      action: AdviceAction.openPlanner,
    );
  }

  static ChatMessage _score(AdvisorSnapshot s) {
    final List<ScoreFactor> sorted = List<ScoreFactor>.of(s.score.factors)
      ..sort((ScoreFactor a, ScoreFactor b) =>
          b.available.compareTo(a.available));
    final ScoreFactor worst = sorted.first;
    final Recommendation? top =
        s.score.recommendations.isEmpty ? null : s.score.recommendations.first;

    return _reply(
      'You are at ${s.score.total} out of 100 — ${s.score.grade.label}. The '
      'largest single gain is ${worst.label.toLowerCase()}, worth '
      '${worst.available} points on its own. ${worst.detail}'
      '${top == null ? '' : ' Start with this: ${top.title.toLowerCase()}.'}',
      at: s.now,
      bullets: <String>[
        for (final ScoreFactor f in sorted)
          '${f.label}: ${f.earned}/${f.weight}${f.available > 0 ? ' (${f.available} available)' : ''}',
      ],
      action: top?.action ?? AdviceAction.openPlanner,
    );
  }

  static ChatMessage _goals(String q, AdvisorSnapshot s) {
    final Goal? goal = s.topGoal;
    if (goal == null) {
      return _reply(
        'You have no open goals. That is ${AppConstants.weightGoals} points of '
        'your health score sitting unclaimed, and more importantly it is the '
        'difference between saving vaguely and saving for something. Name one '
        'thing with a price and a date.',
        at: s.now,
        action: AdviceAction.openGoals,
      );
    }

    final GoalPlan? plan = s.planFor(goal);
    if (plan == null) {
      return _reply('I could not read that goal. Try opening it directly.',
          at: s.now, action: AdviceAction.openGoals);
    }

    final double faster = Money.niceRound(plan.monthlyRequired * 1.25);
    final int monthsAtFaster = faster <= 0
        ? -1
        : CalculatorEngine.monthsToTarget(
            target: goal.cost,
            monthlyContribution: faster,
            startingAmount: goal.saved,
          );

    return _reply(
      '${goal.name}: ${Money.format(goal.saved)} of ${Money.format(goal.cost)}, '
      '${goal.progressPercent}% there. The date you set needs '
      '${Money.format(plan.monthlyRequired)} a month — '
      '${Money.format(plan.dailyRequired)} a day. '
      '${plan.onTrack ? 'You are on track.' : 'Your actual pace is ${Money.format(plan.observedMonthlyPace)} a month, so it is slipping.'} '
      'To finish sooner, raise the monthly amount rather than hoping for a '
      'windfall.',
      at: s.now,
      bullets: <String>[
        'Remaining: ${Money.format(goal.remaining)}',
        'Target date: ${Dates.mediumDate(goal.targetDate)} (${Dates.durationLabel(math.max(0, plan.daysRemaining))})',
        if (plan.projectedCompletion != null)
          'At your real pace: ${Dates.mediumDate(plan.projectedCompletion!)}',
        if (monthsAtFaster > 0)
          'At ${Money.format(faster)} a month: about $monthsAtFaster ${monthsAtFaster == 1 ? 'month' : 'months'}',
      ],
      action: AdviceAction.openGoals,
    );
  }

  static ChatMessage _emergency(AdvisorSnapshot s) {
    final EmergencyPlan e = s.emergency;
    final double suggested = Money.niceRound(e.suggestedMonthly);
    final int months = e.monthsToMin(suggested);

    return _reply(
      'Your fund is ${Money.format(e.balance)} — '
      '${e.coverageMonths.toStringAsFixed(1)} months of essential spending. '
      'Readiness: ${e.readiness.label.toLowerCase()}. ${e.readiness.blurb} '
      '${e.hasMinimum ? 'The six-month mark is ${Money.format(e.idealTarget)}.' : 'The three-month floor is ${Money.format(e.minTarget)}.'}',
      at: s.now,
      bullets: <String>[
        'Three months: ${Money.format(e.minTarget)}',
        'Six months: ${Money.format(e.idealTarget)}',
        if (!e.hasMinimum) 'Still needed: ${Money.format(e.remainingToMin)}',
        if (months > 0)
          '${Money.format(suggested)} a month reaches the floor in $months ${months == 1 ? 'month' : 'months'}',
      ],
      action: AdviceAction.openEmergency,
    );
  }

  static ChatMessage _bills(AdvisorSnapshot s) {
    if (s.bills.isEmpty) {
      return _reply(
        'No bills recorded yet. Adding rent, electricity and any subscriptions '
        'makes the rest of the app honest — fixed costs are what turn a healthy '
        'looking balance into a tight month.',
        at: s.now,
        action: AdviceAction.openBills,
      );
    }
    final List<BillReminder> overdue = ReminderEngine.overdue(s.bills);
    final BillReminder? next = ReminderEngine.next(s.bills);

    return _reply(
      '${Money.format(s.billsOutstanding)} is still owed this cycle across '
      '${ReminderEngine.unpaid(s.bills).length} unpaid '
      '${ReminderEngine.unpaid(s.bills).length == 1 ? 'bill' : 'bills'}. '
      '${overdue.isEmpty ? '' : '${overdue.length} of them ${overdue.length == 1 ? 'is' : 'are'} already overdue. '}'
      '${next == null ? '' : 'Next up is ${next.bill.name}, ${next.dueLabel.toLowerCase()}.'}',
      at: s.now,
      bullets: <String>[
        for (final BillReminder r in s.bills.take(4))
          '${r.bill.name}: ${Money.format(r.bill.amount)} — ${r.dueLabel}',
        'Fixed monthly cost: ${Money.format(ReminderEngine.monthlyFixedCost(s.bills.map((BillReminder r) => r.bill).toList()))}',
      ],
      action: AdviceAction.openBills,
    );
  }

  static ChatMessage _loan(String q, AdvisorSnapshot s) {
    final double? amount = _amountIn(q);
    final double safeEmi = s.income * 0.30;
    final double principalAt10 = CalculatorEngine.affordablePrincipal(
      monthlyPayment: safeEmi,
      annualRate: 10,
      months: 60,
    );

    if (amount != null && amount > 0) {
      final EmiResult r = CalculatorEngine.emi(
        principal: amount,
        annualRate: 10,
        months: 60,
        buildSchedule: false,
      );
      return _reply(
        'On ${Money.format(amount)} over five years at 10% — a placeholder rate, '
        'change it in the calculator — the EMI is '
        '${Money.format(r.monthlyPayment)} a month and you would repay '
        '${Money.format(r.totalPayment)} in total. That is '
        '${Money.format(r.totalInterest)} of interest, '
        '${Money.percent(r.interestShare)} of everything you pay. '
        '${r.isComfortable(s.income) ? 'It sits inside the 30% of income that is generally considered safe.' : 'It takes ${Money.percent(r.shareOfIncome(s.income))} of your income, which is above the 30% comfort line.'}',
        at: s.now,
        bullets: <String>[
          'Safe EMI for your income: about ${Money.format(safeEmi)}',
          'That services roughly ${Money.format(principalAt10)} over five years',
          'Open the calculator to use the real rate and tenure',
        ],
        action: AdviceAction.openCalculator,
      );
    }

    return _reply(
      'Give me an amount and I will run it. As a rule of thumb your total EMIs '
      'should stay under 30% of income, which for you is about '
      '${Money.format(safeEmi)} a month — enough to service roughly '
      '${Money.format(principalAt10)} borrowed over five years at 10%. Borrow '
      'less than the maximum you qualify for; lenders size loans to what you '
      'can just barely pay.',
      at: s.now,
      action: AdviceAction.openCalculator,
    );
  }

  static ChatMessage _budgetReview(AdvisorSnapshot s) {
    if (s.budget.totalLimit <= 0) {
      return _reply(
        'There is no plan yet. The planner can build one from your salary '
        'instantly: essentials first, ${Money.percent(s.profile.savingsRateTarget)} '
        'to savings, the rest split across the categories you actually use. '
        'Edit any line afterwards.',
        at: s.now,
        action: AdviceAction.openPlanner,
      );
    }

    final List<CategoryUsage> ranked = List<CategoryUsage>.of(s.budget.usage)
      ..sort((CategoryUsage a, CategoryUsage b) => b.spent.compareTo(a.spent));

    return _reply(
      'Here is the cycle so far. ${Money.format(s.budget.totalSpent)} spent, '
      '${Money.format(s.budget.saved)} saved, '
      '${Money.format(s.budget.remaining)} left of the plan with '
      '${s.budget.cycle.daysLeft} days to payday. Essentials took '
      '${Money.format(s.budget.essentialsSpent)}; wants took '
      '${Money.format(s.budget.discretionarySpent)}.',
      at: s.now,
      bullets: <String>[
        for (final CategoryUsage u in ranked.take(4))
          '${u.category.label}: ${Money.format(u.spent)} of ${Money.format(u.limit)} (${Money.percent(u.utilisation)})',
        'Unallocated income: ${Money.format(s.budget.unallocated)}',
      ],
      action: AdviceAction.openPlanner,
    );
  }

  static ChatMessage _investing(AdvisorSnapshot s) => _reply(
        'I am a rules engine reading your own numbers, not a licensed adviser, '
        'so I will not name products. The ordering most people benefit from is '
        'the same everywhere: clear expensive debt, then hold three to six '
        'months of essentials in something boring and instantly accessible, '
        'then invest what is genuinely long-term. You are at '
        '${s.emergency.coverageMonths.toStringAsFixed(1)} months of cover, so '
        '${s.emergency.hasMinimum ? 'the cushion is doing its job' : 'the cushion still comes first'}. '
        'The deposit and compound-interest calculators here will show you what '
        'any rate does to your money over time.',
        at: s.now,
        bullets: <String>[
          'Emergency floor: ${Money.format(s.emergency.minTarget)}',
          'Monthly capacity: ${Money.format(s.monthlyCapacity)}',
        ],
        action: AdviceAction.openCalculator,
      );

  static ChatMessage _fallback(AdvisorSnapshot s) => _reply(
        'I did not follow that one. I can only reason about what is stored on '
        'this device — your salary, budget, expenses, goals, fund and bills. '
        'Here is where you stand: score ${s.score.total}/100, '
        '${Money.format(s.budget.remaining)} left of the plan, '
        '${Money.format(s.budget.saved)} saved this cycle, and '
        '${s.budget.cycle.daysLeft} days to payday.',
        at: s.now,
        bullets: suggestedQuestions(s).take(3).toList(growable: false),
      );

  // ----------------------------------------------------------------- helpers

  static int _hits(String q, List<String> needles) {
    int n = 0;
    for (final String needle in needles) {
      if (q.contains(needle)) n++;
    }
    return n;
  }

  /// Pull a money amount out of free text, understanding the shorthands people
  /// actually type: 50k, 1.5 lakh, 2,00,000, 3 crore, 1m.
  static double? _amountIn(String q) {
    final String cleaned = q.replaceAll(',', '');
    final RegExp re = RegExp(
      r'(\d+(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac|lacs|crore|crores|cr|m|mn|million|b|bn|billion)?',
    );
    double? best;
    for (final RegExpMatch m in re.allMatches(cleaned)) {
      final double? base = double.tryParse(m.group(1) ?? '');
      if (base == null) continue;
      final String unit = (m.group(2) ?? '').toLowerCase();
      final double multiplier = switch (unit) {
        'k' || 'thousand' => 1000,
        'lakh' || 'lakhs' || 'lac' || 'lacs' => 100000,
        'crore' || 'crores' || 'cr' => 10000000,
        'm' || 'mn' || 'million' => 1000000,
        'b' || 'bn' || 'billion' => 1000000000,
        _ => 1,
      };
      final double value = base * multiplier;
      if (best == null || value > best) best = value;
    }
    return best;
  }
}

/// Small copy helper so streak wording lives in one place.
abstract final class ChallengeStreakCopy {
  static String next(int streak) {
    final int into = streak % AppConstants.streakBonusEvery;
    final int left = AppConstants.streakBonusEvery - into;
    if (left == AppConstants.streakBonusEvery) {
      return 'Bonus coins land today.';
    }
    return '$left more ${left == 1 ? 'day' : 'days'} to the next bonus.';
  }
}
