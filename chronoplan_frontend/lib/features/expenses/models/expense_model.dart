class ExpenseModel {
  final int id;
  final String title;
  final double amount;
  final int eventId;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.eventId,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      eventId: json['eventId'],
    );
  }
}