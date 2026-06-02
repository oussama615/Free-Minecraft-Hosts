import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/api_client.dart';

void main() => runApp(EMPControlApp(api: ApiClient()));

class EMPControlApp extends StatelessWidget {
  const EMPControlApp({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EMP Control',
        theme: ThemeData.dark(useMaterial3: true).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark)),
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
  bool busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Card(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('EMP Control', style: Theme.of(context).textTheme.headlineLarge),
                  Text('API: ${widget.api.baseUrl}', style: Theme.of(context).textTheme.bodySmall),
                  TextField(controller: username, decoration: const InputDecoration(labelText: 'Username or email')),
                  TextField(controller: password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                  if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: busy ? null : _login, child: Text(busy ? 'Logging in...' : 'Login')),
                ]),
              ),
            ),
          ),
        ),
      );

  Future<void> _login() async {
    setState(() { busy = true; error = null; });
    try {
      await widget.api.login(username.text.trim(), password.text);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(api: widget.api)));
    } catch (exception) {
      setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  late Future<List<EmpServer>> servers = widget.api.servers();

  @override
  Widget build(BuildContext context) {
    final user = widget.api.currentUser;
    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(icon: Icon(Icons.dns), label: Text('Servers')),
      const NavigationRailDestination(icon: Icon(Icons.warning), label: Text('Alerts')),
      if (user?.owner == true) const NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
      const NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
    ];
    if (tab >= destinations.length) tab = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('EMP Control App'), actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))]),
      body: Row(children: [
        NavigationRail(selectedIndex: tab, onDestinationSelected: (index) => setState(() => tab = index), labelType: NavigationRailLabelType.all, destinations: destinations),
        Expanded(child: _pageFor(tab, user)),
      ]),
    );
  }

  Widget _pageFor(int index, EmpUser? user) {
    if (index == 0) return ServerList(future: servers, onOpen: (server) => Navigator.push(context, MaterialPageRoute(builder: (_) => ServerDetail(api: widget.api, server: server))));
    if (index == 1) return AlertsPage(api: widget.api);
    if (user?.owner == true && index == 2) return UsersPage(api: widget.api);
    return SettingsPage(api: widget.api);
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)));
  }
}

class ServerList extends StatelessWidget {
  const ServerList({super.key, required this.future, required this.onOpen});
  final Future<List<EmpServer>> future;
  final void Function(EmpServer) onOpen;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<EmpServer>>(
        future: future,
        builder: (context, state) {
          if (!state.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.all(16), children: state.data!.map((server) {
            final snap = server.snapshot ?? {};
            final health = (snap['health'] as Map?) ?? {};
            final performance = (snap['performance'] as Map?) ?? {};
            final players = (snap['players'] as Map?) ?? {};
            return Card(child: ListTile(
              leading: Icon(server.status == 'ONLINE' ? Icons.check_circle : Icons.cancel, color: server.status == 'ONLINE' ? Colors.green : Colors.red),
              title: Text(server.displayName),
              subtitle: Text('TPS ${_fmt(health['tps1m'])} • MSPT ${_fmt(health['msptAverage'])} • Players ${players['online'] ?? 0}/${players['max'] ?? 0} • RAM ${_fmt(performance['ramPercentage'])}% • ${health['serverVersion'] ?? 'unknown version'}'),
              trailing: Text(server.alerts.isEmpty ? 'No alerts' : 'Last alert'),
              onTap: () => onOpen(server),
            ));
          }).toList());
        },
      );
}

class ServerDetail extends StatefulWidget {
  const ServerDetail({super.key, required this.api, required this.server});
  final ApiClient api;
  final EmpServer server;
  @override
  State<ServerDetail> createState() => _ServerDetailState();
}

class _ServerDetailState extends State<ServerDetail> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.server.displayName)),
        body: Column(children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Dashboard')),
              ButtonSegment(value: 1, label: Text('Logs')),
              ButtonSegment(value: 2, label: Text('Security')),
              ButtonSegment(value: 3, label: Text('Console')),
            ],
            selected: {tab},
            onSelectionChanged: (value) => setState(() => tab = value.first),
          )),
          Expanded(child: switch (tab) {
            0 => StatsDashboard(api: widget.api, server: widget.server),
            1 => LogsPage(api: widget.api, serverId: widget.server.id),
            2 => SecurityPage(api: widget.api, serverId: widget.server.id),
            _ => ConsolePage(api: widget.api, server: widget.server),
          }),
        ]),
      );
}

class StatsDashboard extends StatelessWidget {
  const StatsDashboard({super.key, required this.api, required this.server});
  final ApiClient api;
  final EmpServer server;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: api.latest(server.id),
        builder: (context, state) {
          if (state.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final snap = state.data ?? server.snapshot ?? {};
          final sections = ['health', 'performance', 'players', 'worlds', 'network', 'security'];
          return GridView.count(crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1, padding: const EdgeInsets.all(16), childAspectRatio: 2.1, children: sections.map((key) => Card(child: Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(key.toUpperCase(), style: Theme.of(context).textTheme.titleLarge), Text(_pretty(snap[key]))]))))).toList());
        },
      );
}

class AlertsPage extends StatelessWidget { const AlertsPage({super.key, required this.api}); final ApiClient api; @override Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: api.alerts(null), builder: (context, state) => ListView(children: (state.data ?? []).map((alert) => ListTile(leading: Icon(Icons.warning, color: alert['severity'] == 'CRITICAL' ? Colors.red : Colors.amber), title: Text(alert['title'] as String), subtitle: Text(alert['message'] as String))).toList())); }
class LogsPage extends StatelessWidget { const LogsPage({super.key, required this.api, required this.serverId}); final ApiClient api; final String serverId; @override Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: api.logs(serverId), builder: (context, state) => ListView(children: (state.data ?? []).map((log) => ListTile(title: Text(log['message'] as String), subtitle: Text('${log['level']} • ${log['category']} • ${log['createdAt']}'))).toList())); }
class SecurityPage extends StatelessWidget { const SecurityPage({super.key, required this.api, required this.serverId}); final ApiClient api; final String serverId; @override Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: api.securityEvents(serverId), builder: (context, state) => ListView(children: (state.data ?? []).map((event) => ListTile(leading: const Icon(Icons.shield), title: Text(event['type'] as String), subtitle: Text('${event['action']} ${event['subject'] ?? ''}'))).toList())); }

class ConsolePage extends StatefulWidget { const ConsolePage({super.key, required this.api, required this.server}); final ApiClient api; final EmpServer server; @override State<ConsolePage> createState() => _ConsolePageState(); }
class _ConsolePageState extends State<ConsolePage> { final command = TextEditingController(); String result = 'OWNER only in MVP'; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: command, decoration: const InputDecoration(labelText: 'Minecraft console command (no slash)')), FilledButton(onPressed: widget.api.currentUser?.owner != true ? null : () async { final response = await widget.api.sendCommand(widget.server.id, command.text); setState(() => result = response.toString()); }, child: const Text('Send approved command')), Text(result)])); }
class UsersPage extends StatelessWidget { const UsersPage({super.key, required this.api}); final ApiClient api; @override Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: api.users(), builder: (context, state) => ListView(children: (state.data ?? []).map((user) => ListTile(leading: const Icon(Icons.person), title: Text(user['displayName'] as String), subtitle: Text('${user['username']} • ${user['role']}'))).toList())); }
class SettingsPage extends StatelessWidget { const SettingsPage({super.key, required this.api}); final ApiClient api; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('API URL: ${api.baseUrl}\n\nAndroid emulator default: http://10.0.2.2:3000\nPhysical phone: build with your PC LAN IP or a tunnel URL.\n\niOS builds require Mac, Xcode, an Apple Developer Account, and TestFlight/App Store later.'))); }

String _fmt(dynamic value) => value is num ? value.toStringAsFixed(1) : '--';
String _pretty(dynamic value) => value == null ? 'No data yet' : value.toString();
