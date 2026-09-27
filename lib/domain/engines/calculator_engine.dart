import 'dart:math' as math;

/// One month of a loan's life.
class AmortisationRow {
  const AmortisationRow({
    required this.month,
    required this.payment,
    required this.interest,
    required this.principal,
    required this.balance,
  });

  /// One-based month number.
  final int month;

  final double payment;
  final double interest;
  final double principal;

  /// Outstanding after this payment.
  final double balance;
}

class EmiResult {
  const EmiResult({
    required this.principal,
    required this.annualRate,
    required this.months,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.schedule,
  });

  final double principal;
  final double annualRate;
  final int months;

  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;

  /// Month-by-month breakdown, for the repayment timeline chart.
  final List<AmortisationRow> schedule;

  /// Interest as a share of everything paid — the number that changes minds.
  double get interestShare =>
      totalPayment <= 0 ? 0 : totalInterest / totalPayment;

  /// Interest as a share of the amount borrowed.
  double get interestToPrincipal =>
      principal <= 0 ? 0 : totalInterest / principal;

  /// Share of monthly income this EMI would consume.
  double shareOfIncome(double monthlyIncome) =>
      monthlyIncome <= 0 ? 0 : monthlyPayment / monthlyIncome;

  /// Lenders and every sane guideline cap total EMIs near 40% of income; 30% is
  /// where it stops hurting.
  bool isComfortable(double monthlyIncome) =>
      monthlyIncome > 0 && shareOfIncome(monthlyIncome) <= 0.30;

  bool isStretched(double monthlyIncome) {
    final double share = shareOfIncome(monthlyIncome);
    return monthlyIncome > 0 && share > 0.30 && share <= 0.40;
  }

  /// Interest totalled per year, for a compact bar chart on long loans.
  List<double> get interestByYear {
    final List<double> out = <double>[];
    double running = 0;
    for (int i = 0; i < schedule.length; i++) {
      running += schedule[i].interest;
      if ((i + 1) % 12 == 0 || i == schedule.length - 1) {
        out.add(running);
        running = 0;
      }
    }
    return out;
  }
}

/// A point on a growth curve. Used by every interest calculator.
class GrowthPoint {
  const GrowthPoint({
    required this.period,
    required this.contributed,
    required this.interest,
    required this.balance,
  });

  /// Period index, one-based. Years for deposits, months for goal plans.
  final int period;

  /// Money put in up to this point.
  final double contributed;

  /// Interest earned up to this point.
  final double interest;

  final double balance;
}

class DepositResult {
  const DepositResult({
    required this.principal,
    required this.annualRate,
    required this.years,
    required this.compoundsPerYear,
    required this.monthlyContribution,
    required this.maturity,
    required this.totalContributed,
    required this.interest,
    required this.series,
  });

  final double principal;
  final double annualRate;
  final double years;
  final int compoundsPerYear;
  final double monthlyContribution;

  final double maturity;
  final double totalContributed;
  final double interest;

  /// Yearly balances, for the growth chart.
  final List<GrowthPoint> series;

  double get growthMultiple =>
      totalContributed <= 0 ? 0 : maturity / totalContributed;

  /// The share of the final number that you never had to earn.
  double get interestShare => maturity <= 0 ? 0 : interest / maturity;

  /// Effective annual yield once compounding is accounted for.
  double get effectiveAnnualRate {
    if (compoundsPerYear <= 0) return annualRate / 100;
    final double r = annualRate / 100 / compoundsPerYear;
    return math.pow(1 + r, compoundsPerYear).toDouble() - 1;
  }
}

class SimpleInterestResult {
  const SimpleInterestResult({
    required this.principal,
    required this.annualRate,
    required this.years,
    required this.interest,
    required this.total,
  });

  final double principal;
  final double annualRate;
  final double years;
  final double interest;
  final double total;

  /// What the same money would have made if it compounded yearly instead.
  double compoundedComparison() =>
      principal * math.pow(1 + annualRate / 100, years).toDouble();

  double get compoundingAdvantage => compoundedComparison() - total;
}

class SavingsGoalResult {
  const SavingsGoalResult({
    required this.target,
    required this.months,
    required this.annualRate,
    required this.startingAmount,
    required this.monthlyRequired,
    required this.totalContributed,
    required this.interestEarned,
    required this.series,
  });

  final double target;
  final int months;
  final double annualRate;
  final double startingAmount;

  final double monthlyRequired;
  final double totalContributed;
  final double interestEarned;
  final List<GrowthPoint> series;

  double get weeklyRequired => monthlyRequired * 12 / 52;

  double get dailyRequired => monthlyRequired * 12 / 365;

  /// What the same target costs per month with no interest at all — the honest
  /// baseline, since most people save into an account paying nothing.
  double get withoutInterest {
    if (months <= 0) return math.max(0.0, target - startingAmount);
    return math.max(0.0, (target - startingAmount) / months);
  }
}

abstract final class CalculatorEngine {
  /// Standard reducing-balance EMI.
  ///
  ///   EMI = P·r·(1+r)^n / ((1+r)^n − 1),  r = annual rate / 12 / 100
  ///
  /// A zero rate divides by zero in that formula, so it is special-cased to the
  /// obvious P/n. Both are exact, neither is approximated.
  static EmiResult emi({
    required double principal,
    required double annualRate,
    required int months,
    bool buildSchedule = true,
  }) {
    final double p = math.max(0.0, principal);
    final int n = months < 1 ? 1 : months;
    final double r = annualRate <= 0 ? 0 : annualRate / 12 / 100;

    final double payment;
    if (r == 0) {
      payment = p / n;
    } else {
      final double factor = math.pow(1 + r, n).toDouble();
      payment = p * r * factor / (factor - 1);
    }

    final List<AmortisationRow> schedule = <AmortisationRow>[];
    double balance = p;
    double interestPaid = 0;

    if (buildSchedule) {
      for (int m = 1; m <= n; m++) {
        final double interest = balance * r;
        double principalPart = payment - interest;
        if (principalPart > balance) principalPart = balance;
        balance = math.max(0.0, balance - principalPart);
        interestPaid += interest;
        schedule.add(AmortisationRow(
          month: m,
          payment: principalPart + interest,
          interest: interest,
          principal: principalPart,
          balance: balance,
        ));
      }
    } else {
      interestPaid = payment * n - p;
    }

    final double total = buildSchedule ? p + interestPaid : payment * n;

    return EmiResult(
      principal: p,
      annualRate: annualRate,
      months: n,
      monthlyPayment: payment,
      totalPayment: total,
      totalInterest: math.max(0.0, total - p),
      schedule: schedule,
    );
  }

  /// Fixed deposit or any lump sum left to compound, with optional monthly
  /// top-ups. Compounding frequency defaults to quarterly, which is what most
  /// fixed deposits actually use.
  static DepositResult fixedDeposit({
    required double principal,
    required double annualRate,
    required double years,
    int compoundsPerYear = 4,
    double monthlyContribution = 0,
  }) {
    final double p = math.max(0.0, principal);
    final double y = years <= 0 ? 0 : years;
    final int freq = compoundsPerYear < 1 ? 1 : compoundsPerYear;
    final double contribution = math.max(0.0, monthlyContribution);

    // Stepped month by month so contributions and compounding can coexist.
    final int totalMonths = (y * 12).round();
    final double periodicRate = annualRate / 100 / freq;
    int monthsPerCompound = (12 / freq).round();
    if (monthsPerCompound < 1) monthsPerCompound = 1;
    if (monthsPerCompound > 12) monthsPerCompound = 12;

    double balance = p;
    double contributed = p;
    final List<GrowthPoint> series = <GrowthPoint>[];

    for (int m = 1; m <= totalMonths; m++) {
      balance += contribution;
      contributed += contribution;

      // Interest lands on compounding boundaries; contributions in between
      // simply sit there, which is how a real deposit account behaves.
      if (m % monthsPerCompound == 0) {
        balance *= 1 + periodicRate;
      }

      if (m % 12 == 0 || m == totalMonths) {
        series.add(GrowthPoint(
          period: (m / 12).ceil(),
          contributed: contributed,
          interest: math.max(0.0, balance - contributed),
          balance: balance,
        ));
      }
    }

    if (totalMonths == 0) {
      // Horizon shorter than a month: no interest has landed yet, so report the
      // principal honestly instead of inventing a return.
      series.add(GrowthPoint(
        period: 0,
        contributed: p,
        interest: 0,
        balance: balance,
      ));
    }

    return DepositResult(
      principal: p,
      annualRate: annualRate,
      years: y,
      compoundsPerYear: freq,
      monthlyContribution: contribution,
      maturity: balance,
      totalContributed: contributed,
      interest: math.max(0.0, balance - contributed),
      series: series,
    );
  }

  /// I = P·R·T / 100.
  static SimpleInterestResult simpleInterest({
    required double principal,
    required double annualRate,
    required double years,
  }) {
    final double p = math.max(0.0, principal);
    final double y = math.max(0.0, years);
    final double interest = p * annualRate * y / 100;
    return SimpleInterestResult(
      principal: p,
      annualRate: annualRate,
      years: y,
      interest: interest,
      total: p + interest,
    );
  }

  /// A = P(1 + r/n)^(nt), with the same monthly stepping as [fixedDeposit] so
  /// recurring contributions are handled properly.
  static DepositResult compoundInterest({
    required double principal,
    required double annualRate,
    required double years,
    int compoundsPerYear = 12,
    double monthlyContribution = 0,
  }) =>
      fixedDeposit(
        principal: principal,
        annualRate: annualRate,
        years: years,
        compoundsPerYear: compoundsPerYear,
        monthlyContribution: monthlyContribution,
      );

  /// What it takes each month to hit a target by a date.
  ///
  ///   PMT = (FV − PV(1+r)^n) · r / ((1+r)^n − 1)
  ///
  /// With a zero rate this collapses to the remaining amount over the months,
  /// which is the case most users are actually in.
  static SavingsGoalResult savingsGoal({
    required double target,
    required int months,
    double annualRate = 0,
    double startingAmount = 0,
  }) {
    final double fv = math.max(0.0, target);
    final int n = months < 1 ? 1 : months;
    final double pv = math.max(0.0, startingAmount);
    final double r = annualRate <= 0 ? 0 : annualRate / 100 / 12;

    double pmt;
    if (r == 0) {
      pmt = math.max(0.0, (fv - pv) / n);
    } else {
      final double factor = math.pow(1 + r, n).toDouble();
      pmt = (fv - pv * factor) * r / (factor - 1);
      if (pmt < 0) pmt = 0;
    }

    double balance = pv;
    double contributed = pv;
    final List<GrowthPoint> series = <GrowthPoint>[];
    for (int m = 1; m <= n; m++) {
      balance += pmt;
      contributed += pmt;
      if (r > 0) balance *= 1 + r;
      series.add(GrowthPoint(
        period: m,
        contributed: contributed,
        interest: math.max(0.0, balance - contributed),
        balance: balance,
      ));
    }

    return SavingsGoalResult(
      target: fv,
      months: n,
      annualRate: annualRate,
      startingAmount: pv,
      monthlyRequired: pmt,
      totalContributed: contributed,
      interestEarned: math.max(0.0, balance - contributed),
      series: series,
    );
  }

  /// How long a target takes at a fixed monthly contribution, in months.
  /// Returns -1 when it never gets there.
  static int monthsToTarget({
    required double target,
    required double monthlyContribution,
    double startingAmount = 0,
    double annualRate = 0,
  }) {
    final double remaining = target - startingAmount;
    if (remaining <= 0) return 0;
    if (monthlyContribution <= 0) return -1;
    if (annualRate <= 0) return (remaining / monthlyContribution).ceil();

    final double r = annualRate / 100 / 12;
    double balance = startingAmount;
    int months = 0;
    // 100 years is a generous ceiling and keeps a bad input from looping.
    while (balance < target && months < 1200) {
      balance = (balance + monthlyContribution) * (1 + r);
      months++;
    }
    return balance >= target ? months : -1;
  }

  /// The largest loan a given EMI can service. Powers the affordability answers
  /// in the advisor.
  static double affordablePrincipal({
    required double monthlyPayment,
    required double annualRate,
    required int months,
  }) {
    if (monthlyPayment <= 0 || months < 1) return 0;
    final double r = annualRate <= 0 ? 0 : annualRate / 12 / 100;
    if (r == 0) return monthlyPayment * months;
    final double factor = math.pow(1 + r, months).toDouble();
    return monthlyPayment * (factor - 1) / (r * factor);
  }
}
