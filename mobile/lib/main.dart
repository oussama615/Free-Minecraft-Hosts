import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/api_client.dart';

void main() => runApp(EMPControlApp(api: ApiClient()));

const _black = Color(0xFF05030A);
const _panel = Color(0xFF11101B);
const _panel2 = Color(0xFF1B1230);
const _purple = Color(0xFF8E2BFF);
const _neon = Color(0xFFD65CFF);
const _softWhite = Color(0xFFF4EDFF);
const _muted = Color(0xFFAFA3C7);

enum TabPage { dashboard, activity, logs, security, about }

class EMPControlApp extends StatelessWidget {
  const EMPControlApp({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EMP Control',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: _black,
          colorScheme: ColorScheme.fromSeed(seedColor: _purple, brightness: Brightness.dark),
        ),
        home: LoginScreen(api: api),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const _Background(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: _Card(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: const [
                    _Logo(size: 70),
                    SizedBox(width: 14),
                    Expanded(child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text('EMP CONTROL', maxLines: 1, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1.8)))),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Your Server. Your World.', style: TextStyle(color: _muted)),
                  const SizedBox(height: 24),
                  TextField(controller: username, decoration: const InputDecoration(labelText: 'Username or Email', prefixIcon: Icon(Icons.person_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_rounded)), onSubmitted: (_) => _login()),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: _login, child: const Text('Enter Control Panel')),
                ]),
              ),
            ),
          ),
        ]),
      );

  void _login() {
    final name = username.text.trim();
    if (name.isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter username and password.');
      return;
    }
    widget.api.currentUser = EmpUser('local-owner', name, name, 'OWNER');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(api: widget.api)));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TabPage tab = TabPage.dashboard;
  int selected = 0;
  final logs = <String>['Steve joined Survival', 'Admin used /list', 'Server saved the world', 'Security monitor ready'];
  final activity = <String>['Owner opened dashboard', 'Owner opened console', 'Owner viewed logs'];

  DashboardServer get server => demoServers[selected];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(children: [
            const _Background(),
            Column(children: [
              _Header(user: widget.api.currentUser!, onLogout: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)))),
              Expanded(child: _body()),
              _Nav(tab: tab, onChange: (value) => setState(() => tab = value)),
            ]),
          ]),
        ),
      );

  Widget _body() => switch (tab) {
        TabPage.dashboard => _Dashboard(server: server, servers: demoServers, selected: selected, onSelect: (i) => setState(() => selected = i), onConsole: _openConsole, onUsers: _openUsers),
        TabPage.activity => _ListPage(title: 'Activity', subtitle: 'Actions done inside EMP Control.', items: activity),
        TabPage.logs => _ListPage(title: 'Logs', subtitle: 'Server and player records.', items: logs),
        TabPage.security => const _ListPage(title: 'Security', subtitle: 'Protection status.', items: ['OP protection enabled', 'Dangerous commands monitored', 'No alerts right now']),
        TabPage.about => _About(user: widget.api.currentUser!),
      };

  void _openConsole() => Navigator.push(context, MaterialPageRoute(builder: (_) => ConsoleScreen(server: server, onCommand: (cmd) => setState(() => logs.insert(0, 'Console command: $cmd')))));
  void _openUsers() => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.server, required this.servers, required this.selected, required this.onSelect, required this.onConsole, required this.onUsers});
  final DashboardServer server;
  final List<DashboardServer> servers;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onConsole;
  final VoidCallback onUsers;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 88, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: servers.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) => _ServerChip(server: servers[i], selected: i == selected, onTap: () => onSelect(i)))),
          const SizedBox(height: 16),
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(server.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text('${server.mode} • ${server.software} • ${server.version}', style: const TextStyle(color: _muted)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Metric('Players', '${server.playersOnline}/${server.maxPlayers}'),
              _Metric('CPU', '${server.cpuPercent}%'),
              _Metric('RAM', '${server.ramPercent}%'),
              _Metric('TPS', server.tps.toStringAsFixed(1)),
              _Metric('Ping', '${server.pingMs}ms'),
            ]),
          ])),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _ActionButton('Start', Icons.play_arrow_rounded)), const SizedBox(width: 10), Expanded(child: _ActionButton('Stop', Icons.stop_rounded)), const SizedBox(width: 10), Expanded(child: _ActionButton('Restart', Icons.restart_alt_rounded))]),
          const SizedBox(height: 18),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.35, children: [
            _Feature('Console', Icons.terminal_rounded, onConsole),
            _Feature('Players', Icons.groups_rounded, () {}),
            _Feature('Plugins', Icons.extension_rounded, () {}),
            _Feature('Settings', Icons.tune_rounded, () {}),
            _Feature('Users & Roles', Icons.manage_accounts_rounded, onUsers),
            _Feature('Stats', Icons.query_stats_rounded, () {}),
          ]),
        ]),
      );
}

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key, required this.server, required this.onCommand});
  final DashboardServer server;
  final ValueChanged<String> onCommand;

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final controller = TextEditingController();
  final output = <String>[];

  @override
  void initState() {
    super.initState();
    output.add('[EMP] Connected to ${widget.server.name} console preview');
  }

  @override
  Widget build(BuildContext context) => _SubPage(title: 'Console', child: Column(children: [
        Container(height: 360, width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.black.withOpacity(.45), borderRadius: BorderRadius.circular(18), border: Border.all(color: _purple.withOpacity(.25))), child: ListView(children: output.map((e) => Text(e, style: const TextStyle(fontFamily: 'monospace'))).toList())),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: ['/list', '/say hello', '/plugins', '/restart'].map((c) => ActionChip(label: Text(c), onPressed: () => _send(c))).toList()),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Command'))), const SizedBox(width: 8), FilledButton(onPressed: () => _send(controller.text), child: const Text('Send'))]),
      ]));

  void _send(String text) {
    if (text.trim().isEmpty) return;
    widget.onCommand(text.trim());
    setState(() { output.add('> ${text.trim()}'); output.add('[Preview] Command shown only.'); controller.clear(); });
  }
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) => _SubPage(title: 'Users & Roles', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        _UserTile('xk7', 'Owner'),
        _UserTile('Staff One', 'Moderator'),
        SizedBox(height: 16),
        Text('Permissions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('view_dashboard')), Chip(label: Text('view_logs')), Chip(label: Text('view_console')), Chip(label: Text('send_console_commands')), Chip(label: Text('manage_permissions'))]),
      ]));
}

class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.subtitle, required this.items});
  final String title;
  final String subtitle;
  final List<String> items;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: _muted)), const SizedBox(height: 16), ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _Card(child: Row(children: [const Icon(Icons.bolt_rounded, color: _neon), const SizedBox(width: 12), Expanded(child: Text(e))])))]));
}

class _About extends StatelessWidget {
  const _About({required this.user});
  final EmpUser user;
  @override
  Widget build(BuildContext context) => _ListPage(title: 'About', subtitle: 'EMP Control mobile app.', items: ['Signed in as ${user.displayName}', 'Real controls require backend + plugin', 'Preview UI is available offline']);
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onLogout});
  final EmpUser user;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(18), child: _Card(child: Row(children: [const _Logo(size: 54), const SizedBox(width: 12), const Expanded(child: Text('EMP CONTROL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))), Text(user.displayName, style: const TextStyle(color: _muted)), IconButton(onPressed: onLogout, icon: const Icon(Icons.logout))])));
}

class _Nav extends StatelessWidget {
  const _Nav({required this.tab, required this.onChange});
  final TabPage tab;
  final ValueChanged<TabPage> onChange;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24)), child: Row(children: TabPage.values.map((item) => Expanded(child: InkWell(onTap: () => onChange(item), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(_tabIcon(item), color: item == tab ? _neon : _muted), Text(_tabLabel(item), style: TextStyle(fontSize: 11, color: item == tab ? _softWhite : _muted))])))).toList()));
}

class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Stack(children: [const _Background(), SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)), Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 16), child]))])));
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [_panel, _panel2]), border: Border.all(color: _purple.withOpacity(.32)), boxShadow: [BoxShadow(color: _purple.withOpacity(.22), blurRadius: 28)]), child: child);
}

class _Logo extends StatelessWidget { const _Logo({required this.size}); final double size; @override Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .28), gradient: const LinearGradient(colors: [_purple, _neon])), child: Center(child: Text('EMP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * .24)))); }
class _Background extends StatelessWidget { const _Background(); @override Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(-.8, -.9), radius: 1.2, colors: [Color(0xFF2C0E55), _black]))); }
class _ServerChip extends StatelessWidget { const _ServerChip({required this.server, required this.selected, required this.onTap}); final DashboardServer server; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(width: 145, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: selected ? _panel2 : _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? _neon : Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(server.name, style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('${server.playersOnline}/${server.maxPlayers}', style: const TextStyle(color: _muted))]))); }
class _Metric extends StatelessWidget { const _Metric(this.label, this.value); final String label; final String value; @override Widget build(BuildContext context) => Container(width: 135, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: _muted))])); }
class _ActionButton extends StatelessWidget { const _ActionButton(this.label, this.icon); final String label; final IconData icon; @override Widget build(BuildContext context) => Container(height: 76, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [_purple.withOpacity(.9), _panel2])), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon), Text(label)])); }
class _Feature extends StatelessWidget { const _Feature(this.title, this.icon, this.onTap); final String title; final IconData icon; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _neon), const Spacer(), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]))); }
class _UserTile extends StatelessWidget { const _UserTile(this.name, this.role); final String name; final String role; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _Card(child: Row(children: [const Icon(Icons.person, color: _neon), const SizedBox(width: 12), Expanded(child: Text(name)), Chip(label: Text(role))]))); }

class DashboardServer {
  const DashboardServer({required this.name, required this.mode, required this.online, required this.playersOnline, required this.maxPlayers, required this.cpuPercent, required this.ramPercent, required this.pingMs, required this.tps, required this.version, required this.software});
  final String name; final String mode; final bool online; final int playersOnline; final int maxPlayers; final int cpuPercent; final int ramPercent; final int pingMs; final double tps; final String version; final String software;
}

const demoServers = [
  DashboardServer(name: 'Lobby', mode: 'Hub', online: true, playersOnline: 42, maxPlayers: 250, cpuPercent: 18, ramPercent: 41, pingMs: 24, tps: 20.0, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'Survival', mode: 'Survival', online: true, playersOnline: 18, maxPlayers: 80, cpuPercent: 33, ramPercent: 64, pingMs: 31, tps: 19.8, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'BoxPvP', mode: 'PvP', online: true, playersOnline: 12, maxPlayers: 120, cpuPercent: 24, ramPercent: 52, pingMs: 28, tps: 19.9, version: '1.20.4', software: 'Paper'),
];

String _tabLabel(TabPage tab) => switch (tab) { TabPage.dashboard => 'Dashboard', TabPage.activity => 'Activity', TabPage.logs => 'Logs', TabPage.security => 'Security', TabPage.about => 'About' };
IconData _tabIcon(TabPage tab) => switch (tab) { TabPage.dashboard => Icons.dashboard_rounded, TabPage.activity => Icons.touch_app_rounded, TabPage.logs => Icons.receipt_long_rounded, TabPage.security => Icons.shield_rounded, TabPage.about => Icons.info_rounded };
