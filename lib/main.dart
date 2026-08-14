
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinTabApp());
}

class FinTabApp extends StatelessWidget {
  const FinTabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinTab Expense',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF167A67),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const FinTabHome(),
    );
  }
}

class FinTabHome extends StatefulWidget {
  const FinTabHome({super.key});

  @override
  State<FinTabHome> createState() => _FinTabHomeState();
}

class _FinTabHomeState extends State<FinTabHome> {
  final Store store = Store();
  int tab = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    if (mounted) setState(() => loading = false);
  }

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      DashboardPage(store: store, onChanged: refresh, goTo: (i) => setState(() => tab = i)),
      ExpensePage(store: store, onChanged: refresh),
      PayPage(store: store, onChanged: refresh),
      GoalsPage(store: store, onChanged: refresh),
      MorePage(store: store, onChanged: refresh),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Expense'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), selectedIcon: Icon(Icons.qr_code_2), label: 'Pay'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Goals'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'More'),
        ],
      ),
    );
  }
}

class Store {
  static const _key = 'fintab_v4_state';

  double monthlyBudget = 15000;
  String profileName = 'Bhuvi';
  String profileRole = 'House Head';

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> goals = [];
  List<Map<String, dynamic>> savings = [];
  List<Map<String, dynamic>> bills = [];
  List<Map<String, dynamic>> incomes = [];

  final List<String> masterCategories = [
    'Grocery',
    'Rent',
    'Light Bill / Recharge',
    'Kids School Fees',
    'Milk',
    'Vegetables / Fruits',
    'Medicine / Treatment',
    'Petrol',
    'Kids Pocket Money',
    'Home Hand Cash',
    'Personal Hand Cash',
    'EMI',
    'Family Shopping',
    'Traveling',
    'Vacation / Yatra',
    'Give Mother Father',
    'Festival Celebrate',
    'New Gadgets Buying',
    'Extra Class / Activity',
    'Subscription',
    'Other',
  ];

  final List<Map<String, dynamic>> goalMaster = [
    {'name': 'Retirement', 'icon': '🏖️'},
    {'name': 'Emergency Fund', 'icon': '🛡️'},
    {'name': 'Child Education', 'icon': '🎓'},
    {'name': 'Child Marriage', 'icon': '💍'},
    {'name': 'House Purchase', 'icon': '🏠'},
    {'name': 'House Construction / Renovation', 'icon': '🧱'},
    {'name': 'Car', 'icon': '🚗'},
    {'name': 'Bike', 'icon': '🏍️'},
    {'name': 'Holiday / Vacation', 'icon': '✈️'},
    {'name': 'Business', 'icon': '💼'},
    {'name': 'Medical Fund', 'icon': '🏥'},
    {'name': 'Gold / Jewellery', 'icon': '💎'},
    {'name': 'Higher Education', 'icon': '📚'},
    {'name': 'Foreign Trip', 'icon': '🌍'},
    {'name': 'Gadgets', 'icon': '📱'},
    {'name': 'Family Function', 'icon': '🎉'},
    {'name': 'Debt Free / Loan Closure', 'icon': '✅'},
    {'name': 'Investment Corpus', 'icon': '📈'},
    {'name': 'Create My Own Goal', 'icon': '➕'},
  ];

  String get monthKey => DateFormat('yyyy-MM').format(DateTime.now());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      categories = [
        {'name': 'Grocery', 'allocated': 2000.0, 'active': true},
        {'name': 'Light Bill / Recharge', 'allocated': 1500.0, 'active': true},
        {'name': 'Petrol', 'allocated': 2000.0, 'active': true},
        {'name': 'Medicine / Treatment', 'allocated': 1000.0, 'active': true},
        {'name': 'EMI', 'allocated': 3000.0, 'active': true},
      ];
      await save();
      return;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      monthlyBudget = (data['monthlyBudget'] ?? 15000).toDouble();
      profileName = data['profileName'] ?? 'Bhuvi';
      profileRole = data['profileRole'] ?? 'House Head';
      categories = List<Map<String, dynamic>>.from((data['categories'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      expenses = List<Map<String, dynamic>>.from((data['expenses'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      goals = List<Map<String, dynamic>>.from((data['goals'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      savings = List<Map<String, dynamic>>.from((data['savings'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      bills = List<Map<String, dynamic>>.from((data['bills'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      incomes = List<Map<String, dynamic>>.from((data['incomes'] ?? []).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      await reset();
    }
  }

  Future<void> reset() async {
    monthlyBudget = 15000;
    profileName = 'Bhuvi';
    profileRole = 'House Head';
    categories = [];
    expenses = [];
    goals = [];
    savings = [];
    bills = [];
    incomes = [];
    await save();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      'monthlyBudget': monthlyBudget,
      'profileName': profileName,
      'profileRole': profileRole,
      'categories': categories,
      'expenses': expenses,
      'goals': goals,
      'savings': savings,
      'bills': bills,
      'incomes': incomes,
    }));
  }

  List<Map<String, dynamic>> get activeCategories => categories.where((e) => e['active'] == true).toList();

  double spentForMonth([String? key]) {
    final m = key ?? monthKey;
    return expenses
        .where((e) => (e['month'] ?? '') == m)
        .fold(0.0, (a, e) => a + (e['amount'] ?? 0).toDouble());
  }

  double incomeForMonth([String? key]) {
    final m = key ?? monthKey;
    return incomes
        .where((e) => (e['month'] ?? '') == m)
        .fold(0.0, (a, e) => a + (e['amount'] ?? 0).toDouble());
  }

  double categorySpent(String category, [String? key]) {
    final m = key ?? monthKey;
    return expenses
        .where((e) => (e['month'] ?? '') == m && e['category'] == category)
        .fold(0.0, (a, e) => a + (e['amount'] ?? 0).toDouble());
  }

  double totalSaved() {
    return savings.fold(0.0, (a, e) => a + (e['amount'] ?? 0).toDouble());
  }

  Future<void> addExpense({
    required double amount,
    required String category,
    String note = '',
    String paymentMode = 'Cash',
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    expenses.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'amount': amount,
      'category': category,
      'note': note,
      'paymentMode': paymentMode,
      'date': d.toIso8601String(),
      'month': DateFormat('yyyy-MM').format(d),
    });
    await save();
  }

  Future<void> addIncome(double amount, String source) async {
    final d = DateTime.now();
    incomes.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'amount': amount,
      'source': source,
      'date': d.toIso8601String(),
      'month': DateFormat('yyyy-MM').format(d),
    });
    await save();
  }

  Future<void> addSaving(double amount, String note) async {
    savings.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'amount': amount,
      'note': note,
      'date': DateTime.now().toIso8601String(),
    });
    await save();
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageHeader(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final Store store;
  final VoidCallback onChanged;
  final void Function(int) goTo;
  const DashboardPage({super.key, required this.store, required this.onChanged, required this.goTo});

  @override
  Widget build(BuildContext context) {
    final spent = store.spentForMonth();
    final remaining = store.monthlyBudget - spent;
    final dailyAvg = DateTime.now().day == 0 ? 0 : spent / DateTime.now().day;
    final topGoals = store.goals.take(3).toList();

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF167A67),
                child: Text(store.profileName.isEmpty ? 'F' : store.profileName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.profileName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  Text('${store.profileRole} • Plan • Track • Save', style: TextStyle(color: Colors.grey.shade600)),
                ]),
              ),
              IconButton(onPressed: () => showReportSheet(context, store), icon: const Icon(Icons.insights_outlined)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(DateFormat('MMMM yyyy').format(DateTime.now()), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.auto_graph, color: Color(0xFF167A67)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Daily average ₹${dailyAvg.toStringAsFixed(0)} • ${remaining >= 0 ? "₹${remaining.toStringAsFixed(0)} remaining" : "₹${remaining.abs().toStringAsFixed(0)} over budget"}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF115F54), Color(0xFF1A8A74)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Monthly Budget', style: TextStyle(color: Colors.white70, fontSize: 15)),
              Text('₹${store.monthlyBudget.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _miniStat('Spent', spent)),
                const SizedBox(width: 10),
                Expanded(child: _miniStat('Remaining', remaining)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            Expanded(child: _quick(context, Icons.add_circle_outline, 'Add Expense', () => showExpenseDialog(context, store, onChanged))),
            const SizedBox(width: 10),
            Expanded(child: _quick(context, Icons.qr_code_scanner, 'Scan & Pay', () => goTo(2))),
            const SizedBox(width: 10),
            Expanded(child: _quick(context, Icons.flag_outlined, 'Add Goal', () => goTo(3))),
          ]),
        ),
        const SizedBox(height: 20),
        if (topGoals.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text('Your Goals', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          ...topGoals.map((g) => GoalCard(goal: g, store: store, onChanged: onChanged)),
          const SizedBox(height: 16),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text('Category Snapshot', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        ...store.activeCategories.take(4).map((c) {
          final allocated = (c['allocated'] ?? 0).toDouble();
          final used = store.categorySpent(c['name']);
          final progress = allocated <= 0 ? 0.0 : (used / allocated).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('₹${(allocated - used).toStringAsFixed(0)} left'),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 5),
                  Text('Allocated ₹${allocated.toStringAsFixed(0)} • Spent ₹${used.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _miniStat(String label, double value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _quick(BuildContext context, IconData icon, String label, VoidCallback tap) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [Icon(icon, color: const Color(0xFF167A67)), const SizedBox(height: 7), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
        ),
      );
}

class ExpensePage extends StatelessWidget {
  final Store store;
  final VoidCallback onChanged;
  const ExpensePage({super.key, required this.store, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final monthExpenses = store.expenses.where((e) => e['month'] == store.monthKey).toList();
    return Column(
      children: [
        const PageHeader('Expense Tracker', subtitle: 'Add, edit and review your daily expenses'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showExpenseDialog(context, store, onChanged),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: monthExpenses.isEmpty
              ? const Center(child: Text('No expense added this month.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  itemCount: monthExpenses.length,
                  itemBuilder: (_, i) {
                    final e = monthExpenses[i];
                    final d = DateTime.tryParse(e['date'] ?? '') ?? DateTime.now();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        leading: CircleAvatar(child: Text((e['category'] ?? '?').toString().substring(0, 1))),
                        title: Text(e['category'] ?? 'Expense', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${DateFormat('dd MMM').format(d)} • ${e['paymentMode'] ?? 'Cash'}${(e['note'] ?? '').toString().isNotEmpty ? " • ${e['note']}" : ""}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('₹${(e['amount'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'delete') {
                                store.expenses.removeWhere((x) => x['id'] == e['id']);
                                await store.save();
                                onChanged();
                              } else {
                                await showExpenseDialog(context, store, onChanged, existing: e);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<void> showExpenseDialog(BuildContext context, Store store, VoidCallback onChanged, {Map<String, dynamic>? existing}) async {
  if (store.activeCategories.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('First add a category from More > Categories.')));
    return;
  }
  final amount = TextEditingController(text: existing == null ? '' : (existing['amount'] ?? '').toString());
  final note = TextEditingController(text: existing?['note'] ?? '');
  String category = existing?['category'] ?? store.activeCategories.first['name'];
  String mode = existing?['paymentMode'] ?? 'Cash';
  DateTime date = existing == null ? DateTime.now() : (DateTime.tryParse(existing['date'] ?? '') ?? DateTime.now());

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Add Expense' : 'Edit Expense'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: category,
              items: store.activeCategories.map((c) => DropdownMenuItem(value: c['name'].toString(), child: Text(c['name'].toString()))).toList(),
              onChanged: (v) => setLocal(() => category = v ?? category),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: mode,
              items: ['Cash', 'UPI', 'Card', 'Bank', 'Other'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setLocal(() => mode = v ?? mode),
              decoration: const InputDecoration(labelText: 'Payment Mode'),
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: date);
                if (picked != null) setLocal(() => date = picked);
              },
            )
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(amount.text.trim());
              if (value == null || value <= 0) return;
              if (existing == null) {
                await store.addExpense(amount: value, category: category, note: note.text.trim(), paymentMode: mode, date: date);
              } else {
                existing['amount'] = value;
                existing['category'] = category;
                existing['note'] = note.text.trim();
                existing['paymentMode'] = mode;
                existing['date'] = date.toIso8601String();
                existing['month'] = DateFormat('yyyy-MM').format(date);
                await store.save();
              }
              if (ctx.mounted) Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class PayPage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;
  const PayPage({super.key, required this.store, required this.onChanged});

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  String? lastUpiUri;
  String? lastPayee;
  double? lastAmount;
  String? lastCategory;

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (raw == null || raw.isEmpty) return;
    if (!raw.toLowerCase().startsWith('upi://pay')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This QR is not a UPI payment QR.')));
      return;
    }
    await _preparePayment(raw);
  }

  Future<void> _manual() async {
    final c = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste UPI payment link'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'upi://pay?pa=...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    if (raw != null && raw.toLowerCase().startsWith('upi://pay')) await _preparePayment(raw);
  }

  Future<void> _preparePayment(String rawUri) async {
    if (widget.store.activeCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one expense category first.')));
      return;
    }

    final uri = Uri.parse(rawUri);
    final amountC = TextEditingController(text: uri.queryParameters['am'] ?? '');
    String category = widget.store.activeCategories.first['name'];
    final payee = uri.queryParameters['pn'] ?? uri.queryParameters['pa'] ?? 'UPI Payment';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(payee),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: category,
              items: widget.store.activeCategories.map((e) => DropdownMenuItem(value: e['name'].toString(), child: Text(e['name'].toString()))).toList(),
              onChanged: (v) => setLocal(() => category = v ?? category),
              decoration: const InputDecoration(labelText: 'Expense Category'),
            )
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final a = double.tryParse(amountC.text.trim());
                if (a == null || a <= 0) return;
                Navigator.pop(ctx, {'amount': a, 'category': category});
              },
              child: const Text('Open UPI App'),
            )
          ],
        ),
      ),
    );

    if (result == null) return;
    final amount = (result['amount'] as num).toDouble();
    final newParams = Map<String, String>.from(uri.queryParameters);
    newParams['am'] = amount.toStringAsFixed(2);
    newParams['cu'] = 'INR';
    final finalUri = uri.replace(queryParameters: newParams);

    final launched = await launchUrl(finalUri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No compatible UPI app found.')));
      return;
    }

    setState(() {
      lastUpiUri = finalUri.toString();
      lastPayee = payee;
      lastAmount = amount;
      lastCategory = result['category'];
    });
  }

  Future<void> _savePaidExpense() async {
    if (lastAmount == null || lastCategory == null) return;
    await widget.store.addExpense(
      amount: lastAmount!,
      category: lastCategory!,
      paymentMode: 'UPI',
      note: lastPayee ?? 'UPI Payment',
    );
    widget.onChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment saved as expense.')));
      setState(() {
        lastUpiUri = null;
        lastPayee = null;
        lastAmount = null;
        lastCategory = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeader('Scan & Pay', subtitle: 'Scan merchant UPI QR and pay with any compatible UPI app'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F5C50), Color(0xFF1A8A74)]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Column(children: [
              Icon(Icons.qr_code_scanner, size: 72, color: Colors.white),
              SizedBox(height: 10),
              Text('FinTab Pay', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('FinTab does not hold your money. Payment is completed by your UPI app.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: FilledButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan UPI QR')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: OutlinedButton.icon(onPressed: _manual, icon: const Icon(Icons.link), label: const Text('Paste UPI Link')),
        ),
        if (lastUpiUri != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('After completing payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text('${lastPayee ?? "UPI Payment"} • ₹${lastAmount?.toStringAsFixed(2) ?? ""}'),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _savePaidExpense, icon: const Icon(Icons.check), label: const Text('Payment Completed — Save Expense'))),
                ]),
              ),
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 8),
          child: Text('How it works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text('1. Scan UPI QR\n2. Enter amount and expense category\n3. FinTab opens a compatible UPI app\n4. Complete payment there\n5. Return to FinTab and save it as an expense'),
        ),
      ],
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan UPI QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (done) return;
          final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
          if (raw != null && raw.isNotEmpty) {
            done = true;
            Navigator.pop(context, raw);
          }
        },
      ),
    );
  }
}

class GoalsPage extends StatelessWidget {
  final Store store;
  final VoidCallback onChanged;
  const GoalsPage({super.key, required this.store, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PageHeader('Saving Goals', subtitle: 'Plan your future goals and track progress'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showGoalCategoryPicker(context, store, onChanged),
              icon: const Icon(Icons.add),
              label: const Text('Create New Goal'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: store.goals.isEmpty
              ? const Center(child: Text('No goal yet. Create your first saving goal.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  children: store.goals.map((g) => GoalCard(goal: g, store: store, onChanged: onChanged)).toList(),
                ),
        )
      ],
    );
  }
}

class GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final Store store;
  final VoidCallback onChanged;
  const GoalCard({super.key, required this.goal, required this.store, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final target = (goal['target'] ?? 0).toDouble();
    final saved = (goal['saved'] ?? 0).toDouble();
    final p = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(goal['icon'] ?? '🎯', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(child: Text(goal['name'] ?? 'Goal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'add') {
                    await addMoneyToGoal(context, store, goal, onChanged);
                  } else if (v == 'delete') {
                    store.goals.removeWhere((g) => g['id'] == goal['id']);
                    await store.save();
                    onChanged();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'add', child: Text('Add Saving')),
                  PopupMenuItem(value: 'delete', child: Text('Delete Goal')),
                ],
              ),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: p, minHeight: 9, borderRadius: BorderRadius.circular(9)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('Saved ₹${saved.toStringAsFixed(0)}')),
              Text('Target ₹${target.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text('${(p * 100).toStringAsFixed(0)}% complete • ₹${(target - saved).clamp(0, double.infinity).toStringAsFixed(0)} remaining', style: TextStyle(color: Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }
}

Future<void> showGoalCategoryPicker(BuildContext context, Store store, VoidCallback onChanged) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * .82,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Choose Goal Category', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.55, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: store.goalMaster.length,
              itemBuilder: (_, i) {
                final g = store.goalMaster[i];
                return InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showCreateGoalDialog(context, store, onChanged, g['name'], g['icon']);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(children: [
                      Text(g['icon'], style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 9),
                      Expanded(child: Text(g['name'], style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

Future<void> showCreateGoalDialog(BuildContext context, Store store, VoidCallback onChanged, String categoryName, String icon) async {
  final custom = TextEditingController(text: categoryName == 'Create My Own Goal' ? '' : categoryName);
  final target = TextEditingController();
  final saved = TextEditingController(text: '0');
  DateTime targetDate = DateTime(DateTime.now().year + 5, DateTime.now().month, DateTime.now().day);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Create Goal'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: custom, decoration: const InputDecoration(labelText: 'Goal Name')),
            const SizedBox(height: 10),
            TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount ₹')),
            const SizedBox(height: 10),
            TextField(controller: saved, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Already Saved ₹')),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Target Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(targetDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final p = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime(2100), initialDate: targetDate);
                if (p != null) setLocal(() => targetDate = p);
              },
            )
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final t = double.tryParse(target.text.trim());
              final s = double.tryParse(saved.text.trim()) ?? 0;
              if (custom.text.trim().isEmpty || t == null || t <= 0) return;
              store.goals.insert(0, {
                'id': DateTime.now().microsecondsSinceEpoch.toString(),
                'name': custom.text.trim(),
                'category': categoryName,
                'icon': icon,
                'target': t,
                'saved': s,
                'targetDate': targetDate.toIso8601String(),
              });
              await store.save();
              if (ctx.mounted) Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

Future<void> addMoneyToGoal(BuildContext context, Store store, Map<String, dynamic> goal, VoidCallback onChanged) async {
  final c = TextEditingController();
  final amount = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Add saving to ${goal['name']}'),
      content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.trim())), child: const Text('Add')),
      ],
    ),
  );
  if (amount == null || amount <= 0) return;
  goal['saved'] = (goal['saved'] ?? 0).toDouble() + amount;
  await store.addSaving(amount, 'Goal: ${goal['name']}');
  await store.save();
  onChanged();
}

class MorePage extends StatelessWidget {
  final Store store;
  final VoidCallback onChanged;
  const MorePage({super.key, required this.store, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MoreItem(Icons.account_balance_wallet_outlined, 'Budget', 'Monthly budget and allocations', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetPage(store: store, onChanged: onChanged)))),
      _MoreItem(Icons.category_outlined, 'Categories', 'Choose and customize categories', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesPage(store: store, onChanged: onChanged)))),
      _MoreItem(Icons.savings_outlined, 'Savings', 'Savings history and total saved', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsPage(store: store, onChanged: onChanged)))),
      _MoreItem(Icons.notifications_active_outlined, 'Bills', 'Recurring bills and paid status', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillsPage(store: store, onChanged: onChanged)))),
      _MoreItem(Icons.payments_outlined, 'Income', 'Salary, business and other income', () => Navigator.push(context, MaterialPageRoute(builder: (_) => IncomePage(store: store, onChanged: onChanged)))),
      _MoreItem(Icons.bar_chart_outlined, 'Reports', 'Monthly spending and saving summary', () => showReportSheet(context, store)),
      _MoreItem(Icons.person_outline, 'Profile & Backup', 'Profile, backup and app settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(store: store, onChanged: onChanged)))),
    ];
    return ListView(
      children: [
        const PageHeader('More', subtitle: 'All FinTab money tools in one place'),
        ...items.map((e) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFFE6F2EF), child: Icon(e.icon, color: const Color(0xFF167A67))),
              title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(e.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: e.tap,
            ),
          ),
        )),
      ],
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback tap;
  _MoreItem(this.icon, this.title, this.subtitle, this.tap);
}

class BudgetPage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;
  const BudgetPage({super.key, required this.store, required this.onChanged});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  @override
  Widget build(BuildContext context) {
    final allocated = widget.store.activeCategories.fold(0.0, (a, e) => a + (e['allocated'] ?? 0).toDouble());
    return Scaffold(
      appBar: AppBar(title: const Text('Budget & Allocation')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: ListTile(
              title: const Text('Monthly Budget'),
              subtitle: Text('Allocated ₹${allocated.toStringAsFixed(0)}'),
              trailing: Text('₹${widget.store.monthlyBudget.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () async {
                final c = TextEditingController(text: widget.store.monthlyBudget.toStringAsFixed(0));
                final v = await showNumberDialog(context, 'Set Monthly Budget', c);
                if (v != null && v >= 0) {
                  widget.store.monthlyBudget = v;
                  await widget.store.save();
                  widget.onChanged();
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(height: 14),
          const Text('Category Allocation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...widget.store.activeCategories.map((cat) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(cat['name']),
              subtitle: Text('Spent ₹${widget.store.categorySpent(cat['name']).toStringAsFixed(0)}'),
              trailing: Text('₹${(cat['allocated'] ?? 0).toStringAsFixed(0)}'),
              onTap: () async {
                final c = TextEditingController(text: (cat['allocated'] ?? 0).toString());
                final v = await showNumberDialog(context, 'Allocate to ${cat['name']}', c);
                if (v != null && v >= 0) {
                  cat['allocated'] = v;
                  await widget.store.save();
                  widget.onChanged();
                  setState(() {});
                }
              },
            ),
          )),
        ],
      ),
    );
  }
}

class CategoriesPage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;
  const CategoriesPage({super.key, required this.store, required this.onChanged});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool hasCategory(String name) => widget.store.categories.any((e) => e['name'] == name && e['active'] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final c = TextEditingController();
          final name = await showTextDialog(context, 'Custom Category', c, 'Category name');
          if (name == null || name.trim().isEmpty) return;
          widget.store.categories.add({'name': name.trim(), 'allocated': 0.0, 'active': true});
          await widget.store.save();
          widget.onChanged();
          setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('Custom'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
        children: widget.store.masterCategories.map((name) {
          final active = hasCategory(name);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: SwitchListTile(
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              value: active,
              onChanged: (v) async {
                final idx = widget.store.categories.indexWhere((e) => e['name'] == name);
                if (idx >= 0) {
                  widget.store.categories[idx]['active'] = v;
                } else {
                  widget.store.categories.add({'name': name, 'allocated': 0.0, 'active': v});
                }
                await widget.store.save();
                widget.onChanged();
                setState(() {});
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SavingsPage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;
  const SavingsPage({super.key, required this.store, required this.onChanged});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final amountC = TextEditingController();
          final noteC = TextEditingController();
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add Saving'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹')),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Note')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, {'amount': double.tryParse(amountC.text), 'note': noteC.text}), child: const Text('Save')),
              ],
            ),
          );
          final amount = (result?['amount'] as num?)?.toDouble();
          if (amount != null && amount > 0) {
            await widget.store.addSaving(amount, result?['note'] ?? '');
            widget.onChanged();
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Saving'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Saved', style: TextStyle(color: Colors.grey)),
                Text('₹${widget.store.totalSaved().toStringAsFixed(0)}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.store.savings.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: Text('₹${(s['amount'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(s['note'] ?? ''),
            ),
          )),
        ],
      ),
    );
  }
}

class BillsPage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;
  const BillsPage({super.key, required this.store, required this.onChanged});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  Future<void> addBill() async {
    final nameC = TextEditingController();
    final amountC = TextEditingController();
    final dueC = TextEditingController(text: '5');
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Monthly Bill'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Bill name')),
          TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹')),
          TextField(controller: dueC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Due day (1-31)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {
            'name': nameC.text.trim(),
            'amount': double.tryParse(amountC.text.trim()),
            'dueDay': int.tryParse(dueC.text.trim()),
          }), child: const Text('Add')),
        ],
      ),
    );
    if (r == null || r['name'].toString().isEmpty || r['amount'] == null) return;
    widget.store.bills.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': r['name'],
      'amount': r['amount'],
      'dueDay': r['dueDay'] ?? 5,
      'paidMonth': '',
    });
    await widget.store.save();
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills & Payments')),
      floatingActionButton: FloatingActionButton.extended(onPressed: addBill, icon: const Icon(Icons.add), label: const Text('Add Bill')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
        children: widget.store.bills.isEmpty
            ? [const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No recurring bill added.')))]
            : widget.store.bills.map((b) {
                final paid = b['paidMonth'] == widget.store.monthKey;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: paid,
                    title: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('₹${(b['amount'] ?? 0).toStringAsFixed(0)} • Due day ${b['dueDay']}'),
                    secondary: const Icon(Icons.receipt_outlined),
                    onChanged: (v) async {
                      b['paidMonth'] = v == true ? widget.store.monthKey : '';
                      await widget.store.save();
                      widget.onChanged();
                      setState(() {});
                    },
                  ),
                );
              }).toList(),
      ),
    );
  }
}

class IncomePage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;
  const IncomePage({super.key, required this.store, required this.onChanged});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  @override
  Widget build(BuildContext context) {
    final current = widget.store.incomes.where((e) => e['month'] == widget.store.monthKey).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final amountC = TextEditingController();
          final sourceC = TextEditingController(text: 'Salary');
          final r = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add Income'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹')),
                TextField(controller: sourceC, decoration: const InputDecoration(labelText: 'Source')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, {'amount': double.tryParse(amountC.text), 'source': sourceC.text.trim()}), child: const Text('Add')),
              ],
            ),
          );
          final a = (r?['amount'] as num?)?.toDouble();
          if (a != null && a > 0) {
            await widget.store.addIncome(a, r?['source'] ?? 'Income');
            widget.onChanged();
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Income'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('This month: ₹${widget.store.incomeForMonth().toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)))),
          const SizedBox(height: 12),
          ...current.map((e) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(e['source'] ?? 'Income', style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text('₹${(e['amount'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ))
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final Store store;
  final VoidCallback onChanged;
  const ProfilePage({super.key, required this.store, required this.onChanged});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController nameC;
  late final TextEditingController roleC;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.store.profileName);
    roleC = TextEditingController(text: widget.store.profileRole);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Backup')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: roleC, decoration: const InputDecoration(labelText: 'Profile type / role')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              widget.store.profileName = nameC.text.trim();
              widget.store.profileRole = roleC.text.trim();
              await widget.store.save();
              widget.onChanged();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
            },
            child: const Text('Save Profile'),
          ),
          const SizedBox(height: 22),
          const Text('Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('This V4 stores data offline on the phone. Cloud/email backup can be connected in the next step without changing the app design.'),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () async {
              await widget.store.reset();
              widget.onChanged();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset App Data'),
          ),
        ],
      ),
    );
  }
}

Future<double?> showNumberDialog(BuildContext context, String title, TextEditingController c) {
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.trim())), child: const Text('Save')),
      ],
    ),
  );
}

Future<String?> showTextDialog(BuildContext context, String title, TextEditingController c, String label) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

void showReportSheet(BuildContext context, Store store) {
  final spent = store.spentForMonth();
  final income = store.incomeForMonth();
  final remaining = store.monthlyBudget - spent;
  String highest = '-';
  double highestSpent = 0;
  for (final c in store.activeCategories) {
    final s = store.categorySpent(c['name']);
    if (s > highestSpent) {
      highestSpent = s;
      highest = c['name'];
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Monthly Report', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _reportRow('Income', income),
          _reportRow('Budget', store.monthlyBudget),
          _reportRow('Spent', spent),
          _reportRow('Remaining', remaining),
          _reportRow('Total Saved', store.totalSaved()),
          const SizedBox(height: 10),
          Text('Highest spending category: $highest${highestSpent > 0 ? " (₹${highestSpent.toStringAsFixed(0)})" : ""}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

Widget _reportRow(String label, double value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(children: [
    Expanded(child: Text(label)),
    Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
  ]),
);
