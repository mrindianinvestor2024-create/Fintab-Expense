import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const FinTabExpenseApp());
}

class FinTabExpenseApp extends StatelessWidget {
  const FinTabExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinTab Expense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Entry {
  final String title;
  final double amount;
  final bool isIncome;
  final DateTime date;

  Entry({
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
      };

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'],
        date: DateTime.parse(json['date']),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Entry> entries = [];

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  Future<void> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('entries');
    if (raw != null) {
      final List data = jsonDecode(raw);
      setState(() {
        entries = data.map((e) => Entry.fromJson(e)).toList();
      });
    }
  }

  Future<void> saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'entries',
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  double get income =>
      entries.where((e) => e.isIncome).fold(0, (sum, e) => sum + e.amount);

  double get expense =>
      entries.where((e) => !e.isIncome).fold(0, (sum, e) => sum + e.amount);

  double get balance => income - expense;

  void addEntry() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isIncome = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Transaction'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Grocery',
                    ),
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Income'),
                    value: isIncome,
                    onChanged: (value) {
                      setDialogState(() => isIncome = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text);

                    if (title.isEmpty || amount == null || amount <= 0) {
                      return;
                    }

                    setState(() {
                      entries.insert(
                        0,
                        Entry(
                          title: title,
                          amount: amount,
                          isIncome: isIncome,
                          date: DateTime.now(),
                        ),
                      );
                    });

                    await saveEntries();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> deleteEntry(int index) async {
    setState(() => entries.removeAt(index));
    await saveEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FinTab Expense'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: loadEntries,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Current Balance',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryCard('Income', income, Icons.arrow_downward),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard('Expense', expense, Icons.arrow_upward),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text('No transactions yet. Tap + to add one.'),
                ),
              ),
            ...entries.asMap().entries.map(
              (item) {
                final index = item.key;
                final entry = item.value;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        entry.isIncome
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                    ),
                    title: Text(entry.title),
                    subtitle: Text(
                      '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.isIncome ? '+' : '-'}₹${entry.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: entry.isIncome
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deleteEntry(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _summaryCard(String label, double value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 5),
            Text(label),
            const SizedBox(height: 4),
            Text(
              '₹${value.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
