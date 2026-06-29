import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

const navy = Color(0xFF06121F);
const navy2 = Color(0xFF0B1E31);
const card = Color(0xFF10263A);
const gold = Color(0xFFD8A23A);
const goldBright = Color(0xFFFFC857);
const green = Color(0xFF37B65C);
const red = Color(0xFFD64545);
const muted = Color(0xFF9AA7B4);

void main() => runApp(const NatesProductionPro());

class NatesProductionPro extends StatelessWidget {
  const NatesProductionPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Nate's Production Pro",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

String f(double v, [int d = 2]) => v.toStringAsFixed(d);
String f0(double v) => v.toStringAsFixed(0);

String timeFmt(double minutes) {
  int sec = (minutes * 60).round();
  if (sec < 0) sec = 0;
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  return h > 0
      ? "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}"
      : "$m:${s.toString().padLeft(2, '0')}";
}

String clockSecs(int sec) {
  if (sec < 0) sec = 0;
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  return h > 0
      ? "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}"
      : "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
}

class Product {
  String id;
  String name;
  double dryWeightPerFeed;
  double secondsPerFeed;
  double growthRate;
  double finishedCasesNeeded;
  double caseWeight;
  double cookMinutes;
  bool favorite;

  Product({
    required this.id,
    required this.name,
    required this.dryWeightPerFeed,
    required this.secondsPerFeed,
    required this.growthRate,
    required this.finishedCasesNeeded,
    required this.caseWeight,
    required this.cookMinutes,
    this.favorite = false,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "dryWeightPerFeed": dryWeightPerFeed,
        "secondsPerFeed": secondsPerFeed,
        "growthRate": growthRate,
        "finishedCasesNeeded": finishedCasesNeeded,
        "caseWeight": caseWeight,
        "cookMinutes": cookMinutes,
        "favorite": favorite,
      };

  static Product fromJson(Map<String, dynamic> j) => Product(
        id: j["id"] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j["name"] ?? "Product",
        dryWeightPerFeed: (j["dryWeightPerFeed"] ?? 20).toDouble(),
        secondsPerFeed: (j["secondsPerFeed"] ?? 33).toDouble(),
        growthRate: (j["growthRate"] ?? 2.05).toDouble(),
        finishedCasesNeeded: (j["finishedCasesNeeded"] ?? 1000).toDouble(),
        caseWeight: (j["caseWeight"] ?? 20).toDouble(),
        cookMinutes: (j["cookMinutes"] ?? 13).toDouble(),
        favorite: j["favorite"] ?? false,
      );
}

class RunLog {
  String id;
  String productName;
  DateTime date;
  double cases;
  double stopCases;
  double dryLb;
  double cookedLb;
  double yieldFactor;

  RunLog({
    required this.id,
    required this.productName,
    required this.date,
    required this.cases,
    required this.stopCases,
    required this.dryLb,
    required this.cookedLb,
    required this.yieldFactor,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "productName": productName,
        "date": date.toIso8601String(),
        "cases": cases,
        "stopCases": stopCases,
        "dryLb": dryLb,
        "cookedLb": cookedLb,
        "yieldFactor": yieldFactor,
      };

  static RunLog fromJson(Map<String, dynamic> j) => RunLog(
        id: j["id"] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        productName: j["productName"] ?? "Product",
        date: DateTime.tryParse(j["date"] ?? "") ?? DateTime.now(),
        cases: (j["cases"] ?? 0).toDouble(),
        stopCases: (j["stopCases"] ?? 0).toDouble(),
        dryLb: (j["dryLb"] ?? 0).toDouble(),
        cookedLb: (j["cookedLb"] ?? 0).toDouble(),
        yieldFactor: (j["yieldFactor"] ?? 0).toDouble(),
      );
}

class CalcResult {
  final double dryLbMin;
  final double cookedLbMin;
  final double flushCases;
  final double flushLb;
  final double stopCases;
  final double stopMinutes;
  final double feeds;
  final double dryFed;
  final double cookedTotal;

  CalcResult({
    required this.dryLbMin,
    required this.cookedLbMin,
    required this.flushCases,
    required this.flushLb,
    required this.stopCases,
    required this.stopMinutes,
    required this.feeds,
    required this.dryFed,
    required this.cookedTotal,
  });
}

CalcResult calculate(Product p) {
  if (p.secondsPerFeed <= 0) throw "Seconds per feed must be greater than 0";
  if (p.caseWeight <= 0) throw "Case weight must be greater than 0";
  if (p.growthRate <= 0) throw "Growth rate must be greater than 0";

  final feedsMin = 60 / p.secondsPerFeed;
  final dryLbMin = feedsMin * p.dryWeightPerFeed;
  final cookedLbMin = dryLbMin * p.growthRate;
  final flushLb = cookedLbMin * p.cookMinutes;
  final flushCases = flushLb / p.caseWeight;
  final stopCases = (p.finishedCasesNeeded - flushCases).clamp(0, 99999999).toDouble();
  final stopMinutes = p.cookMinutes + ((stopCases * p.caseWeight) / cookedLbMin);
  final feeds = feedsMin * stopMinutes;
  final dryFed = feeds * p.dryWeightPerFeed;
  final cookedTotal = p.finishedCasesNeeded * p.caseWeight;

  return CalcResult(
    dryLbMin: dryLbMin,
    cookedLbMin: cookedLbMin,
    flushCases: flushCases,
    flushLb: flushLb,
    stopCases: stopCases,
    stopMinutes: stopMinutes,
    feeds: feeds,
    dryFed: dryFed,
    cookedTotal: cookedTotal,
  );
}

class Store extends ChangeNotifier {
  List<Product> products = [];
  List<RunLog> logs = [];
  Product? active;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final pr = sp.getString("products");
    final lr = sp.getString("logs");

    if (pr == null) {
      products = [
        Product(
          id: "1",
          name: "Penne Rigate",
          dryWeightPerFeed: 20,
          secondsPerFeed: 33,
          growthRate: 2.05,
          finishedCasesNeeded: 1000,
          caseWeight: 20,
          cookMinutes: 13,
          favorite: true,
        ),
      ];
    } else {
      products = (jsonDecode(pr) as List).map((e) => Product.fromJson(e)).toList();
    }

    if (lr != null) {
      logs = (jsonDecode(lr) as List).map((e) => RunLog.fromJson(e)).toList();
    }

    active = products.isNotEmpty ? products.first : null;
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString("products", jsonEncode(products.map((e) => e.toJson()).toList()));
    await sp.setString("logs", jsonEncode(logs.map((e) => e.toJson()).toList()));
  }

  Future<void> upsert(Product p) async {
    final i = products.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      products[i] = p;
    } else {
      products.add(p);
    }
    active = p;
    await save();
    notifyListeners();
  }

  Future<void> delete(Product p) async {
    products.removeWhere((x) => x.id == p.id);
    active = products.isEmpty ? null : products.first;
    await save();
    notifyListeners();
  }

  Future<void> logRun(RunLog r) async {
    logs.insert(0, r);
    await save();
    notifyListeners();
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final store = Store();
  int tab = 0;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    store.load().then((_) => setState(() => ready = true));
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: gold)));
    }

    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        final pages = [
          Dashboard(store: store, go: (i) => setState(() => tab = i)),
          CalculatorPage(store: store),
          ProductsPage(store: store),
          HistoryPage(store: store),
          SettingsPage(store: store),
        ];

        return Scaffold(
          body: SafeArea(child: pages[tab]),
          bottomNavigationBar: NavigationBar(
            backgroundColor: const Color(0xFF040B13),
            indicatorColor: gold.withOpacity(.2),
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: gold), label: "Home"),
              NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate, color: gold), label: "Calc"),
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2, color: gold), label: "Products"),
              NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history, color: gold), label: "History"),
              NavigationDestination(icon: Icon(Icons.settings), selectedIcon: Icon(Icons.settings, color: gold), label: "More"),
            ],
          ),
        );
      },
    );
  }
}

Widget logo([double h = 74]) => Image.asset("assets/nates_logo.png", height: h, fit: BoxFit.contain);

class Header extends StatelessWidget {
  final String title;
  final Widget? action;

  const Header(this.title, {super.key, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            logo(42),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            if (action != null) action!,
          ],
        ),
      );
}

class ProCard extends StatelessWidget {
  final Widget child;

  const ProCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: child,
      );
}

class GoldButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const GoldButton(this.text, this.icon, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: navy),
        label: Text(text, style: const TextStyle(color: navy, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

class Dashboard extends StatelessWidget {
  final Store store;
  final ValueChanged<int> go;

  const Dashboard({super.key, required this.store, required this.go});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = store.logs.where((r) => r.date.year == now.year && r.date.month == now.month && r.date.day == now.day).toList();
    final cases = today.fold<double>(0, (a, b) => a + b.cases);
    final dry = today.fold<double>(0, (a, b) => a + b.dryLb);

    return ListView(
      children: [
        const SizedBox(height: 14),
        Center(child: logo(90)),
        const Center(child: Text("NATE'S PRODUCTION PRO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        const Center(child: Text("Blancher & Production Management", style: TextStyle(color: gold, fontWeight: FontWeight.w600))),
        ProCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("CURRENT PRODUCT", style: TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 12)),
              Text(store.active?.name ?? "No product selected", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text(
                store.active == null ? "Create a product to begin" : "Yield ${f(store.active!.growthRate)} • Cook ${f(store.active!.cookMinutes)} min",
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              GoldButton("START CALCULATOR", Icons.play_arrow, () => go(1)),
            ],
          ),
        ),
        ProCard(
          child: Column(
            children: [
              const Text("TODAY'S PRODUCTION", style: TextStyle(color: gold, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(children: [stat("CASES", f0(cases)), stat("DRY LB", f0(dry))]),
              const SizedBox(height: 8),
              Row(children: [stat("RUNS", today.length.toString()), stat("PRODUCTS", store.products.length.toString())]),
            ],
          ),
        ),
      ],
    );
  }

  Widget stat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: navy2, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: gold, fontSize: 11)),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
}

class CalculatorPage extends StatefulWidget {
  final Store store;

  const CalculatorPage({super.key, required this.store});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  late TextEditingController name;
  late TextEditingController dry;
  late TextEditingController sec;
  late TextEditingController yieldC;
  late TextEditingController cases;
  late TextEditingController caseW;
  late TextEditingController cook;
  CalcResult? result;

  @override
  void initState() {
    super.initState();
    load(widget.store.active);
  }

  void load(Product? p) {
    p ??= Product(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: "New Product",
      dryWeightPerFeed: 20,
      secondsPerFeed: 33,
      growthRate: 2.05,
      finishedCasesNeeded: 1000,
      caseWeight: 20,
      cookMinutes: 13,
    );

    name = TextEditingController(text: p.name);
    dry = TextEditingController(text: f(p.dryWeightPerFeed));
    sec = TextEditingController(text: f0(p.secondsPerFeed));
    yieldC = TextEditingController(text: f(p.growthRate));
    cases = TextEditingController(text: f0(p.finishedCasesNeeded));
    caseW = TextEditingController(text: f(p.caseWeight));
    cook = TextEditingController(text: f(p.cookMinutes));
  }

  double val(TextEditingController c) => double.tryParse(c.text) ?? 0;

  Product current() => Product(
        id: widget.store.active?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.text.trim().isEmpty ? "Unnamed Product" : name.text.trim(),
        dryWeightPerFeed: val(dry),
        secondsPerFeed: val(sec),
        growthRate: val(yieldC),
        finishedCasesNeeded: val(cases),
        caseWeight: val(caseW),
        cookMinutes: val(cook),
        favorite: widget.store.active?.favorite ?? false,
      );

  void doCalc() {
    try {
      setState(() => result = calculate(current()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Header(
            "Calculator",
            action: IconButton(
              icon: const Icon(Icons.save, color: gold),
              onPressed: () async {
                await widget.store.upsert(current());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product saved")));
                }
              },
            ),
          ),
          ProCard(
            child: Column(
              children: [
                field("Product name", name, number: false),
                field("Dry weight per feed", dry, suffix: "lb"),
                field("Seconds per feed", sec, suffix: "sec"),
                field("Growth rate / yield", yieldC, suffix: "x"),
                field("Finished cases needed", cases, suffix: "cases"),
                field("Case weight", caseW, suffix: "lb"),
                field("Blancher cook duration", cook, suffix: "min"),
                const SizedBox(height: 10),
                GoldButton("CALCULATE", Icons.calculate, doCalc),
              ],
            ),
          ),
          if (result != null) resultCard(result!),
        ],
      );

  Widget field(String label, TextEditingController c, {String suffix = "", bool number = true}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(
          controller: c,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            filled: true,
            fillColor: navy2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      );

  Widget resultCard(CalcResult r) => ProCard(
        child: Column(
          children: [
            const Text("STOP FEEDING WHEN PACKED CASES REACH", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            Text(f(r.stopCases), style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: goldBright)),
            const Text("cases", style: TextStyle(color: muted)),
            const Divider(color: Colors.white12),
            row("Remaining cases in blancher", "${f(r.flushCases)} cases"),
            row("Dry pounds per minute", "${f(r.dryLbMin)} lb/min"),
            row("Cooked pounds per minute", "${f(r.cookedLbMin)} lb/min"),
            row("Time from start to stop", timeFmt(r.stopMinutes)),
            row("Total dry pounds fed", "${f(r.dryFed)} lb"),
            row("Total cooked pounds", "${f(r.cookedTotal)} lb"),
            const SizedBox(height: 12),
            GoldButton("START PRODUCTION TIMER", Icons.timer, () async {
              final p = current();
              await widget.store.upsert(p);
              await widget.store.logRun(
                RunLog(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  productName: p.name,
                  date: DateTime.now(),
                  cases: p.finishedCasesNeeded,
                  stopCases: r.stopCases,
                  dryLb: r.dryFed,
                  cookedLb: r.cookedTotal,
                  yieldFactor: p.growthRate,
                ),
              );
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TimerScreen(product: p, result: r)));
              }
            }),
          ],
        ),
      );

  Widget row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(a, style: const TextStyle(color: muted))), Text(b, style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
}

class TimerScreen extends StatefulWidget {
  final Product product;
  final CalcResult result;

  const TimerScreen({super.key, required this.product, required this.result});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? timer;
  late int remain;
  int elapsed = 0;
  bool running = true;
  bool buzzed = false;

  @override
  void initState() {
    super.initState();
    remain = (widget.result.stopMinutes * 60).round();
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!running) return;
      setState(() {
        if (remain > 0) remain--;
        elapsed++;
      });
      if (remain == 0 && !buzzed) {
        buzzed = true;
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          Vibration.vibrate(pattern: [0, 800, 300, 800, 300, 1200]);
        }
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = remain <= 0;
    return Scaffold(
      backgroundColor: done ? const Color(0xFF350909) : navy,
      body: SafeArea(
        child: ListView(
          children: [
            Header("Live Run", action: IconButton(icon: const Icon(Icons.close, color: gold), onPressed: () => Navigator.pop(context))),
            ProCard(
              child: Column(
                children: [
                  Text(widget.product.name.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  Text(done ? "STOP FEEDING NOW" : "STOP FEEDING IN", style: TextStyle(color: done ? red : gold, fontWeight: FontWeight.w900)),
                  Text(clockSecs(remain), style: TextStyle(fontSize: 76, fontWeight: FontWeight.w900, color: done ? red : green)),
                  const Divider(color: Colors.white12),
                  big("STOP FEEDING", f(widget.result.stopCases)),
                  big("TARGET CASES", f0(widget.product.finishedCasesNeeded)),
                  big("ELAPSED", clockSecs(elapsed)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => running = !running),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: gold), minimumSize: const Size(0, 52)),
                          child: Text(running ? "PAUSE" : "RESUME", style: const TextStyle(color: gold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: red, minimumSize: const Size(0, 52)),
                          child: const Text("END RUN"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget big(String label, String value) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: navy2, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Text(label, style: const TextStyle(color: gold, fontSize: 11)), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))]),
      );
}

class ProductsPage extends StatefulWidget {
  final Store store;

  const ProductsPage({super.key, required this.store});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String q = "";

  @override
  Widget build(BuildContext context) {
    final items = widget.store.products.where((p) => p.name.toLowerCase().contains(q.toLowerCase())).toList();

    return ListView(
      children: [
        Header("Products", action: IconButton(icon: const Icon(Icons.add, color: gold), onPressed: () => editor())),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: "Search products",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        ...items.map(
          (p) => ProCard(
            child: Row(
              children: [
                Icon(p.favorite ? Icons.star : Icons.inventory_2, color: gold),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      widget.store.active = p;
                      widget.store.notifyListeners();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${p.name} selected")));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text("Yield ${f(p.growthRate)} • Cook ${f(p.cookMinutes)} min • Feed ${f0(p.secondsPerFeed)} sec", style: const TextStyle(color: muted)),
                      ],
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit, color: gold), onPressed: () => editor(p)),
                IconButton(icon: const Icon(Icons.delete_outline, color: red), onPressed: () => widget.store.delete(p)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void editor([Product? p]) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: navy,
        builder: (_) => ProductEditor(store: widget.store, product: p),
      );
}

class ProductEditor extends StatefulWidget {
  final Store store;
  final Product? product;

  const ProductEditor({super.key, required this.store, this.product});

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  late TextEditingController name;
  late TextEditingController dry;
  late TextEditingController sec;
  late TextEditingController yieldC;
  late TextEditingController cases;
  late TextEditingController caseW;
  late TextEditingController cook;
  bool fav = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? "");
    dry = TextEditingController(text: f(p?.dryWeightPerFeed ?? 20));
    sec = TextEditingController(text: f0(p?.secondsPerFeed ?? 33));
    yieldC = TextEditingController(text: f(p?.growthRate ?? 2.05));
    cases = TextEditingController(text: f0(p?.finishedCasesNeeded ?? 1000));
    caseW = TextEditingController(text: f(p?.caseWeight ?? 20));
    cook = TextEditingController(text: f(p?.cookMinutes ?? 13));
    fav = p?.favorite ?? false;
  }

  double v(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 18),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(widget.product == null ? "New Product" : "Edit Product", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              e("Name", name, false),
              e("Dry weight/feed", dry),
              e("Seconds/feed", sec),
              e("Growth rate", yieldC),
              e("Cases needed", cases),
              e("Case weight", caseW),
              e("Cook minutes", cook),
              SwitchListTile(value: fav, onChanged: (x) => setState(() => fav = x), activeColor: gold, title: const Text("Favorite")),
              GoldButton("SAVE PRODUCT", Icons.save, () async {
                await widget.store.upsert(
                  Product(
                    id: widget.product?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name.text.trim().isEmpty ? "Unnamed Product" : name.text.trim(),
                    dryWeightPerFeed: v(dry),
                    secondsPerFeed: v(sec),
                    growthRate: v(yieldC),
                    finishedCasesNeeded: v(cases),
                    caseWeight: v(caseW),
                    cookMinutes: v(cook),
                    favorite: fav,
                  ),
                );
                if (mounted) Navigator.pop(context);
              })
            ],
          ),
        ),
      );

  Widget e(String label, TextEditingController c, [bool number = true]) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(
          controller: c,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      );
}

class HistoryPage extends StatelessWidget {
  final Store store;

  const HistoryPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const Header("History"),
          if (store.logs.isEmpty) const ProCard(child: Text("No runs yet. Start a production timer to record history.")),
          ...store.logs.map(
            (r) => ProCard(
              child: Row(
                children: [
                  Container(width: 4, height: 70, decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${r.date.month}/${r.date.day}/${r.date.year} ${r.date.hour}:${r.date.minute.toString().padLeft(2, '0')}", style: const TextStyle(color: muted)),
                        Text(r.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text("Yield ${f(r.yieldFactor)} • Stop ${f(r.stopCases)} cases", style: const TextStyle(color: muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${f0(r.cases)} Cases", style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text("${f0(r.cookedLb)} lb", style: const TextStyle(color: muted)),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      );
}

class SettingsPage extends StatelessWidget {
  final Store store;

  const SettingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final totalCases = store.logs.fold<double>(0, (a, b) => a + b.cases);

    return ListView(
      children: [
        const Header("Reports & Settings"),
        ProCard(
          child: Column(
            children: [
              logo(80),
              const SizedBox(height: 10),
              const Text("Nate's Fine Foods", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const Text("Roseville, California", style: TextStyle(color: gold)),
              const Divider(color: Colors.white12),
              line("Theme", "Navy & Gold"),
              line("Saved products", store.products.length.toString()),
              line("Runs recorded", store.logs.length.toString()),
              line("Total cases recorded", f0(totalCases)),
              line("Version", "1.0.0"),
            ],
          ),
        ),
        const ProCard(
          child: Text(
            "Next upgrades: PDF reports, Excel export, operator names, batch numbers, multiple blancher lines, notification alarms, and backup/restore.",
            style: TextStyle(color: muted),
          ),
        ),
      ],
    );
  }

  Widget line(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Expanded(child: Text(a, style: const TextStyle(color: muted))), Text(b, style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
}
