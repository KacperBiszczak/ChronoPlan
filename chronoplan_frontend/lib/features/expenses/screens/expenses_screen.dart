import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../events/services/event_service.dart';
import '../models/expense_model.dart';
import '../services/expense_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/app_confirm_dialog.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../participants/models/participant_model.dart';
import '../../participants/services/participant_service.dart';

enum ExpenseSort {
  defaultOrder,
  amountAsc,
  amountDesc,
  titleAsc,
}

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
  final participantService = ParticipantService();
  final eventService = EventService();
  final authService = AuthService();

  final searchController = TextEditingController();

  String searchQuery = '';
  ExpenseSort selectedSort = ExpenseSort.defaultOrder;

  bool canManageExpenses = false;

  late Future<List<ExpenseModel>> expensesFuture;
  late Future<double> summaryFuture;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadData();
    loadPermissions();
  }

  void loadData() {
    expensesFuture = expenseService.getExpensesByEvent(widget.eventId);
    summaryFuture = expenseService.getExpenseSummary(widget.eventId);
  }

  Future<void> refreshExpenses() async {
    final expenses = expenseService.getExpensesByEvent(widget.eventId);
    final summary = expenseService.getExpenseSummary(widget.eventId);

    setState(() {
      expensesFuture = expenses;
      summaryFuture = summary;
    });

    await loadPermissions();
    await Future.wait([
      expenses,
      summary,
    ]);
  }

  List<ExpenseModel> filterAndSortExpenses(List<ExpenseModel> expenses) {
    final filteredExpenses = expenses.where((expense) {
      final title = expense.title.toLowerCase();
      final amount = expense.amount.toStringAsFixed(2);

      return title.contains(searchQuery) || amount.contains(searchQuery);
    }).toList();

    switch (selectedSort) {
      case ExpenseSort.defaultOrder:
        return filteredExpenses;
      case ExpenseSort.amountAsc:
        filteredExpenses.sort((a, b) => a.amount.compareTo(b.amount));
        return filteredExpenses;
      case ExpenseSort.amountDesc:
        filteredExpenses.sort((a, b) => b.amount.compareTo(a.amount));
        return filteredExpenses;
      case ExpenseSort.titleAsc:
        filteredExpenses.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        return filteredExpenses;
    }
  }

  Future<void> showCreateExpenseDialog() async {
    final participants = await loadAcceptedParticipants();

    if (!mounted) return;
    
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    int? selectedPaidById;
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
                AppSnackBar.info(
                  dialogContext,
                  'Podaj nazwę wydatku',
                );
                return;
              }

              if (amount == null || amount <= 0) {
                AppSnackBar.info(
                  dialogContext,
                  'Podaj poprawną kwotę',
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
                  paidById: selectedPaidById,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                AppSnackBar.error(
                  dialogContext,
                  e,
                  fallback: 'Błąd dodawania wydatku',
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedPaidById,
                      decoration: const InputDecoration(
                        labelText: 'Kto zapłacił?',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Ja / aktualny użytkownik'),
                        ),
                        ...participants.map(
                          (participant) {
                            final user = participant.user;

                            return DropdownMenuItem<int?>(
                              value: participant.userId,
                              child: Text(user?.name ?? user?.email ?? 'Uczestnik'),
                            );
                          },
                        ),
                      ],
                      onChanged: isLoading
                          ? null
                          : (value) {
                              setDialogState(() {
                                selectedPaidById = value;
                              });
                            },
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

      AppSnackBar.success(
        context,
        'Wydatek został dodany',
      );
    }
  }

  Future<void> showEditExpenseDialog(ExpenseModel expense) async {
    final participants = await loadAcceptedParticipants();

    if (!mounted) return;

    final titleController = TextEditingController(text: expense.title);
    final amountController = TextEditingController(
      text: expense.amount.toStringAsFixed(2),
    );

    int? selectedPaidById = expense.paidById;
    bool isLoading = false;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> updateExpense() async {
              final title = titleController.text.trim();
              final amountText = amountController.text.trim().replaceAll(',', '.');
              final amount = double.tryParse(amountText);

              if (title.isEmpty) {
                AppSnackBar.info(
                  dialogContext,
                  'Podaj nazwę wydatku',
                );
                return;
              }

              if (amount == null || amount <= 0) {
                AppSnackBar.info(
                  dialogContext,
                  'Podaj poprawną kwotę',
                );
                return;
              }

              setDialogState(() {
                isLoading = true;
              });

              try {
                await expenseService.updateExpense(
                  id: expense.id,
                  title: title,
                  amount: amount,
                  paidById: selectedPaidById,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isLoading = false;
                });

                AppSnackBar.error(
                  dialogContext,
                  e,
                  fallback: 'Błąd edycji wydatku',
                );
              }
            }

            return AlertDialog(
              title: const Text('Edytuj wydatek'),
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedPaidById,
                      decoration: const InputDecoration(
                        labelText: 'Kto zapłacił?',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Brak przypisanej osoby'),
                        ),
                        ...participants.map(
                          (participant) {
                            final user = participant.user;

                            return DropdownMenuItem<int?>(
                              value: participant.userId,
                              child: Text(user?.name ?? user?.email ?? 'Uczestnik'),
                            );
                          },
                        ),
                      ],
                      onChanged: isLoading
                          ? null
                          : (value) {
                              setDialogState(() {
                                selectedPaidById = value;
                              });
                            },
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
                  onPressed: isLoading ? null : updateExpense,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zapisz'),
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

    if (updated == true) {
      await refreshExpenses();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydatek został zaktualizowany',
      );
    }
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Szukaj wydatku...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  searchController.clear();

                  setState(() {
                    searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          searchQuery = value.trim().toLowerCase();
        });
      },
    );
  }

  Widget buildSortSelector() {
    return DropdownButtonFormField<ExpenseSort>(
      initialValue: selectedSort,
      decoration: InputDecoration(
        labelText: 'Sortowanie',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: const [
        DropdownMenuItem(
          value: ExpenseSort.defaultOrder,
          child: Text('Domyślnie'),
        ),
        DropdownMenuItem(
          value: ExpenseSort.amountAsc,
          child: Text('Kwota rosnąco'),
        ),
        DropdownMenuItem(
          value: ExpenseSort.amountDesc,
          child: Text('Kwota malejąco'),
        ),
        DropdownMenuItem(
          value: ExpenseSort.titleAsc,
          child: Text('Nazwa A-Z'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          selectedSort = value;
        });
      },
    );
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
                  AppFormatters.amount(total),
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
        subtitle: Text(
          expense.paidBy != null
              ? 'Zapłacił: ${expense.paidBy!.name}'
              : 'Brak osoby płacącej',
        ),
      trailing: canManageExpenses
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    showEditExpenseDialog(expense);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edytuj',
                ),
                IconButton(
                  onPressed: () => deleteExpense(expense),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Usuń',
                ),
              ],
            )
          : null,
      ),
    );
  }

  Future<void> deleteExpense(ExpenseModel expense) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Usuń wydatek',
      message: 'Czy na pewno chcesz usunąć wydatek "${expense.title}"?',
      confirmText: 'Usuń',
      cancelText: 'Anuluj',
      isDanger: true,
    );

    if (!mounted || !confirmed) return;

    try {
      await expenseService.deleteExpense(expense.id);

      await refreshExpenses();

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Wydatek został usunięty',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się usunąć wydatku',
      );
    }
  }

  Future<void> loadPermissions() async {
    try {
      final currentUser = await authService.getCurrentUser();
      final event = await eventService.getEventById(widget.eventId);

      if (!mounted) return;

      setState(() {
        canManageExpenses = event.creatorId == currentUser.id;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        canManageExpenses = false;
      });
    }
  }

  Future<List<ParticipantModel>> loadAcceptedParticipants() async {
    final participants = await participantService.getParticipantsByEvent(
      widget.eventId,
    );

    return participants
        .where((participant) => participant.status == 'ACCEPTED')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budżet'),
      ),
      floatingActionButton: canManageExpenses
        ? FloatingActionButton(
        onPressed: showCreateExpenseDialog,
        child: const Icon(Icons.add),
      ): null,
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
            final filteredExpenses = filterAndSortExpenses(expenses);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                buildSummaryCard(),
                const SizedBox(height: 16),

                if (expenses.isNotEmpty) ...[
                  buildSearchField(),
                  const SizedBox(height: 16),
                  buildSortSelector(),
                  const SizedBox(height: 16),
                ],

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
                ] else if (filteredExpenses.isEmpty) ...[
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.search_off,
                    size: 56,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Brak wyników',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nie znaleziono wydatków pasujących do wyszukiwania.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  ...filteredExpenses.map(buildExpenseCard),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}