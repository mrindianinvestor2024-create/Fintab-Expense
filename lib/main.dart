import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const appShareUrl = String.fromEnvironment(
  'APP_SHARE_URL',
  defaultValue:
      'https://play.google.com/store/apps/details?id=com.thefintab.expense',
);
const premiumProductId = 'fintab_premium_monthly_29';
const premiumSubscriptionsEnabled = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinTabApp());
}

class FinTabApp extends StatefulWidget {
  const FinTabApp({super.key});

  @override
  State<FinTabApp> createState() => _FinTabAppState();
}

class _FinTabAppState extends State<FinTabApp> {
  final AppModel model = AppModel();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    model.load().then((_) {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0C7C66);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinTab Expense',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE6EBED)),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: ready
          ? MainShell(model: model)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class CategoryItem {
  CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    this.selected = false,
    this.custom = false,
  });

  String id;
  String name;
  String icon;
  bool selected;
  bool custom;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'selected': selected,
        'custom': custom,
      };

  factory CategoryItem.fromJson(Map<String, dynamic> j) => CategoryItem(
        id: j['id'],
        name: j['name'],
        icon: j['icon'] ?? '•',
        selected: j['selected'] ?? false,
        custom: j['custom'] ?? false,
      );
}

class ExpenseEntry {
  ExpenseEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note = '',
  });

  String id;
  String title;
  double amount;
  String categoryId;
  DateTime date;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'categoryId': categoryId,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> j) => ExpenseEntry(
        id: j['id'],
        title: j['title'],
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'],
        date: DateTime.parse(j['date']),
        note: j['note'] ?? '',
      );
}

class DiaryEntry {
  DiaryEntry({required this.id, required this.date, required this.text});
  String id;
  DateTime date;
  String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'text': text,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'],
        date: DateTime.parse(j['date']),
        text: j['text'] ?? '',
      );
}

class ProfileData {
  ProfileData({
    this.name = '',
    this.mobile = '',
    this.email = '',
    this.purpose = 'House Head',
    this.photoPath = '',
  });
  String name;
  String mobile;
  String email;
  String purpose;
  String photoPath;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobile': mobile,
        'email': email,
        'purpose': purpose,
        'photoPath': photoPath,
      };

  factory ProfileData.fromJson(Map<String, dynamic> j) => ProfileData(
        name: j['name'] ?? '',
        mobile: j['mobile'] ?? '',
        email: j['email'] ?? '',
        purpose: j['purpose'] ?? 'House Head',
        photoPath: j['photoPath'] ?? '',
      );
}

class MonthPlan {
  MonthPlan({this.budget = 0, Map<String, double>? allocations})
      : allocations = allocations ?? {};

  double budget;
  Map<String, double> allocations;

  Map<String, dynamic> toJson() => {
        'budget': budget,
        'allocations': allocations,
      };

  factory MonthPlan.fromJson(Map<String, dynamic> j) {
    final raw = (j['allocations'] as Map?) ?? {};
    return MonthPlan(
      budget: ((j['budget'] ?? 0) as num).toDouble(),
      allocations: raw.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      ),
    );
  }
}

class AppModel extends ChangeNotifier {
  static const _categoriesKey = 'v2_categories';
  static const _expensesKey = 'v2_expenses';
  static const _plansKey = 'v2_plans';
  static const _profileKey = 'v3_profile';
  static const _diaryKey = 'v3_diary';
  static const _draftKey = 'v3_expense_draft';
  static const _premiumKey = 'v4_premium_active';

  late SharedPreferences prefs;
  List<CategoryItem> categories = [];
  List<ExpenseEntry> expenses = [];
  Map<String, MonthPlan> plans = {};
  List<DiaryEntry> diaryEntries = [];
  ProfileData profile = ProfileData();
  Map<String, dynamic> expenseDraft = {};
  DateTime activeMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? premiumProduct;
  bool premiumActive = false;
  bool storeAvailable = false;
  bool purchasePending = false;
  String billingMessage = '';

  static List<CategoryItem> masterCategories() => [
        CategoryItem(id: 'grocery', name: 'Grocery', icon: '🛒'),
        CategoryItem(id: 'rent', name: 'Rent', icon: '🏠'),
        CategoryItem(id: 'electricity', name: 'Light Bill / Recharge', icon: '💡'),
        CategoryItem(id: 'school', name: 'Kids School Fees', icon: '🎓'),
        CategoryItem(id: 'milk', name: 'Milk', icon: '🥛'),
        CategoryItem(id: 'vegetables', name: 'Vegetables / Fruits', icon: '🥬'),
        CategoryItem(id: 'medical', name: 'Medicine / Treatment', icon: '💊'),
        CategoryItem(id: 'petrol', name: 'Petrol / Travel', icon: '⛽'),
        CategoryItem(id: 'pocket', name: 'Kids Pocket Money', icon: '🧒'),
        CategoryItem(id: 'homecash', name: 'Home Hand Cash', icon: '🏡'),
        CategoryItem(id: 'personalcash', name: 'Personal Hand Cash', icon: '👤'),
        CategoryItem(id: 'emi', name: 'EMI / Loan', icon: '🏦'),
        CategoryItem(id: 'mobile', name: 'Mobile / Internet', icon: '📱'),
        CategoryItem(id: 'insurance', name: 'Insurance', icon: '🛡️'),
        CategoryItem(id: 'entertainment', name: 'Entertainment', icon: '🎬'),
        CategoryItem(id: 'shopping', name: 'Shopping', icon: '🛍️'),
        CategoryItem(id: 'familyshopping', name: 'Family Shopping', icon: '👨‍👩‍👧‍👦'),
        CategoryItem(id: 'travel', name: 'Travelling', icon: '🚗'),
        CategoryItem(id: 'vacation', name: 'Vacation / Yatra', icon: '🧳'),
        CategoryItem(id: 'parents', name: 'Give Mother / Father', icon: '🙏'),
        CategoryItem(id: 'festival', name: 'Festival Celebration', icon: '🪔'),
        CategoryItem(id: 'gadgets', name: 'New Gadgets Buying', icon: '💻'),
        CategoryItem(id: 'classes', name: 'Extra Class / Activity', icon: '📚'),
        CategoryItem(id: 'subscription', name: 'Subscriptions', icon: '🔁'),
        CategoryItem(id: 'business', name: 'Business / Shop', icon: '🏪'),
        CategoryItem(id: 'shoprent', name: 'Shop / Office Rent', icon: '🏬'),
        CategoryItem(id: 'shoputilities', name: 'Shop Light / Wi-Fi Bill', icon: '📶'),
        CategoryItem(id: 'staff', name: 'Staff / Salary', icon: '👥'),
        CategoryItem(id: 'maintenance', name: 'Office Maintenance', icon: '🧰'),
        CategoryItem(id: 'misc', name: 'Remaining / Misc', icon: '📦'),
        CategoryItem(id: 'other', name: 'Other — Create Your Own', icon: '✍️'),
      ];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();

    final catText = prefs.getString(_categoriesKey);
    if (catText == null) {
      categories = masterCategories();
    } else {
      categories = (jsonDecode(catText) as List)
          .map((e) => CategoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      for (final master in masterCategories()) {
        if (!categories.any((c) => c.id == master.id)) categories.add(master);
      }
    }

    final expText = prefs.getString(_expensesKey);
    if (expText != null) {
      expenses = (jsonDecode(expText) as List)
          .map((e) => ExpenseEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final planText = prefs.getString(_plansKey);
    if (planText != null) {
      final raw = Map<String, dynamic>.from(jsonDecode(planText));
      plans = raw.map(
        (key, value) => MapEntry(
          key,
          MonthPlan.fromJson(Map<String, dynamic>.from(value)),
        ),
      );
    }
    final profileText = prefs.getString(_profileKey);
    if (profileText != null) {
      profile = ProfileData.fromJson(Map<String, dynamic>.from(jsonDecode(profileText)));
    }
    final diaryText = prefs.getString(_diaryKey);
    if (diaryText != null) {
      diaryEntries = (jsonDecode(diaryText) as List)
          .map((e) => DiaryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final draftText = prefs.getString(_draftKey);
    if (draftText != null) expenseDraft = Map<String, dynamic>.from(jsonDecode(draftText));
    premiumActive = prefs.getBool(_premiumKey) ?? false;
    notifyListeners();
    if (premiumSubscriptionsEnabled) await _initBilling();
  }

  Future<void> _initBilling() async {
    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        purchasePending = false;
        billingMessage = 'Google Play billing is temporarily unavailable.';
        notifyListeners();
      },
    );
    storeAvailable = await _inAppPurchase.isAvailable();
    if (!storeAvailable) {
      billingMessage = 'Install the Play Store version to activate Premium.';
      notifyListeners();
      return;
    }
    final response = await _inAppPurchase.queryProductDetails(
      const <String>{premiumProductId},
    );
    if (response.productDetails.isNotEmpty) {
      premiumProduct = response.productDetails.first;
      billingMessage = '';
    } else {
      billingMessage = '₹29 monthly product is not active in Play Console yet.';
    }
    notifyListeners();
  }

  Future<void> buyPremium() async {
    final product = premiumProduct;
    if (!storeAvailable || product == null || purchasePending) return;
    purchasePending = true;
    billingMessage = 'Opening Google Play…';
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePremium() async {
    if (!storeAvailable) return;
    purchasePending = true;
    billingMessage = 'Restoring subscription…';
    notifyListeners();
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.productID != premiumProductId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        purchasePending = true;
        billingMessage = 'Payment is pending in Google Play.';
      } else if (purchase.status == PurchaseStatus.error) {
        purchasePending = false;
        billingMessage = purchase.error?.message ?? 'Subscription failed.';
      } else if (purchase.status == PurchaseStatus.canceled) {
        purchasePending = false;
        billingMessage = 'Subscription was cancelled.';
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final hasStoreProof =
            purchase.verificationData.serverVerificationData.isNotEmpty;
        if (hasStoreProof) {
          premiumActive = true;
          purchasePending = false;
          billingMessage = 'FinTab Premium is active.';
          await prefs.setBool(_premiumKey, true);
        } else {
          purchasePending = false;
          billingMessage = 'Purchase verification failed.';
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  String monthKey([DateTime? month]) {
    final d = month ?? activeMonth;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  MonthPlan get currentPlan => plans.putIfAbsent(monthKey(), () => MonthPlan());

  List<CategoryItem> get selectedCategories =>
      categories.where((c) => c.selected).toList();

  double get totalSpent => expenses
      .where((e) => _sameMonth(e.date, activeMonth))
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalCarryForward => _totalBalanceBefore(activeMonth);

  double get totalAvailableBudget =>
      currentPlan.budget + totalCarryForward;

  double get totalRemaining => totalAvailableBudget - totalSpent;

  double get allocatedTotal =>
      currentPlan.allocations.values.fold(0.0, (a, b) => a + b);

  double spentFor(String categoryId) => expenses
      .where((e) =>
          e.categoryId == categoryId && _sameMonth(e.date, activeMonth))
      .fold(0.0, (sum, e) => sum + e.amount);

  double allocationFor(String categoryId) =>
      currentPlan.allocations[categoryId] ?? 0;

  double carryForwardFor(String categoryId) =>
      _categoryBalanceBefore(activeMonth, categoryId);

  double availableFor(String categoryId) =>
      allocationFor(categoryId) + carryForwardFor(categoryId);

  List<ExpenseEntry> get monthExpenses {
    final list =
        expenses.where((e) => _sameMonth(e.date, activeMonth)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  CategoryItem? categoryById(String id) {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> setBudget(double value) async {
    currentPlan.budget = value;
    await _savePlans();
    notifyListeners();
  }

  Future<void> setAllocation(String categoryId, double value) async {
    currentPlan.allocations[categoryId] = value;
    await _savePlans();
    notifyListeners();
  }

  Future<void> setAllocations(Map<String, double> values) async {
    currentPlan.allocations.addAll(values);
    await _savePlans();
    notifyListeners();
  }

  Future<void> toggleCategory(String id, bool selected) async {
    final c = categoryById(id);
    if (c == null) return;
    c.selected = selected;
    await _saveCategories();
    notifyListeners();
  }

  Future<void> addCustomCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    categories.add(CategoryItem(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: clean,
      icon: '⭐',
      selected: true,
      custom: true,
    ));
    await _saveCategories();
    notifyListeners();
  }

  Future<void> updateCategoryName(String id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final category = categoryById(id);
    if (category == null) return;
    category.name = clean;
    await _saveCategories();
    notifyListeners();
  }

  Future<void> deleteCustomCategory(String id) async {
    categories.removeWhere((c) => c.id == id && c.custom);
    await _saveCategories();
    notifyListeners();
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required String categoryId,
    required DateTime date,
    String note = '',
  }) async {
    expenses.add(ExpenseEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note.trim(),
    ));
    await _saveExpenses();
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    await _saveExpenses();
    notifyListeners();
  }

  Future<void> updateExpense(ExpenseEntry entry) async {
    final i = expenses.indexWhere((e) => e.id == entry.id);
    if (i < 0) return;
    expenses[i] = entry;
    await _saveExpenses();
    notifyListeners();
  }

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    expenseDraft = draft;
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<void> clearDraft() async {
    expenseDraft = {};
    await prefs.remove(_draftKey);
  }

  Future<void> saveProfile(ProfileData value) async {
    profile = value;
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    notifyListeners();
  }

  Future<void> saveDiary(DateTime date, String text) async {
    final clean = text.trim();
    final existing = diaryEntries.indexWhere((e) =>
        e.date.year == date.year && e.date.month == date.month && e.date.day == date.day);
    if (clean.isEmpty) {
      if (existing >= 0) diaryEntries.removeAt(existing);
    } else if (existing >= 0) {
      diaryEntries[existing].text = clean;
    } else {
      diaryEntries.add(DiaryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        text: clean,
      ));
    }
    await prefs.setString(_diaryKey, jsonEncode(diaryEntries.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  DiaryEntry? diaryFor(DateTime date) {
    try {
      return diaryEntries.firstWhere((e) =>
          e.date.year == date.year && e.date.month == date.month && e.date.day == date.day);
    } catch (_) {
      return null;
    }
  }

  double get dailyAverage {
    final days = DateTime.now().year == activeMonth.year && DateTime.now().month == activeMonth.month
        ? DateTime.now().day
        : DateTime(activeMonth.year, activeMonth.month + 1, 0).day;
    return days == 0 ? 0 : totalSpent / days;
  }

  bool get isAboveAveragePace {
    if (totalAvailableBudget <= 0) return false;
    final totalDays = DateTime(activeMonth.year, activeMonth.month + 1, 0).day;
    final now = DateTime.now();
    final elapsed = now.year == activeMonth.year && now.month == activeMonth.month ? now.day : totalDays;
    final expectedByNow = totalAvailableBudget * elapsed / totalDays;
    return totalSpent > expectedByNow;
  }

  CategoryItem? get highestSpentCategory {
    if (selectedCategories.isEmpty) return null;
    final sorted = [...selectedCategories]..sort((a, b) => spentFor(b.id).compareTo(spentFor(a.id)));
    return spentFor(sorted.first.id) > 0 ? sorted.first : null;
  }

  Map<String, dynamic> backupJson() => {
        'app': 'FinTab Expense',
        'version': 3,
        'createdAt': DateTime.now().toIso8601String(),
        'profile': profile.toJson(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'plans': plans.map((k, v) => MapEntry(k, v.toJson())),
        'diary': diaryEntries.map((e) => e.toJson()).toList(),
      };

  Future<void> restoreBackup(Map<String, dynamic> data) async {
    if (data['app'] != 'FinTab Expense') throw const FormatException('Invalid FinTab backup');
    profile = ProfileData.fromJson(Map<String, dynamic>.from(data['profile'] ?? {}));
    categories = (data['categories'] as List).map((e) => CategoryItem.fromJson(Map<String, dynamic>.from(e))).toList();
    expenses = (data['expenses'] as List).map((e) => ExpenseEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    final rawPlans = Map<String, dynamic>.from(data['plans'] ?? {});
    plans = rawPlans.map((k, v) => MapEntry(k, MonthPlan.fromJson(Map<String, dynamic>.from(v))));
    diaryEntries = ((data['diary'] as List?) ?? []).map((e) => DiaryEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    await _saveCategories();
    await _saveExpenses();
    await _savePlans();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    await prefs.setString(_diaryKey, jsonEncode(diaryEntries.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void previousMonth() {
    activeMonth = DateTime(activeMonth.year, activeMonth.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    activeMonth = DateTime(activeMonth.year, activeMonth.month + 1);
    notifyListeners();
  }

  double _totalBalanceBefore(DateTime targetMonth) {
    final start = _earliestTrackedMonth();
    if (start == null || !_monthBefore(start, targetMonth)) return 0;

    var cursor = start;
    var balance = 0.0;
    while (_monthBefore(cursor, targetMonth)) {
      final plan = plans[monthKey(cursor)];
      final spent = expenses
          .where((e) => _sameMonth(e.date, cursor))
          .fold(0.0, (sum, e) => sum + e.amount);
      balance += (plan?.budget ?? 0) - spent;
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return balance;
  }

  double _categoryBalanceBefore(DateTime targetMonth, String categoryId) {
    final start = _earliestTrackedMonth();
    if (start == null || !_monthBefore(start, targetMonth)) return 0;

    var cursor = start;
    var balance = 0.0;
    while (_monthBefore(cursor, targetMonth)) {
      final allocation =
          plans[monthKey(cursor)]?.allocations[categoryId] ?? 0;
      final spent = expenses
          .where((e) =>
              e.categoryId == categoryId && _sameMonth(e.date, cursor))
          .fold(0.0, (sum, e) => sum + e.amount);
      balance += allocation - spent;
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return balance;
  }

  DateTime? _earliestTrackedMonth() {
    DateTime? earliest;
    for (final key in plans.keys) {
      final parts = key.split('-');
      if (parts.length != 2) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null || month < 1 || month > 12) continue;
      final value = DateTime(year, month);
      if (earliest == null || _monthBefore(value, earliest)) earliest = value;
    }
    for (final expense in expenses) {
      final value = DateTime(expense.date.year, expense.date.month);
      if (earliest == null || _monthBefore(value, earliest)) earliest = value;
    }
    return earliest;
  }

  static bool _monthBefore(DateTime a, DateTime b) =>
      a.year < b.year || (a.year == b.year && a.month < b.month);

  Future<void> _saveCategories() async {
    await prefs.setString(
      _categoriesKey,
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveExpenses() async {
    await prefs.setString(
      _expensesKey,
      jsonEncode(expenses.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _savePlans() async {
    await prefs.setString(
      _plansKey,
      jsonEncode(plans.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.model});
  final AppModel model;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(model: widget.model),
      StatementScreen(model: widget.model),
      CategoriesScreen(model: widget.model),
      DiaryScreen(model: widget.model),
      MoreScreen(model: widget.model),
    ];
    return Scaffold(
      body: SafeArea(child: screens[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Statement',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Diary',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              onPressed: () => showAddExpenseSheet(context, widget.model),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final money = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    ProfileAvatar(model: model, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.profile.name.isEmpty ? 'FinTab Expense' : model.profile.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${model.profile.purpose} • Plan • Track • Save',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Export PDF',
                      onPressed: () => exportPdf(context, model),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: MonthSelector(model: model)),
            if (model.totalSpent > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Card(
                    color: model.isAboveAveragePace
                        ? const Color(0xFFFFECEC)
                        : const Color(0xFFEAF8F4),
                    child: ListTile(
                      leading: Icon(
                        model.isAboveAveragePace
                            ? Icons.warning_amber_rounded
                            : Icons.insights,
                      ),
                      title: Text(
                        model.isAboveAveragePace
                            ? 'Warning: spending is above your monthly average'
                            : 'Daily average ₹${model.dailyAverage.toStringAsFixed(0)}',
                      ),
                      subtitle: Text(
                        model.highestSpentCategory == null
                            ? 'Keep recording expenses to receive saving advice.'
                            : 'Highest spending: ${model.highestSpentCategory!.name}. '
                                '${model.totalRemaining > 0 ? 'Move the remaining ₹${model.totalRemaining.toStringAsFixed(0)} to savings at month end.' : 'Review this category to control overspending.'}',
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF073B33), Color(0xFF0C7C66)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Budget',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        money.format(model.totalAvailableBudget),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (model.totalCarryForward != 0) ...[
                        const SizedBox(height: 5),
                        Text(
                          'This month ${money.format(model.currentPlan.budget)}  •  Carry forward ${model.totalCarryForward >= 0 ? '+' : ''}${money.format(model.totalCarryForward)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _DarkMetric(
                              label: 'Spent',
                              value: money.format(model.totalSpent),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DarkMetric(
                              label: 'Remaining',
                              value: money.format(model.totalRemaining),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => showBudgetDialog(context, model),
                              icon: const Icon(Icons.account_balance_wallet_outlined),
                              label: const Text('Set Budget'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AllocationScreen(model: model),
                                ),
                              ),
                              icon: const Icon(Icons.tune),
                              label: const Text('Allocate'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: FilledButton.icon(
                  onPressed: () => startScanAndPay(context, model),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan & Pay with Google Pay / UPI'),
                ),
              ),
            ),
            if (model.selectedCategories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Icon(Icons.category_outlined, size: 40),
                          const SizedBox(height: 10),
                          const Text(
                            'Choose your expense categories',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Only categories you select will appear on your dashboard.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Category Funds',
                  action: 'Manage',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllocationScreen(model: model),
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: model.selectedCategories.length,
                itemBuilder: (context, i) {
                  final c = model.selectedCategories[i];
                  final allocated = model.allocationFor(c.id);
                  final carry = model.carryForwardFor(c.id);
                  final available = model.availableFor(c.id);
                  final spent = model.spentFor(c.id);
                  final remaining = available - spent;
                  final progress = available <= 0
                      ? 0.0
                      : (spent / available).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(c.icon, style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  money.format(remaining),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: remaining < 0
                                        ? Colors.red.shade700
                                    : const Color(0xFF0C7C66),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit allocation',
                                  onPressed: () => showAllocationDialog(
                                    context,
                                    model,
                                    c,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    carry == 0
                                        ? 'Allocated ${money.format(allocated)}'
                                        : 'New ${money.format(allocated)} • Carry ${carry >= 0 ? '+' : ''}${money.format(carry)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Spent ${money.format(spent)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Recent Expenses',
                action: 'Statement',
                onTap: () {},
              ),
            ),
            if (model.monthExpenses.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Center(
                    child: Text(
                      'No expenses yet. Tap “Add Expense” to start.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: model.monthExpenses.take(5).length,
                itemBuilder: (context, i) {
                  final e = model.monthExpenses[i];
                  final c = model.categoryById(e.categoryId);
                  return ExpenseTile(
                    entry: e,
                    category: c,
                    money: money,
                    onEdit: () => showAddExpenseSheet(context, model, existing: e),
                    onDelete: () => confirmDeleteExpense(context, model, e),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        );
      },
    );
  }
}

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: model.previousMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(model.activeMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: model.nextMonth,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF073B33), Color(0xFF14A784)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C7C66).withValues(alpha: .18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Center(
        child: Text(
          'F₹',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * .37,
          ),
        ),
      ),
    );
  }
}

class AllocationScreen extends StatefulWidget {
  const AllocationScreen({super.key, required this.model});
  final AppModel model;

  @override
  State<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends State<AllocationScreen> {
  final Map<String, TextEditingController> controllers = {};

  AppModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    for (final c in model.selectedCategories) {
      final value = model.allocationFor(c.id);
      controllers[c.id] = TextEditingController(text: value == 0 ? '' : value.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> saveAndClose() async {
    FocusScope.of(context).unfocus();
    final values = <String, double>{};
    for (final c in model.selectedCategories) {
      values[c.id] = parseMoney(controllers[c.id]?.text ?? '');
    }
    await model.setAllocations(values);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category allocations saved.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allocate Category Funds')),
      body: AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          final budget = model.currentPlan.budget;
          final left = budget - model.allocatedTotal;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Budget allocation balance'),
                  subtitle: Text(
                    'Budget ₹${budget.toStringAsFixed(0)} • Allocated ₹${model.allocatedTotal.toStringAsFixed(0)}',
                  ),
                  trailing: Text(
                    '₹${left.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: left < 0 ? Colors.red : const Color(0xFF0C7C66),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (model.selectedCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'First select categories from the Categories tab.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ...model.selectedCategories.map((c) {
                final controller = controllers.putIfAbsent(c.id, () => TextEditingController());
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Text(c.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(
                            width: 125,
                            child: TextField(
                              controller: controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '0',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: saveAndClose,
                icon: const Icon(Icons.check),
                label: const Text('Save Allocations'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            const Row(
              children: [
                BrandMark(size: 42),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Choose Categories',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select only what you need. Unselected categories stay hidden from the dashboard.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => showAddCategoryDialog(context, model),
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Category'),
            ),
            const SizedBox(height: 12),
            ...model.categories.map(
              (c) => Card(
                child: SwitchListTile(
                  value: c.selected,
                  onChanged: (v) async {
                    if (c.id == 'other' && v) {
                      await showAddCategoryDialog(context, model);
                    } else {
                      await model.toggleCategory(c.id, v);
                    }
                  },
                  secondary: Text(c.icon, style: const TextStyle(fontSize: 24)),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit category name',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => showEditCategoryDialog(
                          context,
                          model,
                          c,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ],
                  ),
                  subtitle: c.custom ? const Text('Custom category') : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final money = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const BrandMark(size: 42),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Monthly Statement',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Create PDF',
                    onPressed: () => exportPdf(context, model),
                    icon: const Icon(Icons.picture_as_pdf),
                  ),
                ],
              ),
            ),
            MonthSelector(model: model),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          'Available',
                          money.format(model.totalAvailableBudget),
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          'Spent',
                          money.format(model.totalSpent),
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          'Left',
                          money.format(model.totalRemaining),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: model.monthExpenses.isEmpty
                  ? const Center(child: Text('No transactions this month.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: model.monthExpenses.length,
                      itemBuilder: (context, i) {
                        final e = model.monthExpenses[i];
                        return ExpenseTile(
                          entry: e,
                          category: model.categoryById(e.categoryId),
                          money: money,
                          onEdit: () => showAddExpenseSheet(context, model, existing: e),
                          onDelete: () =>
                              confirmDeleteExpense(context, model, e),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    );
  }
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.entry,
    required this.category,
    required this.money,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseEntry entry;
  final CategoryItem? category;
  final NumberFormat money;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Text(category?.icon ?? '•'),
          ),
          title: Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${category?.name ?? 'Unknown'} • ${DateFormat('dd MMM yyyy').format(entry.date)}'
            '${entry.note.isEmpty ? '' : '\n${entry.note}'}',
          ),
          isThreeLine: entry.note.isNotEmpty,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '-${money.format(entry.amount)}',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                tooltip: 'Edit expense',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete expense',
                onPressed: onDelete,
                color: Colors.red.shade700,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.model, this.size = 52});
  final AppModel model;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = model.profile.photoPath;
    final hasPhoto = path.isNotEmpty && File(path).existsSync();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF0C7C66),
      backgroundImage: hasPhoto ? FileImage(File(path)) : null,
      child: hasPhoto
          ? null
          : Text(
              model.profile.name.isEmpty ? 'F₹' : model.profile.name.characters.first.toUpperCase(),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .35),
            ),
    );
  }
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.model});
  final AppModel model;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime date = DateTime.now();
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.model.diaryFor(date)?.text ?? '');
  }

  void loadDate(DateTime value) {
    setState(() {
      date = value;
      controller.text = widget.model.diaryFor(date)?.text ?? '';
    });
  }

  @override
  void dispose() {
    unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        const Text('My Daily Diary', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Write an experience, important event or money note for the day.'),
        const SizedBox(height: 16),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(Icons.calendar_month),
          title: const Text('Diary date'),
          subtitle: Text(DateFormat('dd MMMM yyyy').format(date)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) loadDate(picked);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          minLines: 10,
          maxLines: 16,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Today’s experience / incident',
            alignLabelWithHint: true,
            hintText: 'Write freely here…',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () async {
            await widget.model.saveDiary(date, controller.text);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diary saved.')));
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Diary Page'),
        ),
      ],
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          const Text('Profile & Data', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: ProfileAvatar(model: model, size: 52),
              title: Text(model.profile.name.isEmpty ? 'Add your profile' : model.profile.name),
              subtitle: Text(
                '${model.profile.purpose}'
                '${model.profile.mobile.isEmpty ? '' : ' • ${model.profile.mobile}'}'
                '${model.profile.email.isEmpty ? '' : '\n${model.profile.email}'}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => showProfileDialog(context, model),
            ),
          ),
          const SizedBox(height: 10),
          if (premiumSubscriptionsEnabled) ...[
            Card(
              color: model.premiumActive
                  ? const Color(0xFFFFF6DA)
                  : Colors.white,
              child: ListTile(
                leading: Icon(
                  Icons.workspace_premium,
                  color: model.premiumActive
                      ? const Color(0xFF9A6700)
                      : const Color(0xFF0C7C66),
                ),
                title: Text(
                  model.premiumActive
                      ? 'FinTab Premium Active'
                      : 'FinTab Premium — ₹29/month',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  model.premiumActive
                      ? 'Monthly subscription managed by Google Play'
                      : 'Auto-renewing plan • Cancel anytime in Google Play',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showPremiumDialog(context, model),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Financial Year Details'),
                  subtitle: const Text('April to March spending summary'),
                  onTap: () => showFinancialYear(context, model),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Download / Share Backup'),
                  subtitle: const Text('Keep a safe copy before changing phone'),
                  onTap: () => exportBackup(context, model),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email Backup'),
                  subtitle: Text(
                    model.profile.email.isEmpty
                        ? 'Add an email, then send your backup through Gmail'
                        : 'Send backup to ${model.profile.email}',
                  ),
                  onTap: () => emailBackup(context, model),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore Backup'),
                  subtitle: const Text('Bring entries back from a FinTab backup file'),
                  onTap: () => restoreBackup(context, model),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share FinTab Expense'),
              subtitle: const Text('Tell family and friends about the app'),
              onTap: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'Download FinTab Expense — plan your monthly budget, track expenses and save more.\n$appShareUrl',
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'FinTab Expense V3.4 • Free offline expense manager with UPI Scan & Pay. Premium is prepared for the future and currently switched off.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> startScanAndPay(
  BuildContext context,
  AppModel model,
) async {
  if (model.selectedCategories.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('First select an expense category.')),
    );
    return;
  }
  final rawUpi = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const ScanUpiQrScreen()),
  );
  if (rawUpi == null || !context.mounted) return;
  await showUpiPaymentSheet(context, model, rawUpi);
}

class ScanUpiQrScreen extends StatefulWidget {
  const ScanUpiQrScreen({super.key});

  @override
  State<ScanUpiQrScreen> createState() => _ScanUpiQrScreenState();
}

class _ScanUpiQrScreenState extends State<ScanUpiQrScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool handled = false;

  Future<void> handleCapture(BarcodeCapture capture) async {
    if (handled || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'upi' ||
        uri.host.toLowerCase() != 'pay') {
      handled = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This is not a valid UPI payment QR.')),
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      handled = false;
      return;
    }
    handled = true;
    await controller.stop();
    if (mounted) Navigator.pop(context, raw);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Merchant UPI QR'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: controller.toggleTorch,
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: handleCapture,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Scan only a trusted merchant UPI QR. Your UPI PIN is entered only inside Google Pay or your chosen UPI app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showUpiPaymentSheet(
  BuildContext context,
  AppModel model,
  String rawUpi,
) async {
  final scanned = Uri.parse(rawUpi);
  final params = Map<String, String>.from(scanned.queryParameters);
  final payeeAddress = params['pa']?.trim() ?? '';
  if (payeeAddress.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Merchant UPI ID is missing in this QR.')),
    );
    return;
  }

  final amount = TextEditingController(text: params['am'] ?? '');
  final title = TextEditingController(
    text: (params['pn']?.trim().isNotEmpty ?? false)
        ? params['pn']!.trim()
        : 'UPI Payment',
  );
  var categoryId = model.selectedCategories.first.id;

  final request = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(ctx).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm UPI Payment',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text('Merchant UPI: $payeeAddress'),
              const SizedBox(height: 16),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Merchant / Expense name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Expense category'),
                items: model.selectedCategories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.icon}  ${c.name}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setLocal(() => categoryId = value);
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final value = parseMoney(amount.text);
                    if (title.text.trim().isEmpty || value <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter merchant name and valid amount.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, <String, dynamic>{
                      'title': title.text.trim(),
                      'amount': value,
                      'categoryId': categoryId,
                    });
                  },
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Open Google Pay / UPI App'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'FinTab does not hold money or ask for your UPI PIN.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  amount.dispose();
  title.dispose();
  if (request == null || !context.mounted) return;

  params['pa'] = payeeAddress;
  params['pn'] = request['title'] as String;
  params['am'] = (request['amount'] as double).toStringAsFixed(2);
  params['cu'] = 'INR';
  params.putIfAbsent(
    'tn',
    () => 'FinTab Expense payment',
  );
  final query = params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  final paymentUri = Uri.parse('upi://pay?$query');

  final launched = await launchUrl(
    paymentUri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI app found. Install or open Google Pay.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final paid = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Was payment successful?'),
      content: Text(
        'Confirm only after Google Pay shows payment successful for ₹${(request['amount'] as double).toStringAsFixed(2)}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('No / Failed'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes, Add Expense'),
        ),
      ],
    ),
  );
  if (paid == true) {
    await model.addExpense(
      title: request['title'] as String,
      amount: request['amount'] as double,
      categoryId: request['categoryId'] as String,
      date: DateTime.now(),
      note: 'Paid via UPI QR • $payeeAddress',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment added to expenses.')),
      );
    }
  }
}

Future<void> showPremiumDialog(
  BuildContext context,
  AppModel model,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AnimatedBuilder(
      animation: model,
      builder: (ctx, _) {
        final price = model.premiumProduct?.price ?? '₹29';
        return AlertDialog(
          title: const Text('FinTab Premium'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.premiumActive
                    ? 'Premium is active on this Google Play account.'
                    : '$price per month • Auto-renewing • Cancel anytime',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const Text('• Advanced statements and financial-year insights'),
              const Text('• Email backup and upcoming secure cloud sync'),
              const Text('• Premium Scan & Pay improvements and support'),
              if (model.billingMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  model.billingMessage,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (model.purchasePending) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => model.restorePremium(),
              child: const Text('Restore Purchase'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (!model.premiumActive)
              FilledButton(
                onPressed: model.premiumProduct == null || model.purchasePending
                    ? null
                    : () => model.buyPremium(),
                child: const Text('Subscribe ₹29/month'),
              ),
          ],
        );
      },
    ),
  );
}

Future<void> showProfileDialog(BuildContext context, AppModel model) async {
  final name = TextEditingController(text: model.profile.name);
  final mobile = TextEditingController(text: model.profile.mobile);
  final email = TextEditingController(text: model.profile.email);
  String purpose = model.profile.purpose;
  String photoPath = model.profile.photoPath;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('My Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundImage: photoPath.isNotEmpty && File(photoPath).existsSync() ? FileImage(File(photoPath)) : null,
                child: photoPath.isEmpty ? const Icon(Icons.person, size: 38) : null,
              ),
              TextButton.icon(
                onPressed: () async {
                  final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (image != null) {
                    final directory = await getApplicationDocumentsDirectory();
                    final saved = await File(image.path).copy('${directory.path}/fintab_profile.jpg');
                    setLocal(() => photoPath = saved.path);
                  }
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose Photo'),
              ),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(
                controller: mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Backup email',
                  hintText: 'name@example.com',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: purpose,
                decoration: const InputDecoration(labelText: 'App purpose'),
                items: const ['House Head', 'Shop', 'Office', 'Student']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) { if (v != null) setLocal(() => purpose = v); },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await model.saveProfile(ProfileData(
                name: name.text.trim(),
                mobile: mobile.text.trim(),
                email: email.text.trim(),
                purpose: purpose,
                photoPath: photoPath,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    ),
  );
}

Future<void> emailBackup(BuildContext context, AppModel model) async {
  if (model.profile.email.trim().isEmpty) {
    await showProfileDialog(context, model);
    if (model.profile.email.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add your backup email first.')),
        );
      }
      return;
    }
  }
  await exportBackup(
    context,
    model,
    targetEmail: model.profile.email.trim(),
  );
}

Future<void> exportBackup(
  BuildContext context,
  AppModel model, {
  String? targetEmail,
}) async {
  try {
    final name = 'FinTab_Backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
    final file = File('${Directory.systemTemp.path}/$name');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(model.backupJson()));
    final message = targetEmail == null
        ? 'FinTab Expense offline backup'
        : 'FinTab Expense backup for $targetEmail. Select Gmail and send this attached file to $targetEmail.';
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: message),
    );
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup could not be created.')));
  }
}

Future<void> restoreBackup(BuildContext context, AppModel model) async {
  try {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (result == null) return;
    final picked = result.files.single;
    final text = picked.bytes != null ? utf8.decode(picked.bytes!) : await File(picked.path!).readAsString();
    final data = Map<String, dynamic>.from(jsonDecode(text));
    if (!context.mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text('Current app data will be replaced by the selected backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (yes == true) {
      await model.restoreBackup(data);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored successfully.')));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is not a valid FinTab backup file.')));
  }
}

Future<void> showFinancialYear(BuildContext context, AppModel model) async {
  final base = model.activeMonth.month >= 4 ? model.activeMonth.year : model.activeMonth.year - 1;
  final months = List.generate(12, (i) => DateTime(base, 4 + i));
  double spent(DateTime month) => model.expenses
      .where((e) => e.date.year == month.year && e.date.month == month.month)
      .fold(0.0, (sum, e) => sum + e.amount);
  final total = months.fold(0.0, (sum, month) => sum + spent(month));
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('FY $base-${(base + 1).toString().substring(2)} • ₹${total.toStringAsFixed(0)}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: months.map((m) => ListTile(
            dense: true,
            title: Text(DateFormat('MMMM yyyy').format(m)),
            trailing: Text('₹${spent(m).toStringAsFixed(0)}'),
          )).toList(),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}

Future<void> showBudgetDialog(BuildContext context, AppModel model) async {
  final controller = TextEditingController(
    text: model.currentPlan.budget == 0
        ? ''
        : model.currentPlan.budget.toStringAsFixed(0),
  );
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Set Monthly Budget'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Total monthly budget',
          prefixText: '₹ ',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await model.setBudget(parseMoney(controller.text));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> showAddCategoryDialog(
  BuildContext context,
  AppModel model,
) async {
  final controller = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New Category'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Category name',
          hintText: 'e.g. Farm, Tuition, Shop Stock',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await model.addCustomCategory(controller.text);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

Future<void> showEditCategoryDialog(
  BuildContext context,
  AppModel model,
  CategoryItem category,
) async {
  final controller = TextEditingController(text: category.name);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Category'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Category name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (controller.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Enter a category name.')),
              );
              return;
            }
            await model.updateCategoryName(category.id, controller.text);
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category saved successfully.')),
    );
  }
}

Future<void> showAddExpenseSheet(
  BuildContext context,
  AppModel model,
  {ExpenseEntry? existing}
) async {
  if (model.selectedCategories.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('First select at least one category.')),
    );
    return;
  }

  final draft = existing == null ? model.expenseDraft : <String, dynamic>{};
  final title = TextEditingController(text: existing?.title ?? draft['title'] ?? '');
  final amount = TextEditingController(
    text: existing == null
        ? (draft['amount'] ?? '')
        : existing.amount.toStringAsFixed(2),
  );
  final note = TextEditingController(text: existing?.note ?? draft['note'] ?? '');
  String categoryId = existing?.categoryId ?? draft['categoryId'] ?? model.selectedCategories.first.id;
  if (!model.selectedCategories.any((c) => c.id == categoryId)) {
    categoryId = model.selectedCategories.first.id;
  }
  DateTime date = existing?.date ??
      (draft['date'] == null ? DateTime.now() : DateTime.tryParse(draft['date']) ?? DateTime.now());

  Future<void> persistDraft() async {
    if (existing != null) return;
    await model.saveDraft({
      'title': title.text,
      'amount': amount.text,
      'note': note.text,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
    });
  }
  title.addListener(persistDraft);
  amount.addListener(persistDraft);
  note.addListener(persistDraft);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add Expense' : 'Edit Expense',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                if (existing == null && draft.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Your unfinished draft has been restored.', style: TextStyle(color: Color(0xFF0C7C66))),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Expense title',
                    hintText: 'e.g. Weekly grocery',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: model.selectedCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.icon}  ${c.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setLocal(() => categoryId = v);
                      persistDraft();
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: const Color(0xFFF7F9FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setLocal(() => date = picked);
                      persistDraft();
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final value = parseMoney(amount.text);
                      if (title.text.trim().isEmpty || value <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Enter title and valid amount.'),
                          ),
                        );
                        return;
                      }
                      if (existing == null) {
                        await model.addExpense(
                          title: title.text,
                          amount: value,
                          categoryId: categoryId,
                          date: date,
                          note: note.text,
                        );
                        await model.clearDraft();
                      } else {
                        await model.updateExpense(ExpenseEntry(
                          id: existing.id,
                          title: title.text.trim(),
                          amount: value,
                          categoryId: categoryId,
                          date: date,
                          note: note.text.trim(),
                        ));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.save),
                    label: Text(existing == null ? 'Save Expense' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> showAllocationDialog(
  BuildContext context,
  AppModel model,
  CategoryItem category,
) async {
  final controller = TextEditingController(
    text: model.allocationFor(category.id) == 0
        ? ''
        : model.allocationFor(category.id).toStringAsFixed(0),
  );
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Edit ${category.name} allocation'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'This month allocation',
          prefixText: '₹ ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved == true) {
    await model.setAllocation(category.id, parseMoney(controller.text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category allocation saved.')),
      );
    }
  }
  controller.dispose();
}

double parseMoney(String text) {
  return double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
}

Future<void> confirmDeleteExpense(
  BuildContext context,
  AppModel model,
  ExpenseEntry e,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete expense?'),
      content: Text('Remove “${e.title}” from the statement?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (yes == true) await model.deleteExpense(e.id);
}

Future<void> exportPdf(BuildContext context, AppModel model) async {
  final doc = pw.Document();
  final monthName = DateFormat('MMMM yyyy').format(model.activeMonth);
  final entries = model.monthExpenses;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FinTab Expense',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Monthly Statement - $monthName'),
              ],
            ),
            pw.Text(
              'Generated ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfMetric('Available Budget', model.totalAvailableBudget),
              _pdfMetric('Spent', model.totalSpent),
              _pdfMetric('Remaining', model.totalRemaining),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Category Summary',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Category',
            'New Budget',
            'Carry',
            'Available',
            'Spent',
            'Remaining',
          ],
          data: model.selectedCategories.map((c) {
            final allocated = model.allocationFor(c.id);
            final carry = model.carryForwardFor(c.id);
            final available = model.availableFor(c.id);
            final spent = model.spentFor(c.id);
            return [
              c.name,
              'Rs. ${allocated.toStringAsFixed(0)}',
              'Rs. ${carry.toStringAsFixed(0)}',
              'Rs. ${available.toStringAsFixed(0)}',
              'Rs. ${spent.toStringAsFixed(0)}',
              'Rs. ${(available - spent).toStringAsFixed(0)}',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Expense Statement',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Date', 'Category', 'Details', 'Amount'],
          data: entries.map((e) {
            final c = model.categoryById(e.categoryId);
            return [
              DateFormat('dd-MM-yyyy').format(e.date),
              c?.name ?? 'Unknown',
              e.note.isEmpty ? e.title : '${e.title} - ${e.note}',
              'Rs. ${e.amount.toStringAsFixed(2)}',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'FinTab Expense • Offline personal budget & expense manager',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  try {
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'FinTab_Expense_${model.monthKey()}.pdf',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create PDF on this device.')),
      );
    }
  }
}

pw.Widget _pdfMetric(String label, double value) {
  return pw.Column(
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      pw.Text(
        'Rs. ${value.toStringAsFixed(0)}',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}
