import 'package:flutter_test/flutter_test.dart';

import 'package:savewise/core/constants/achievement_catalog.dart';
import 'package:savewise/core/constants/app_constants.dart';
import 'package:savewise/data/models/bill.dart';
import 'package:savewise/data/models/budget.dart';
import 'package:savewise/data/models/challenge.dart';
import 'package:savewise/data/models/expense.dart';
import 'package:savewise/data/models/goal.dart';
import 'package:savewise/data/models/user_profile.dart';
import 'package:savewise/domain/engines/achievement_engine.dart';
import 'package:savewise/domain/engines/budget_engine.dart';
import 'package:savewise/domain/engines/calculator_engine.dart';
import 'package:savewise/domain/engines/challenge_engine.dart';
import 'package:savewise/domain/engines/emergency_fund_engine.dart';
import 'package:savewise/domain/engines/goal_engine.dart';
import 'package:savewise/domain/engines/health_score_engine.dart';
import 'package:savewise/domain/engines/pay_cycle.dart';
import 'package:savewise/domain/engines/reminder_engine.dart';

/// Tests for the pure engines — the parts that decide what the app tells the
/// user about their money. The UI can be eyeballed; this arithmetic cannot, so
/// it is the part worth pinning down.
///
/// Every test uses a fixed `now`, never `DateTime.now()`, so a run in December
/// behaves the same as a run in June.

/// Mid-month, mid-morning. Salary day is the 1st in most tests, which puts this
/// date squarely inside the cycle.
final DateTime now = DateTime(2026, 8, 17, 10, 30);

UserProfile profileWith({
  double salary = 60000,
  int salaryDay = 1,
  double target = 0.20,
  int coins = 0,
  int xp = 0,
  int streak = 0,
  int longestStreak = 0,
  String? lastChallengeDay,
}) =>
    UserProfile(
      name: 'Test',
      monthlySalary: salary,
      salaryDay: salaryDay,
      currencyCode: 'USD',
      currencySymbol: r'$',
      localeTag: 'en_US',
      createdAt: DateTime(2026, 1, 1),
      savingsRateTarget: target,
      coins: coins,
      xp: xp,
      streak: streak,
      longestStreak: longestStreak,
      lastChallengeDay: lastChallengeDay,
    );

Goal goalWith({
  double cost = 12000,
  double saved = 0,
  DateTime? target,
  DateTime? created,
  GoalPriority priority = GoalPriority.medium,
  DateTime? completedAt,
}) =>
    Goal(
      id: 'g1',
      name: 'Laptop',
      cost: cost,
      saved: saved,
      targetDate: target ?? DateTime(2027, 8, 17),
      createdAt: created ?? DateTime(2026, 8, 17),
      priority: priority,
      completedAt: completedAt,
    );

void main() {
  // ------------------------------------------------------------- pay cycle

  group('PayCycle', () {
    test('runs payday to payday, not calendar month', () {
      final PayCycle cycle = PayCycle.forDate(DateTime(2026, 8, 17), 25);
      expect(cycle.start, DateTime(2026, 7, 25));
      expect(cycle.end, DateTime(2026, 8, 25));
      expect(cycle.contains(DateTime(2026, 8, 1)), isTrue);
      expect(cycle.contains(DateTime(2026, 7, 24)), isFalse);
    });

    test('progress is 0 on payday and grows across the cycle', () {
      final PayCycle fresh = PayCycle.forDate(DateTime(2026, 8, 1), 1);
      expect(fresh.progress, 0);

      final PayCycle late = PayCycle.forDate(DateTime(2026, 8, 30), 1);
      expect(late.progress, greaterThan(0.9));
    });

    test('gradingProgress floors at 0.34 so day two is not marked down', () {
      // The whole point: two days in, the user has spent 6% of the cycle but is
      // graded as though a third of it has passed. Without this floor a new
      // user is told they are failing at saving before they have been paid.
      final PayCycle fresh = PayCycle.forDate(DateTime(2026, 8, 3), 1);
      expect(fresh.progress, lessThan(0.34));
      expect(fresh.gradingProgress(), 0.34);

      final PayCycle late = PayCycle.forDate(DateTime(2026, 8, 25), 1);
      expect(late.gradingProgress(), late.progress);
    });

    test('daysLeft never goes negative', () {
      final PayCycle cycle = PayCycle.forDate(DateTime(2026, 8, 17), 1);
      expect(cycle.daysLeft, greaterThanOrEqualTo(0));
      expect(cycle.elapsedDays + cycle.daysLeft, cycle.totalDays);
    });
  });

  // -------------------------------------------------------- health score

  group('HealthScoreEngine', () {
    test('the four weights total exactly 100, per the brief', () {
      expect(
        AppConstants.weightSavingsRate +
            AppConstants.weightDiscipline +
            AppConstants.weightEmergency +
            AppConstants.weightGoals,
        100,
      );
      expect(AppConstants.weightSavingsRate, 30);
      expect(AppConstants.weightDiscipline, 25);
      expect(AppConstants.weightEmergency, 25);
      expect(AppConstants.weightGoals, 20);
    });

    test('grade bands match the brief exactly', () {
      expect(HealthScoreEngine.gradeFor(100), HealthGrade.excellent);
      expect(HealthScoreEngine.gradeFor(90), HealthGrade.excellent);
      expect(HealthScoreEngine.gradeFor(89), HealthGrade.good);
      expect(HealthScoreEngine.gradeFor(75), HealthGrade.good);
      expect(HealthScoreEngine.gradeFor(74), HealthGrade.average);
      expect(HealthScoreEngine.gradeFor(50), HealthGrade.average);
      expect(HealthScoreEngine.gradeFor(49), HealthGrade.needsWork);
      expect(HealthScoreEngine.gradeFor(0), HealthGrade.needsWork);
    });

    test('score stays within 0..100 for an empty profile', () {
      final UserProfile profile = profileWith(salary: 0);
      final PayCycle cycle = PayCycle.forDate(now, 1);
      final BudgetSummary summary = BudgetEngine.summarise(
        budget: MonthlyBudget.empty('2026-08'),
        expenses: const <Expense>[],
        cycle: cycle,
        income: 0,
      );
      final HealthScore score = HealthScoreEngine.evaluate(
        profile: profile,
        summary: summary,
        emergency: EmergencyFundEngine.plan(
          balance: 0,
          essentialsMonthly: 0,
          monthlySalary: 0,
        ),
        goals: const <Goal>[],
        now: now,
      );

      expect(score.total, inInclusiveRange(0, 100));
      expect(score.factors.length, 4);
      // Weights carried on the factors must still add to 100.
      expect(
        score.factors.fold<int>(0, (int sum, ScoreFactor f) => sum + f.weight),
        100,
      );
    });

    test('funding every goal scores full marks, never zero', () {
      // Regression: the goal factor used to fall to 0 when no goals were left
      // open, so completing the last one cost 20 points and could knock a
      // profile down a whole grade band at the moment it succeeded.
      final UserProfile profile = profileWith(salary: 60000);
      final PayCycle cycle = PayCycle.forDate(now, 1);
      final BudgetSummary summary = BudgetEngine.summarise(
        budget: BudgetEngine.suggest(
          monthKey: '2026-08',
          salary: 60000,
          savingsRate: 0.20,
        ),
        expenses: const <Expense>[],
        cycle: cycle,
        income: 60000,
      );
      final EmergencyPlan fund = EmergencyFundEngine.plan(
        balance: 180000,
        essentialsMonthly: 30000,
        monthlySalary: 60000,
      );

      ScoreFactor goalFactorOf(List<Goal> goals) =>
          HealthScoreEngine.evaluate(
            profile: profile,
            summary: summary,
            emergency: fund,
            goals: goals,
            now: now,
          ).factors.firstWhere((ScoreFactor f) => f.id == 'goals');

      final ScoreFactor funded =
          goalFactorOf(<Goal>[goalWith(cost: 1000, saved: 1000)]);
      final ScoreFactor halfway =
          goalFactorOf(<Goal>[goalWith(cost: 1000, saved: 500)]);
      final ScoreFactor none = goalFactorOf(const <Goal>[]);

      expect(funded.ratio, closeTo(1.0, 0.001));
      expect(funded.ratio, greaterThan(halfway.ratio));
      // No goals at all is the one case that genuinely earns nothing, and the
      // advice nudges the user to name one.
      expect(none.ratio, 0);
    });

    test('a disciplined saver scores far above someone overspending', () {
      final UserProfile profile = profileWith(salary: 60000);
      final PayCycle cycle = PayCycle.forDate(now, 1);
      final MonthlyBudget budget = BudgetEngine.suggest(
        monthKey: '2026-08',
        salary: 60000,
        savingsRate: 0.20,
      );

      // Good: saved the target, spent modestly, fund full, goal progressing.
      final BudgetSummary good = BudgetEngine.summarise(
        budget: budget,
        expenses: <Expense>[
          Expense(
            id: 'e1',
            categoryId: 'savings',
            amount: 12000,
            date: DateTime(2026, 8, 2),
          ),
          Expense(
            id: 'e2',
            categoryId: 'food',
            amount: 3000,
            date: DateTime(2026, 8, 3),
          ),
        ],
        cycle: cycle,
        income: 60000,
      );
      final HealthScore strong = HealthScoreEngine.evaluate(
        profile: profile,
        summary: good,
        emergency: EmergencyFundEngine.plan(
          balance: 180000,
          essentialsMonthly: 30000,
          monthlySalary: 60000,
        ),
        goals: <Goal>[goalWith(cost: 12000, saved: 9000)],
        now: now,
      );

      // Bad: nothing saved, blown through every limit, no fund, no goals.
      final BudgetSummary bad = BudgetEngine.summarise(
        budget: budget,
        expenses: <Expense>[
          Expense(
            id: 'e3',
            categoryId: 'shopping',
            amount: 40000,
            date: DateTime(2026, 8, 3),
          ),
          Expense(
            id: 'e4',
            categoryId: 'entertainment',
            amount: 20000,
            date: DateTime(2026, 8, 4),
          ),
        ],
        cycle: cycle,
        income: 60000,
      );
      final HealthScore weak = HealthScoreEngine.evaluate(
        profile: profile,
        summary: bad,
        emergency: EmergencyFundEngine.plan(
          balance: 0,
          essentialsMonthly: 30000,
          monthlySalary: 60000,
        ),
        goals: const <Goal>[],
        now: now,
      );

      expect(strong.total, greaterThan(weak.total + 30));
      expect(strong.total, inInclusiveRange(0, 100));
      expect(weak.total, inInclusiveRange(0, 100));
      expect(weak.recommendations, isNotEmpty);
    });
  });

  // ------------------------------------------------------ emergency fund

  group('EmergencyFundEngine', () {
    test('targets are 3 and 6 months of essentials, not of income', () {
      final EmergencyPlan plan = EmergencyFundEngine.plan(
        balance: 0,
        essentialsMonthly: 20000,
        monthlySalary: 60000,
      );
      expect(plan.minTarget, 60000); // 3 x essentials
      expect(plan.idealTarget, 120000); // 6 x essentials
      expect(AppConstants.emergencyMinMonths, 3);
      expect(AppConstants.emergencyIdealMonths, 6);
    });

    test('falls back to half of income when no budget exists yet', () {
      final EmergencyPlan plan = EmergencyFundEngine.plan(
        balance: 0,
        essentialsMonthly: 0,
        monthlySalary: 60000,
      );
      // A zero target would render as "complete", which would be a lie.
      expect(plan.essentialsMonthly, 30000);
      expect(plan.idealTarget, 180000);
    });

    test('readiness bands map to coverage months', () {
      EmergencyReadiness readinessAt(double balance) =>
          EmergencyFundEngine.plan(
            balance: balance,
            essentialsMonthly: 10000,
            monthlySalary: 20000,
          ).readiness;

      expect(readinessAt(0), EmergencyReadiness.critical);
      expect(readinessAt(4000), EmergencyReadiness.critical); // 0.4 months
      expect(readinessAt(5000), EmergencyReadiness.low); // 0.5
      expect(readinessAt(14000), EmergencyReadiness.low); // 1.4
      expect(readinessAt(15000), EmergencyReadiness.moderate); // 1.5
      expect(readinessAt(29000), EmergencyReadiness.moderate); // 2.9
      expect(readinessAt(30000), EmergencyReadiness.safe); // 3.0 = minimum
      expect(readinessAt(59000), EmergencyReadiness.safe);
      expect(readinessAt(60000), EmergencyReadiness.excellent); // 6.0 = ideal
      expect(readinessAt(90000), EmergencyReadiness.excellent);
    });

    test('progress and remaining figures agree with each other', () {
      final EmergencyPlan plan = EmergencyFundEngine.plan(
        balance: 30000,
        essentialsMonthly: 10000,
        monthlySalary: 20000,
      );
      expect(plan.coverageMonths, closeTo(3.0, 0.001));
      expect(plan.percentOfIdeal, 50);
      expect(plan.hasMinimum, isTrue);
      expect(plan.isComplete, isFalse);
      expect(plan.remainingToMin, 0);
      expect(plan.remainingToIdeal, 30000);
      expect(plan.monthsToIdeal(10000), 3);
      expect(plan.monthsToIdeal(0), -1); // never, at zero contribution
    });
  });

  // --------------------------------------------------------------- goals

  group('GoalEngine', () {
    test('monthly, weekly and daily requirements are consistent', () {
      // Exactly one year out, nothing saved yet.
      final Goal goal = goalWith(
        cost: 12000,
        saved: 0,
        created: DateTime(2026, 8, 17),
        target: DateTime(2027, 8, 17),
      );
      final GoalPlan plan = GoalEngine.plan(goal: goal, now: now);

      expect(plan.daysRemaining, 365);
      expect(plan.monthlyRequired, closeTo(12000 / (365 / 30.44), 1));
      expect(plan.weeklyRequired, closeTo(12000 / (365 / 7), 1));
      expect(plan.dailyRequired, closeTo(12000 / 365, 0.01));
      // Daily x days should recover the full cost.
      expect(plan.dailyRequired * 365, closeTo(12000, 1));
    });

    test('a funded goal requires nothing further', () {
      final Goal goal = goalWith(cost: 12000, saved: 12000);
      final GoalPlan plan = GoalEngine.plan(goal: goal, now: now);
      expect(plan.isComplete, isTrue);
      expect(plan.monthlyRequired, 0);
      expect(plan.onTrack, isTrue);
      expect(plan.verdict, 'Funded');
    });

    test('an overdue, unfunded goal is flagged overdue', () {
      final Goal goal = goalWith(
        cost: 5000,
        saved: 1000,
        target: DateTime(2026, 7, 1), // before `now`
      );
      final GoalPlan plan = GoalEngine.plan(goal: goal, now: now);
      expect(plan.daysRemaining, lessThan(0));
      expect(plan.isOverdue, isTrue);
      expect(plan.verdict, 'Target date passed');
    });

    test('capacity is split by priority, three shares to two to one', () {
      final List<Goal> goals = <Goal>[
        goalWith(cost: 10000).copyWith(id: 'high', priority: GoalPriority.high),
        goalWith(cost: 10000)
            .copyWith(id: 'med', priority: GoalPriority.medium),
        goalWith(cost: 10000).copyWith(id: 'low', priority: GoalPriority.low),
      ];
      final Map<String, double> split =
          GoalEngine.allocate(goals: goals, monthlyCapacity: 6000);

      expect(split['high'], closeTo(3000, 0.01));
      expect(split['med'], closeTo(2000, 0.01));
      expect(split['low'], closeTo(1000, 0.01));
      expect(
        split.values.fold<double>(0, (double a, double b) => a + b),
        closeTo(6000, 0.01),
      );
    });

    test('completed goals get no allocation', () {
      final List<Goal> goals = <Goal>[
        goalWith(cost: 10000, saved: 10000).copyWith(id: 'done'),
        goalWith(cost: 10000).copyWith(id: 'open'),
      ];
      final Map<String, double> split =
          GoalEngine.allocate(goals: goals, monthlyCapacity: 1000);
      expect(split['done'] ?? 0, 0);
      expect(split['open'], closeTo(1000, 0.01));
    });

    test('milestones fire once, at 25/50/75/100', () {
      expect(AppConstants.goalMilestones, <int>[25, 50, 75, 100]);

      final Goal before = goalWith(cost: 1000, saved: 200);
      final Goal after = before.copyWith(saved: 600);
      expect(GoalEngine.newMilestones(before, after), <int>[25, 50]);

      // Already-celebrated milestones do not fire again.
      final Goal recorded = after.copyWith(milestonesUnlocked: <int>[25, 50]);
      expect(GoalEngine.newMilestones(recorded, recorded.copyWith(saved: 700)),
          isEmpty);
    });

    test('completedCount and averageProgress read the list correctly', () {
      final List<Goal> goals = <Goal>[
        goalWith(cost: 100, saved: 100).copyWith(id: 'a'),
        goalWith(cost: 100, saved: 50).copyWith(id: 'b'),
      ];
      expect(GoalEngine.completedCount(goals), 1);

      // Two figures, two different questions. The reporting average counts a
      // funded goal as a full 1, so this is (1.0 + 0.5) / 2.
      expect(GoalEngine.averageProgress(goals), closeTo(0.75, 0.001));
      // The health score's average looks only at what is still open.
      expect(GoalEngine.averageOpenProgress(goals), closeTo(0.5, 0.001));

      // Funding everything must read as finished, never as nothing.
      final List<Goal> allFunded = <Goal>[goalWith(cost: 100, saved: 100)];
      expect(GoalEngine.averageProgress(allFunded), closeTo(1.0, 0.001));
      expect(GoalEngine.averageProgress(const <Goal>[]), 0);
    });
  });

  // ---------------------------------------------------------- calculator

  group('CalculatorEngine.emi', () {
    test('matches a hand-computed amortisation', () {
      // 100,000 at 12% over 12 months. r = 1%/month.
      // EMI = P·r·(1+r)^n / ((1+r)^n - 1) = 8884.88
      final EmiResult r = CalculatorEngine.emi(
        principal: 100000,
        annualRate: 12,
        months: 12,
      );
      expect(r.monthlyPayment, closeTo(8884.88, 0.05));
      expect(r.schedule.length, 12);
      // The loan must actually finish.
      expect(r.schedule.last.balance, closeTo(0, 0.01));
      // Principal repaid must equal the amount borrowed.
      final double principalPaid = r.schedule
          .fold<double>(0, (double a, AmortisationRow x) => a + x.principal);
      expect(principalPaid, closeTo(100000, 0.01));
      expect(r.totalInterest, closeTo(6618.55, 1.0));
      expect(r.totalPayment, closeTo(106618.55, 1.0));
    });

    test('a zero-rate loan is simply principal over months', () {
      final EmiResult r = CalculatorEngine.emi(
        principal: 1200,
        annualRate: 0,
        months: 12,
      );
      expect(r.monthlyPayment, closeTo(100, 0.001));
      expect(r.totalInterest, closeTo(0, 0.001));
      expect(r.schedule.last.balance, closeTo(0, 0.001));
    });

    test('affordability thresholds sit at 30% and 40% of income', () {
      final EmiResult r = CalculatorEngine.emi(
        principal: 100000,
        annualRate: 12,
        months: 12,
      ); // ~8885/month
      expect(r.shareOfIncome(60000), closeTo(0.148, 0.001));
      expect(r.isComfortable(60000), isTrue);
      expect(r.isComfortable(25000), isFalse); // 35% of income
      expect(r.isStretched(25000), isTrue);
      expect(r.shareOfIncome(0), 0); // no divide-by-zero
    });

    test('affordablePrincipal inverts emi', () {
      final double principal = CalculatorEngine.affordablePrincipal(
        monthlyPayment: 8884.88,
        annualRate: 12,
        months: 12,
      );
      expect(principal, closeTo(100000, 1.0));
    });

    test('a longer term lowers the payment but costs more interest', () {
      final EmiResult short = CalculatorEngine.emi(
        principal: 500000,
        annualRate: 10,
        months: 36,
      );
      final EmiResult long = CalculatorEngine.emi(
        principal: 500000,
        annualRate: 10,
        months: 72,
      );
      expect(long.monthlyPayment, lessThan(short.monthlyPayment));
      expect(long.totalInterest, greaterThan(short.totalInterest));
    });
  });

  group('CalculatorEngine deposits and interest', () {
    test('simple interest is P·R·T/100', () {
      final SimpleInterestResult r = CalculatorEngine.simpleInterest(
        principal: 10000,
        annualRate: 8,
        years: 5,
      );
      expect(r.interest, closeTo(4000, 0.001));
      expect(r.total, closeTo(14000, 0.001));
      // Compounding the same money must beat simple interest.
      expect(r.compoundingAdvantage, greaterThan(0));
    });

    test('compound interest beats simple over the same horizon', () {
      final DepositResult c = CalculatorEngine.compoundInterest(
        principal: 10000,
        annualRate: 8,
        years: 5,
      );
      final SimpleInterestResult s = CalculatorEngine.simpleInterest(
        principal: 10000,
        annualRate: 8,
        years: 5,
      );
      expect(c.maturity, greaterThan(s.total));
      expect(c.interest, greaterThan(0));
      expect(c.totalContributed, closeTo(10000, 0.001));
    });

    test('a fixed deposit with no rate returns exactly what went in', () {
      final DepositResult r = CalculatorEngine.fixedDeposit(
        principal: 10000,
        annualRate: 0,
        years: 2,
        monthlyContribution: 500,
      );
      expect(r.totalContributed, closeTo(10000 + 500 * 24, 0.001));
      expect(r.maturity, closeTo(r.totalContributed, 0.001));
      expect(r.interest, closeTo(0, 0.001));
    });

    test('a horizon under one month invents no return', () {
      final DepositResult r = CalculatorEngine.fixedDeposit(
        principal: 10000,
        annualRate: 12,
        years: 0,
      );
      expect(r.maturity, closeTo(10000, 0.001));
      expect(r.interest, closeTo(0, 0.001));
      expect(r.series, isNotEmpty);
    });

    test('savings goal with no interest is remaining over months', () {
      final SavingsGoalResult r = CalculatorEngine.savingsGoal(
        target: 12000,
        months: 12,
        startingAmount: 0,
      );
      expect(r.monthlyRequired, closeTo(1000, 0.001));
      expect(r.withoutInterest, closeTo(1000, 0.001));
      expect(r.weeklyRequired, closeTo(1000 * 12 / 52, 0.001));
      expect(r.dailyRequired, closeTo(1000 * 12 / 365, 0.001));
    });

    test('a starting balance reduces what is required', () {
      final SavingsGoalResult r = CalculatorEngine.savingsGoal(
        target: 12000,
        months: 12,
        startingAmount: 6000,
      );
      expect(r.monthlyRequired, closeTo(500, 0.001));
    });

    test('an already-met target requires nothing', () {
      final SavingsGoalResult r = CalculatorEngine.savingsGoal(
        target: 5000,
        months: 12,
        startingAmount: 6000,
      );
      expect(r.monthlyRequired, 0);
      expect(r.withoutInterest, 0);
    });

    test('monthsToTarget counts honestly and reports the impossible', () {
      expect(
        CalculatorEngine.monthsToTarget(target: 1000, monthlyContribution: 100),
        10,
      );
      expect(
        CalculatorEngine.monthsToTarget(
            target: 1000, monthlyContribution: 300, startingAmount: 700),
        1,
      );
      expect(
        CalculatorEngine.monthsToTarget(target: 1000, monthlyContribution: 0),
        -1,
      );
      expect(
        CalculatorEngine.monthsToTarget(
            target: 1000, monthlyContribution: 50, startingAmount: 1000),
        0,
      );
    });
  });

  // --------------------------------------------------------------- bills

  group('ReminderEngine', () {
    Bill billDue(int day, {String id = 'b1', bool recurring = true}) => Bill(
          id: id,
          name: 'Electricity',
          type: 'Electricity',
          amount: 2000,
          dueDay: day,
          recurring: recurring,
        );

    test('urgency maps to the 7 / 3 / 1 / today windows from the brief', () {
      expect(AppConstants.reminderDays, <int>[7, 3, 1, 0]);

      // `now` is the 17th.
      final List<BillReminder> reminders = ReminderEngine.build(
        bills: <Bill>[
          billDue(17, id: 'today'),
          billDue(18, id: 'tomorrow'),
          billDue(22, id: 'thisWeek'),
          billDue(30, id: 'upcoming'),
        ],
        now: now,
      );

      BillReminder byId(String id) =>
          reminders.firstWhere((BillReminder r) => r.bill.id == id);

      expect(byId('today').urgency, BillUrgency.dueToday);
      expect(byId('tomorrow').urgency, BillUrgency.dueTomorrow);
      expect(byId('thisWeek').urgency, BillUrgency.dueThisWeek);
      expect(byId('upcoming').urgency, BillUrgency.upcoming);
    });

    test('a paid recurring bill reads as paid, not overdue', () {
      final Bill paid = Bill(
        id: 'p1',
        name: 'Rent',
        type: 'Rent',
        amount: 15000,
        dueDay: 5, // already past on the 17th
        paidMonths: const <String>['2026-08'],
      );
      final List<BillReminder> reminders =
          ReminderEngine.build(bills: <Bill>[paid], now: now);

      expect(reminders.single.urgency, BillUrgency.paid);
      expect(reminders.single.isPaid, isTrue);
      expect(reminders.single.needsAttention, isFalse);
      expect(ReminderEngine.overdue(reminders), isEmpty);
      expect(ReminderEngine.paid(reminders).length, 1);
    });

    test('unpaid and paid partition the list, and totals agree', () {
      final List<Bill> bills = <Bill>[
        billDue(18, id: 'a'),
        billDue(20, id: 'b'),
        Bill(
          id: 'c',
          name: 'Internet',
          type: 'Internet',
          amount: 1000,
          dueDay: 9,
          paidMonths: const <String>['2026-08'],
        ),
      ];
      final List<BillReminder> all =
          ReminderEngine.build(bills: bills, now: now);

      expect(all.length, 3);
      expect(
        ReminderEngine.unpaid(all).length + ReminderEngine.paid(all).length,
        all.length,
      );
      expect(ReminderEngine.outstanding(all), closeTo(4000, 0.001));
      expect(ReminderEngine.paidTotal(all), closeTo(1000, 0.001));
      expect(ReminderEngine.monthlyFixedCost(bills), closeTo(5000, 0.001));
    });

    test('unpaid bills sort soonest-first and paid ones sink', () {
      final List<BillReminder> all = ReminderEngine.build(
        bills: <Bill>[
          billDue(28, id: 'later'),
          billDue(18, id: 'sooner'),
          Bill(
            id: 'settled',
            name: 'Water',
            type: 'Water',
            amount: 500,
            dueDay: 19,
            paidMonths: const <String>['2026-08'],
          ),
        ],
        now: now,
      );
      expect(all.first.bill.id, 'sooner');
      expect(all.last.bill.id, 'settled');
    });

    test('marking paid and unpaid round-trips', () {
      final Bill bill = billDue(18);
      final Bill afterPay = ReminderEngine.markPaid(bill, DateTime(2026, 8, 18));
      expect(afterPay.isPaidFor('2026-08'), isTrue);

      final Bill afterUndo = ReminderEngine.markUnpaid(afterPay, DateTime(2026, 8, 18));
      expect(afterUndo.isPaidFor('2026-08'), isFalse);
    });

    test('next returns the soonest unpaid bill', () {
      final List<BillReminder> all = ReminderEngine.build(
        bills: <Bill>[billDue(28, id: 'later'), billDue(19, id: 'sooner')],
        now: now,
      );
      expect(ReminderEngine.next(all)?.bill.id, 'sooner');
      expect(ReminderEngine.next(const <BillReminder>[]), isNull);
    });
  });

  // ---------------------------------------------------------- challenges

  group('ChallengeEngine', () {
    test('the same day always produces the same challenge', () {
      final UserProfile profile = profileWith();
      final DailyChallenge a = ChallengeEngine.forDay(
        day: DateTime(2026, 8, 17),
        profile: profile,
      );
      final DailyChallenge b = ChallengeEngine.forDay(
        day: DateTime(2026, 8, 17),
        profile: profile,
      );
      expect(a.templateId, b.templateId);
      expect(a.title, b.title);
      expect(a.dayKey, b.dayKey);
    });

    test('consecutive completions build a streak', () {
      UserProfile profile = profileWith();

      profile = ChallengeEngine.award(
        profile: profile,
        challenge: ChallengeEngine.forDay(
          day: DateTime(2026, 8, 15),
          profile: profile,
        ),
      );
      expect(profile.streak, 1);

      profile = ChallengeEngine.award(
        profile: profile,
        challenge: ChallengeEngine.forDay(
          day: DateTime(2026, 8, 16),
          profile: profile,
        ),
      );
      expect(profile.streak, 2);
      expect(profile.longestStreak, 2);
      expect(profile.coins, greaterThan(0));
      expect(profile.xp, greaterThan(0));
    });

    test('a missed day resets the streak but keeps the best', () {
      UserProfile profile = profileWith(
        streak: 5,
        longestStreak: 5,
        lastChallengeDay: '2026-08-10',
      );
      profile = ChallengeEngine.award(
        profile: profile,
        challenge: ChallengeEngine.forDay(
          day: DateTime(2026, 8, 14), // four-day gap
          profile: profile,
        ),
      );
      expect(profile.streak, 1);
      expect(profile.longestStreak, 5);
    });

    test('the same day cannot be claimed twice', () {
      UserProfile profile = profileWith();
      final DailyChallenge challenge = ChallengeEngine.forDay(
        day: DateTime(2026, 8, 15),
        profile: profile,
      );

      profile = ChallengeEngine.award(profile: profile, challenge: challenge);
      final int coinsAfterFirst = profile.coins;

      profile = ChallengeEngine.award(profile: profile, challenge: challenge);
      expect(profile.coins, coinsAfterFirst);
      expect(profile.streak, 1);
    });

    test('every seventh day pays the streak bonus', () {
      expect(AppConstants.streakBonusEvery, 7);
      expect(ChallengeEngine.bonusDueAt(7), isTrue);
      expect(ChallengeEngine.bonusDueAt(14), isTrue);
      expect(ChallengeEngine.bonusDueAt(6), isFalse);
      expect(ChallengeEngine.bonusDueAt(0), isFalse);
      expect(ChallengeEngine.daysToBonus(5), 2);
      expect(ChallengeEngine.daysToBonus(7), 7);

      // Walk a full week and confirm the bonus actually lands. Templates in the
      // pool pay different amounts by difficulty (20-60 xp), so `xpPerChallenge`
      // is only a baseline — sum what each day actually offered rather than
      // assuming a flat rate.
      UserProfile profile = profileWith();
      int owedCoins = 0;
      int owedXp = 0;
      for (int day = 1; day <= 7; day++) {
        final DailyChallenge today = ChallengeEngine.forDay(
          day: DateTime(2026, 8, day),
          profile: profile,
        );
        owedCoins += today.coins;
        owedXp += today.xp;
        profile = ChallengeEngine.award(profile: profile, challenge: today);
      }
      expect(profile.streak, 7);

      // Day seven closes a full week, so the bonus lands exactly once, on top
      // of the seven daily payouts, and it is paid in coins only.
      expect(profile.coins, owedCoins + AppConstants.streakBonusCoins);
      expect(profile.xp, owedXp);
    });

    test('backfilling an older day pays out without touching the streak', () {
      UserProfile profile = profileWith(
        streak: 3,
        longestStreak: 3,
        lastChallengeDay: '2026-08-16',
      );
      final int coinsBefore = profile.coins;

      profile = ChallengeEngine.award(
        profile: profile,
        challenge: ChallengeEngine.forDay(
          day: DateTime(2026, 8, 12), // earlier than lastChallengeDay
          profile: profile,
        ),
      );
      expect(profile.streak, 3);
      expect(profile.coins, greaterThan(coinsBefore));
    });

    test('a stale streak is cleared on app open', () {
      final UserProfile stale = profileWith(
        streak: 9,
        longestStreak: 9,
        lastChallengeDay: '2026-08-01',
      );
      final UserProfile fresh =
          ChallengeEngine.resetStaleStreak(stale, DateTime(2026, 8, 17));
      expect(fresh.streak, 0);
      expect(fresh.longestStreak, 9); // history is never rewritten
    });

    test('xp per level is what the profile uses', () {
      final UserProfile profile =
          profileWith(xp: AppConstants.xpPerLevel * 2 + 10);
      expect(profile.level, 3);
      expect(profile.xpToNextLevel, AppConstants.xpPerLevel - 10);
      expect(profile.levelProgress, closeTo(10 / AppConstants.xpPerLevel, 1e-9));
    });
  });

  // -------------------------------------------------------- achievements

  group('AchievementEngine', () {
    AchievementInputs inputsWith({
      double salary = 10000,
      double saved = 0,
      int goals = 0,
      double fund = 0,
      int streak = 0,
    }) =>
        AchievementInputs(
          monthlySalary: salary,
          lifetimeSaved: saved,
          goalsCompleted: goals,
          emergencyFraction: fund,
          longestStreak: streak,
        );

    test('the catalogue is non-empty and every id is unique', () {
      final List<AchievementDef> all = AchievementCatalog.all;
      expect(all, isNotEmpty);
      expect(all.map((AchievementDef d) => d.id).toSet().length, all.length);
      for (final AchievementDef d in all) {
        expect(d.threshold, greaterThan(0));
        expect(d.title, isNotEmpty);
        expect(d.detail, isNotEmpty);
      }
    });

    test('nothing unlocks on an empty profile', () {
      expect(
        AchievementEngine.newlyUnlocked(
          inputs: inputsWith(),
          alreadyUnlocked: const <String>{},
        ),
        isEmpty,
      );
    });

    test('savings badges are measured in multiples of income', () {
      // One month of income saved.
      final AchievementInputs oneMonth =
          inputsWith(salary: 10000, saved: 10000);
      expect(oneMonth.savingsMultiple, closeTo(1.0, 1e-9));

      final List<AchievementDef> unlocked = AchievementEngine.newlyUnlocked(
        inputs: oneMonth,
        alreadyUnlocked: const <String>{},
      );
      expect(unlocked, isNotEmpty);
      expect(
        unlocked.every((AchievementDef d) => oneMonth.valueFor(d.metric) >= d.threshold),
        isTrue,
      );
    });

    test('an already-unlocked badge never fires twice', () {
      final AchievementInputs inputs = inputsWith(salary: 10000, saved: 50000);
      final List<AchievementDef> first = AchievementEngine.newlyUnlocked(
        inputs: inputs,
        alreadyUnlocked: const <String>{},
      );
      expect(first, isNotEmpty);

      final Set<String> known =
          first.map((AchievementDef d) => d.id).toSet();
      expect(
        AchievementEngine.newlyUnlocked(
          inputs: inputs,
          alreadyUnlocked: known,
        ),
        isEmpty,
      );
    });

    test('progress is clamped and percent tracks it', () {
      final List<AchievementProgress> list = AchievementEngine.progressList(
        inputs: inputsWith(salary: 10000, saved: 5000, streak: 3),
        unlockedAt: const <String, DateTime>{},
      );
      expect(list.length, AchievementEngine.totalCount());
      for (final AchievementProgress p in list) {
        expect(p.progress, inInclusiveRange(0.0, 1.0));
        expect(p.percent, inInclusiveRange(0, 100));
        expect(p.remaining, greaterThanOrEqualTo(0));
      }
    });

    test('nextUp picks the closest unearned badge', () {
      final AchievementProgress? next = AchievementEngine.nextUp(
        inputs: inputsWith(salary: 10000, saved: 4000, streak: 5),
        unlockedAt: const <String, DateTime>{},
      );
      expect(next, isNotNull);
      expect(next!.isUnlocked, isFalse);

      final List<AchievementProgress> locked = AchievementEngine.progressList(
        inputs: inputsWith(salary: 10000, saved: 4000, streak: 5),
        unlockedAt: const <String, DateTime>{},
      ).where((AchievementProgress p) => !p.isUnlocked).toList();

      // Nothing unearned may be closer than the one we picked.
      for (final AchievementProgress p in locked) {
        expect(p.progress, lessThanOrEqualTo(next.progress + 1e-9));
      }
    });

    test('unlockedCount counts what has been earned', () {
      final Map<String, DateTime> unlockedAt = <String, DateTime>{
        AchievementCatalog.all.first.id: DateTime(2026, 8, 1),
      };
      expect(AchievementEngine.unlockedCount(unlockedAt), 1);
    });
  });

  // -------------------------------------------------------------- budget

  group('BudgetEngine', () {
    test('a suggested plan totals the salary exactly', () {
      final MonthlyBudget budget = BudgetEngine.suggest(
        monthKey: '2026-08',
        salary: 60000,
        savingsRate: 0.20,
      );
      expect(budget.total, closeTo(60000, 0.01));
      // All seven categories from the brief are present.
      expect(budget.limits.length, BudgetCategory.values.length);
      expect(BudgetCategory.values.length, 7);
      for (final BudgetCategory c in BudgetCategory.values) {
        expect(budget.limitFor(c), greaterThanOrEqualTo(0));
      }
    });

    test('savings is not counted as spendable', () {
      final MonthlyBudget budget = BudgetEngine.suggest(
        monthKey: '2026-08',
        salary: 60000,
        savingsRate: 0.20,
      );
      expect(budget.plannedSavings, greaterThan(0));
      expect(budget.spendableTotal, closeTo(60000 - budget.plannedSavings, 0.01));
    });

    test('a zero salary yields an empty plan rather than nonsense', () {
      final MonthlyBudget budget = BudgetEngine.suggest(
        monthKey: '2026-08',
        salary: 0,
        savingsRate: 0.20,
      );
      expect(budget.total, 0);
    });

    test('summarise only counts expenses inside the cycle', () {
      final PayCycle cycle = PayCycle.forDate(now, 1); // Aug 1 - Sep 1
      final BudgetSummary summary = BudgetEngine.summarise(
        budget: BudgetEngine.suggest(
          monthKey: '2026-08',
          salary: 60000,
          savingsRate: 0.20,
        ),
        expenses: <Expense>[
          Expense(
            id: 'in',
            categoryId: 'food',
            amount: 1000,
            date: DateTime(2026, 8, 5),
          ),
          Expense(
            id: 'out',
            categoryId: 'food',
            amount: 9999,
            date: DateTime(2026, 7, 5), // previous cycle
          ),
        ],
        cycle: cycle,
        income: 60000,
      );
      expect(summary.forCategory(BudgetCategory.food).spent, closeTo(1000, 0.01));
      expect(summary.totalSpent, closeTo(1000, 0.01));
    });

    test('overspending is detected and reported', () {
      final MonthlyBudget budget = BudgetEngine.suggest(
        monthKey: '2026-08',
        salary: 60000,
        savingsRate: 0.20,
      );
      final double foodLimit = budget.limitFor(BudgetCategory.food);
      final BudgetSummary summary = BudgetEngine.summarise(
        budget: budget,
        expenses: <Expense>[
          Expense(
            id: 'e1',
            categoryId: 'food',
            amount: foodLimit + 500,
            date: DateTime(2026, 8, 5),
          ),
        ],
        cycle: PayCycle.forDate(now, 1),
        income: 60000,
      );

      final CategoryUsage food = summary.forCategory(BudgetCategory.food);
      expect(food.isOver, isTrue);
      expect(food.overspend, closeTo(500, 0.01));
      expect(food.status, BudgetStatus.over);
      expect(summary.overspent, isNotEmpty);
      expect(BudgetEngine.alerts(summary), isNotEmpty);
    });

    test('savings rate is derived from what was actually saved', () {
      final BudgetSummary summary = BudgetEngine.summarise(
        budget: BudgetEngine.suggest(
          monthKey: '2026-08',
          salary: 60000,
          savingsRate: 0.20,
        ),
        expenses: <Expense>[
          Expense(
            id: 's1',
            categoryId: 'savings',
            amount: 6000,
            date: DateTime(2026, 8, 5),
          ),
        ],
        cycle: PayCycle.forDate(now, 1),
        income: 60000,
      );
      expect(summary.saved, closeTo(6000, 0.01));
      expect(summary.savingsRate, closeTo(0.10, 0.001));
    });

    test('rollForward carries limits into the next month', () {
      final MonthlyBudget august = BudgetEngine.suggest(
        monthKey: '2026-08',
        salary: 60000,
        savingsRate: 0.20,
      );
      final MonthlyBudget september =
          BudgetEngine.rollForward(previous: august, monthKey: '2026-09');
      expect(september.monthKey, '2026-09');
      expect(september.limits, august.limits);
    });
  });
}
