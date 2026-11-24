import 'package:flutter/material.dart';

void main() => runApp(const NhAiAgentApp());

const _bg = Color(0xFF07080D);
const _surface = Color(0x0FFFFFFF);
const _border = Color(0x17FFFFFF);
const _muted = Color(0xFF8A8FA3);
const _accentA = Color(0xFF7C8CFF);
const _accentB = Color(0xFF36E3C4);
const _warn = Color(0xFFFFB547);
const _grad = LinearGradient(colors: [_accentA, _accentB]);

class NhAiAgentApp extends StatelessWidget {
  const NhAiAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NHAI Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _accentA, secondary: _accentB),
        useMaterial3: true,
      ),
      home: const AgentShell(),
    );
  }
}

/// A command becomes a plan. Read-only plans run immediately; anything that
/// sends, changes or sets something waits for the user's approval.
class Plan {
  Plan({required this.id, required this.text, required this.category, required this.readOnly});
  final int id;
  final String text;
  final String category;
  final bool readOnly;
  String state = 'pending';
  String log = '';
}

class AgentShell extends StatefulWidget {
  const AgentShell({super.key});
  @override
  State<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends State<AgentShell> {
  int _tab = 0;
  final _plans = <Plan>[];
  final _controller = TextEditingController();
  int _nextId = 1;

  List<Plan> get _pending => _plans.where((p) => p.state == 'pending').toList();

  String _classify(String t) {
    if (t.contains('ইমেইল')) return 'ইমেইল';
    if (RegExp('ভিডিও|থাম্বনেল|শিরোনাম|ইউটিউব').hasMatch(t)) return 'ইউটিউব';
    if (RegExp('মেসেজ|বস|হোয়াটসঅ্যাপ').hasMatch(t)) return 'হোয়াটসঅ্যাপ';
    if (RegExp('অ্যালার্ম|স্টোরেজ|ব্যাটারি|রিমাইন্ডার|ফোন').hasMatch(t)) return 'মোবাইল';
    return 'সাধারণ';
  }

  void _submit(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final readOnly = RegExp('দেখাও|সারাংশ|চেক|পরামর্শ').hasMatch(text) &&
        !RegExp('পাঠাও|সেট|চালু|বানাও|উন্নত|খসড়া').hasMatch(text);
    final plan = Plan(id: _nextId++, text: text, category: _classify(text), readOnly: readOnly);
    setState(() => _plans.add(plan));
    _controller.clear();
    if (readOnly) _run(plan);
  }

  // Placeholder execution. Real connectors (Gmail, etc.) plug in here.
  Future<void> _run(Plan plan) async {
    setState(() => plan.state = 'running');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      plan.state = 'done';
      plan.log = 'সম্পন্ন হয়েছে';
    });
  }

  void _approve(Plan plan) => _run(plan);

  void _cancel(Plan plan) => setState(() {
        plan.state = 'cancelled';
        plan.log = 'বাতিল করা হয়েছে';
      });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(pending: _pending, onApprove: _approve, onCancel: _cancel, onCommand: _submit),
      _ActivityPage(plans: _plans.reversed.toList(), onApprove: _approve, onCancel: _cancel),
      _CategoryPage(title: 'ইমেইল', commands: const ['ইমেইল সারাংশ দেখাও', 'জরুরি ইমেইলের উত্তর খসড়া করো'], onCommand: _submit),
      _CategoryPage(title: 'ইউটিউব', commands: const ['ভিডিওর স্ক্রিপ্ট বানাও', 'আমার সাম্প্রতিক ভিডিও চেক করো', 'থাম্বনেল ডিজাইন করো'], onCommand: _submit),
      _CategoryPage(title: 'হোয়াটসঅ্যাপ', commands: const ['সব অপঠিত মেসেজের সারাংশ দাও', 'বসের মেসেজের উত্তর পাঠাও'], onCommand: _submit),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(pendingCount: _pending.length),
            Expanded(child: IndexedStack(index: _tab, children: pages)),
            _Composer(controller: _controller, onSubmit: _submit),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _surface,
        indicatorColor: _accentA.withValues(alpha: 0.2),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'হোম'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'কার্যকলাপ'),
          NavigationDestination(icon: Icon(Icons.mail_outline), label: 'ইমেইল'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'ইউটিউব'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'হোয়াটসঅ্যাপ'),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: _grad, borderRadius: BorderRadius.circular(12)),
            child: const Text('N', style: TextStyle(color: _bg, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NHAI Agent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                Text('সক্রিয় · অনুমোদন ছাড়া কিছু করবে না', style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: _warn, borderRadius: BorderRadius.circular(999)),
              child: Text('$pendingCount', style: const TextStyle(color: _bg, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: onSubmit,
                decoration: const InputDecoration(
                  hintText: 'একটি কমান্ড লিখুন…',
                  hintStyle: TextStyle(color: _muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton.filled(
              onPressed: () => onSubmit(controller.text),
              icon: const Icon(Icons.arrow_upward, color: _bg),
              style: IconButton.styleFrom(backgroundColor: _accentA),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.pending, required this.onApprove, required this.onCancel, required this.onCommand});
  final List<Plan> pending;
  final void Function(Plan) onApprove;
  final void Function(Plan) onCancel;
  final void Function(String) onCommand;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const _Label('অপেক্ষমাণ অনুমোদন'),
        if (pending.isEmpty)
          const _Empty('কোনো অপেক্ষমাণ অনুমোদন নেই')
        else
          ...pending.map((p) => _PlanCard(plan: p, onApprove: onApprove, onCancel: onCancel)),
        const _Label('দ্রুত কমান্ড'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            'আজকের কাজের সারাংশ দাও',
            'ইমেইল সারাংশ দেখাও',
            'একটি রিমাইন্ডার সেট করো',
          ].map((c) => ActionChip(label: Text(c), onPressed: () => onCommand(c))).toList(),
        ),
      ],
    );
  }
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage({required this.plans, required this.onApprove, required this.onCancel});
  final List<Plan> plans;
  final void Function(Plan) onApprove;
  final void Function(Plan) onCancel;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const _Empty('এখনো কোনো কমান্ড দেওয়া হয়নি');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: plans.map((p) => _PlanCard(plan: p, onApprove: onApprove, onCancel: onCancel)).toList(),
    );
  }
}

class _CategoryPage extends StatelessWidget {
