class ExpenseModel {
  final int id;
  final String title;
  final double amount;
  final int eventId;
  final int? paidById;
  final ExpenseUserModel? paidBy;
  final String? category;
  final String visibility;
  final String settlementType;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.eventId,
    required this.paidById,
    required this.paidBy,
    required this.category,
    required this.visibility,
    required this.settlementType,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      eventId: json['eventId'],
      paidById: json['paidById'],
      paidBy: json['paidBy'] == null
          ? null
          : ExpenseUserModel.fromJson(json['paidBy']),
      category: json['category'],
      visibility: json['visibility'] ?? 'PARTICIPANTS',
      settlementType: json['settlementType'] ?? 'SPLIT_EQUALLY',
    );
  }
}

class ExpenseUserModel {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;

  ExpenseUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  factory ExpenseUserModel.fromJson(Map<String, dynamic> json) {
    return ExpenseUserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class ExpenseSummaryModel {
  final double totalExpenses;
  final double settledExpensesTotal;
  final double unassignedExpensesTotal;
  final int participantCount;
  final double perPersonShare;
  final List<ExpenseBalanceModel> balances;
  final List<ExpenseSettlementModel> settlements;
  final String budgetMode;
  final bool hidden;

  ExpenseSummaryModel({
    required this.totalExpenses,
    required this.settledExpensesTotal,
    required this.unassignedExpensesTotal,
    required this.participantCount,
    required this.perPersonShare,
    required this.balances,
    required this.settlements,
    required this.budgetMode,
    required this.hidden,
  });

  factory ExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    final balancesData = json['balances'] as List? ?? [];
    final settlementsData = json['settlements'] as List? ?? [];
    

    return ExpenseSummaryModel(
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      settledExpensesTotal: (json['settledExpensesTotal'] as num).toDouble(),
      unassignedExpensesTotal:
          (json['unassignedExpensesTotal'] as num).toDouble(),
      participantCount: json['participantCount'],
      perPersonShare: (json['perPersonShare'] as num).toDouble(),
      balances: balancesData
          .map((item) => ExpenseBalanceModel.fromJson(item))
          .toList(),
      settlements: settlementsData
          .map((item) => ExpenseSettlementModel.fromJson(item))
          .toList(),
      budgetMode: json['budgetMode'] ?? 'SHARED',
      hidden: json['hidden'] == true,
    );
  }
}

class ExpenseBalanceModel {
  final ExpenseUserModel user;
  final double paid;
  final double share;
  final double balance;

  ExpenseBalanceModel({
    required this.user,
    required this.paid,
    required this.share,
    required this.balance,
  });

  factory ExpenseBalanceModel.fromJson(Map<String, dynamic> json) {
    return ExpenseBalanceModel(
      user: ExpenseUserModel.fromJson(json['user']),
      paid: (json['paid'] as num).toDouble(),
      share: (json['share'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
    );
  }
}

class ExpenseSettlementModel {
  final ExpenseUserModel from;
  final ExpenseUserModel to;
  final double amount;

  ExpenseSettlementModel({
    required this.from,
    required this.to,
    required this.amount,
  });

  factory ExpenseSettlementModel.fromJson(Map<String, dynamic> json) {
    return ExpenseSettlementModel(
      from: ExpenseUserModel.fromJson(json['from']),
      to: ExpenseUserModel.fromJson(json['to']),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}