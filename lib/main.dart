import 'package:flutter/material.dart';
import 'ai_service.dart';

void main() {
  runApp(const NhAiAgentApp());
}

const Color kBg = Color(0xFF07080D);
const Color kSurface = Color(0xFF13151E);
const Color kBorder = Color(0xFF222636);
const Color kMuted = Color(0xFF8A8FA3);
const Color kAccentA = Color(0xFF7C8CFF);
const Color kAccentB = Color(0xFF36E3C4);
const Color kWarn = Color(0xFFFFB547);

class NhAiAgentApp extends StatelessWidget {
  const NhAiAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NHAI Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kAccentA, secondary: kAccentB),
        useMaterial3: true,
      ),
      home: const AgentHome(),
    );
  }
}

class Plan {
  Plan(this.text, this.category);
  final String text;
  final String category;
  String state = 'pending';
  String log = '';
}

class AgentHome extends StatefulWidget {
  const AgentHome({super.key});

  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  final List<Plan> _plans = [];
  final TextEditingController _controller = TextEditingController();
  int _tab = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Plan> get _pending => _plans.where((p) => p.state == 'pending').toList();

  String _classify(String t) {
    if (t.contains('ইমেইল')) return 'ইমেইল';
    if (t.contains('ভিডিও') || t.contains('থাম্বনেল') || t.contains('ইউটিউব')) return 'ইউটিউব';
    if (t.contains('মেসেজ') || t.contains('বস') || t.contains('হোয়াটসঅ্যাপ')) return 'হোয়াটসঅ্যাপ';
    if (t.contains('অ্যালার্ম') || t.contains('রিমাইন্ডার') || t.contains('ফোন')) return 'মোবাইল';
    return 'সাধারণ';
  }

  // Only actions that send, change or set something need approval.
  bool _needsApproval(String t) {
    return RegExp('পাঠাও|সেট|চালু|বানাও|উন্নত|খসড়া|মুছ|বাতিল').hasMatch(t);
  }

  void _submit(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return;
    final Plan plan = Plan(text, _classify(text));
    final bool auto = !_needsApproval(text);
    _controller.clear();
    setState(() {
      _plans.insert(0, plan); // নতুনটা সবার উপরে
      _tab = 1; // কার্যকলাপ ট্যাবে নিয়ে যাবে
    });
    if (auto) {
      _run(plan);
    }
  }

  Future<void> _run(Plan plan) async {
    setState(() {
      plan.state = 'running';
      plan.log = 'উত্তর খোঁজা হচ্ছে…';
    });
    String result;
    if (plan.category == 'সাধারণ') {
      result = await AiService.ask(plan.text);
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
      result = 'সম্পন্ন হয়েছে';
    }
    if (!mounted) return;
    setState(() {
      plan.state = 'done';
      plan.log = result;
    });
  }

  void _cancel(Plan plan) {
    setState(() {
      plan.state = 'cancelled';
      plan.log = 'বাতিল করা হয়েছে';
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _buildHome(),
      _buildActivity(),
      _buildCategory('ইমেইল', ['ইমেইল সারাংশ দেখাও', 'জরুরি ইমেইলের উত্তর খসড়া করো']),
      _buildCategory('ইউটিউব', ['ভিডিওর স্ক্রিপ্ট বানাও', 'আমার সাম্প্রতিক ভিডিও চেক করো', 'থাম্বনেল ডিজাইন করো']),
      _buildCategory('হোয়াটসঅ্যাপ', ['সব অপঠিত মেসেজের সারাংশ দাও', 'বসের মেসেজের উত্তর পাঠাও']),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: IndexedStack(index: _tab, children: pages),
            ),
            _composer(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() => _tab = i),
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

  Widget _header() {
    final int count = _pending.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kAccentA, kAccentB]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('N', style: TextStyle(color: kBg, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('NHAI Agent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: kWarn, borderRadius: BorderRadius.circular(999)),
              child: Text('$count', style: const TextStyle(color: kBg, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'একটি কমান্ড লিখুন…',
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: kBorder),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _submit(_controller.text),
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final List<Plan> recent = _plans.take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _label('অপেক্ষমাণ অনুমোদন'),
        if (_pending.isEmpty)
          _empty('কোনো অপেক্ষমাণ অনুমোদন নেই')
        else
          ..._pending.map(_planCard),
        _label('সাম্প্রতিক'),
        if (recent.isEmpty)
          _empty('এখনো কিছু করা হয়নি')
        else
          ...recent.map(_planCard),
        _label('দ্রুত কমান্ড'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final String c in ['আজকের কাজের সারাংশ দাও', 'ইমেইল সারাংশ দেখাও', 'একটি রিমাইন্ডার সেট করো'])
              ActionChip(label: Text(c), onPressed: () => _submit(c)),
          ],
        ),
      ],
    );
  }

  Widget _buildActivity() {
    if (_plans.isEmpty) {
      return _empty('এখনো কোনো কমান্ড দেওয়া হয়নি');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: _plans.map(_planCard).toList(),
    );
  }

  Widget _buildCategory(String title, List<String> commands) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _label(title),
        for (final String c in commands)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: kSurface,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              title: Text(c),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kMuted),
              onTap: () => _submit(c),
            ),
          ),
      ],
    );
  }

  Widget _planCard(Plan plan) {
    final bool pending = plan.state == 'pending';
    String statusText = 'বাতিল';
    if (plan.state == 'pending') {
      statusText = 'অনুমোদন দরকার';
    } else if (plan.state == 'running') {
      statusText = 'চলছে';
    } else if (plan.state == 'done') {
      statusText = 'সম্পন্ন';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: pending ? kWarn : kBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.text, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(statusText, style: TextStyle(fontSize: 11, color: pending ? kWarn : kMuted)),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            plan.state == 'done' || plan.state == 'cancelled' || plan.state == 'running'
                ? (plan.log.isEmpty ? plan.category : plan.log)
                : plan.category,
            style: const TextStyle(fontSize: 14, color: kMuted, height: 1.6),
          ),
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancel(plan),
                    child: const Text('বাতিল'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _run(plan),
                    child: const Text('চালাও'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _empty(String text) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(child: Text(text, style: const TextStyle(color: kMuted))),
    );
  }
}
