import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/expense_model.dart';
import '../services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  final int eventId;

  const ExpensesScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final expenseService = ExpenseService();

  late Future<List<ExpenseModel>> expensesFuture;
  late Future<double> summaryFuture;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() {
    expensesFuture = expenseService.getExpensesByEvent(widget.eventId);
    summaryFuture = expenseService.getExpenseSummary(widget.eventId);
  }

  Future<void> refreshExpenses() async {
    setState(() {
      loadData();
    });
  }

  String formatAmount(double amount) {
    return '${amount.toStringAsFixed(2)} zł';
  }

  Future<void> showCreateExpenseDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    bool isLoading = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> createExpense() async {
              final title = titleController.text.trim();
              final amountText = amountController.text.trim().replaceAll(',', '.');
              final amount = double.tryParse(amountText);

              if (title.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Podaj nazwę wydatku')),
                );
                return;
              }

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Podaj poprawną kwotę')),
                );
                return;
              }

              setDialogState(() {
                isLoading = true;
              });

              try {
                await expenseService.createExpense(
                  title: title,
                  amount: amount,
                  eventId: widget.eventId,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } on DioException catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                final message =
                    error.response?.data['message'] ?? 'Błąd dodawania wydatku';

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } catch (_) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Nieoczekiwany błąd')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Nowy wydatek'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa wydatku',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kwota',
                        border: OutlineInputBorder(),
                        suffixText: 'zł',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: isLoading ? null : createExpense,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Dodaj'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();

    if (!mounted) return;

    if (created == true) {
      await refreshExpenses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wydatek został dodany')),
      );
    }
  }

  Future<void> deleteExpense(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Usuń wydatek'),
          content: Text('Czy na pewno chcesz usunąć "${expense.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Usuń'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmed != true) return;

    try {
      await expenseService.deleteExpense(expense.id);

      await refreshExpenses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wydatek został usunięty')),
      );
    } on DioException catch (error) {
      if (!mounted) return;

      final message =
          error.response?.data['message'] ?? 'Błąd usuwania wydatku';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieoczekiwany błąd')),
      );
    }
  }

  Widget buildSummaryCard() {
    return FutureBuilder<double>(
      future: summaryFuture,
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0;

        return Card(
          color: Colors.blue,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  child: Icon(Icons.payments),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Suma wydatków',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
                Text(
                  formatAmount(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildExpenseCard(ExpenseModel expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          child: Icon(Icons.receipt_long),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(formatAmount(expense.amount)),
        trailing: IconButton(
          onPressed: () => deleteExpense(expense),
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          tooltip: 'Usuń',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budżet'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showCreateExpenseDialog,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: refreshExpenses,
        child: FutureBuilder<List<ExpenseModel>>(
          future: expensesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.error_outline,
                    size: 56,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nie udało się pobrać wydatków',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: refreshExpenses,
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              );
            }

            final expenses = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                buildSummaryCard(),
                const SizedBox(height: 16),
                if (expenses.isEmpty) ...[
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.payments,
                    size: 56,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Brak wydatków',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dodaj pierwszy wydatek do tego wydarzenia.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  ...expenses.map(buildExpenseCard),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}