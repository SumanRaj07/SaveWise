/// Storage keys, versioned so a future migration can read the old shape.
///
/// Every key is prefixed by [LocalStore] before it hits disk, so wiping the app
/// only ever removes SaveWise's own data.
abstract final class StorageKeys {
  static const String profile = 'profile';
  static const String budgets = 'budgets';
  static const String expenses = 'expenses';
  static const String goals = 'goals';
  static const String emergencyFund = 'emergencyFund';
  static const String bills = 'bills';
  static const String dailyChallenges = 'dailyChallenges';
  static const String savingsChallenges = 'savingsChallenges';
  static const String achievements = 'achievements';
  static const String snapshots = 'snapshots';
  static const String advisorHistory = 'advisorHistory';
  static const String setupComplete = 'setupComplete';
  static const String lastOpenedMonth = 'lastOpenedMonth';
}
