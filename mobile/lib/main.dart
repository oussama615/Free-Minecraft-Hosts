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

enum ConnectionMode { loading, connected, offlineDemo, error }

enum DashboardTab { dashboard, activity, security, about }

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
          snackBarTheme: const SnackBarThemeData(backgroundColor: _panel2, contentTextStyle: TextStyle(color: _softWhite)),
          textTheme: ThemeData.dark().textTheme.apply(bodyColor: _softWhite, displayColor: _softWhite),
        ),
        home: ControlShell(api: api),
      );
}

class ControlShell extends StatefulWidget {
  const ControlShell({super.key, required this.api});
  final ApiClient api;

  @override
  State<ControlShell> createState() => _ControlShellState();
}

class _ControlShellState extends State<ControlShell> {
  ConnectionMode mode = ConnectionMode.loading;
  DashboardTab tab = DashboardTab.dashboard;
  List<DashboardServer> servers = demoServers;
  int selectedServer = 0;
  String? error;
  bool loadingServers = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => mode = ConnectionMode.loading);
    final online = await widget.api.healthCheck();
    if (!mounted) return;
    if (!online) {
      setState(() {
        mode = ConnectionMode.offlineDemo;
        servers = demoServers;
        error = null;
      });
      return;
    }
    setState(() => mode = ConnectionMode.connected);
    await _refreshServers();
  }

  Future<void> _refreshServers() async {
    if (widget.api.currentUser == null) return;
    setState(() => loadingServers = true);
    try {
      final realServers = await widget.api.servers();
      if (!mounted) return;
      setState(() {
        servers = realServers.isEmpty ? demoServers : realServers.map(DashboardServer.fromEmpServer).toList();
        selectedServer = 0;
        error = null;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        mode = ConnectionMode.offlineDemo;
        servers = demoServers;
        error = '$exception';
      });
    } finally {
      if (mounted) setState(() => loadingServers = false);
    }
  }

  DashboardServer get current => servers[_safeIndex(selectedServer, servers.length)];
  bool get demo => mode != ConnectionMode.connected || widget.api.currentUser == null || servers == demoServers;

  @override
  Widget build(BuildContext context) {
    if (widget.api.currentUser == null) {
      return _PremiumLoginScreen(
        apiUrl: widget.api.baseUrl,
        mode: mode,
        onRefresh: _bootstrap,
        onLogin: _login,
        onDemo: _continueDemo,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          const _LuxuryBackground(),
          Column(children: [
            _Header(
              mode: mode,
              apiUrl: widget.api.baseUrl,
              user: widget.api.currentUser,
              onLogin: () {},
              onLogout: _logout,
              onRefresh: _bootstrap,
            ),
            Expanded(child: _body()),
            _BottomNav(tab: tab, onChanged: (value) => setState(() => tab = value)),
          ]),
        ]),
      ),
    );
  }

  Widget _body() => switch (tab) {
        DashboardTab.dashboard => _DashboardPage(
            servers: servers,
            selectedIndex: selectedServer,
            loading: loadingServers,
            onSelect: (index) => setState(() => selectedServer = index),
            onControl: _previewControl,
            onOpenFeature: _openFeature,
          ),
        DashboardTab.activity => _ActivityPage(mode: mode, server: current, api: widget.api),
        DashboardTab.security => _SecurityPage(mode: mode, server: current, api: widget.api),
        DashboardTab.about => _AboutPage(mode: mode, api: widget.api, user: widget.api.currentUser, error: error),
      };

  Future<void> _login(String usernameOrEmail, String password) async {
    if (mode != ConnectionMode.connected) {
      if (usernameOrEmail.trim().isEmpty || password.isEmpty) {
        throw Exception('Enter any username/email and password to start demo mode.');
      }
      _startDemoSession(usernameOrEmail.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo login active. Backend/plugin required for real controls.')));
      }
      return;
    }

    await widget.api.login(usernameOrEmail.trim(), password);
    setState(() {
      mode = ConnectionMode.connected;
      tab = DashboardTab.dashboard;
    });
    await _refreshServers();
  }

  void _continueDemo() {
    _startDemoSession('Demo Owner');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo login active. Backend/plugin required for real controls.')));
    }
  }

  void _startDemoSession(String displayName) {
    widget.api.currentUser = EmpUser('demo-owner', displayName.isEmpty ? 'demo' : displayName, 'Demo Owner', 'OWNER');
    setState(() {
      mode = ConnectionMode.offlineDemo;
      tab = DashboardTab.dashboard;
      servers = demoServers;
      selectedServer = 0;
      error = null;
    });
  }

  Future<void> _logout() async {
    await widget.api.logout();
    setState(() {
      servers = demoServers;
      selectedServer = 0;
    });
  }

  void _previewControl(String action) {
    final message = demo ? 'Demo mode: action preview only. Connect backend/plugin to use remote server controls.' : '$action queued through EMP Control backend.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openFeature(String title) {
    if (title == 'Files') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files are disabled in the MVP. No server files are exposed.')));
      return;
    }
    if (title == 'Console' && widget.api.currentUser?.owner != true && mode == ConnectionMode.connected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Console is OWNER-only when auth is active.')));
      return;
    }
    if (title == 'Stats') {
      setState(() => tab = DashboardTab.dashboard);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PlaceholderScreen(title: title, server: current, demo: demo)));
  }
}


class _PremiumLoginScreen extends StatefulWidget {
  const _PremiumLoginScreen({required this.apiUrl, required this.mode, required this.onRefresh, required this.onLogin, required this.onDemo});
  final String apiUrl;
  final ConnectionMode mode;
  final VoidCallback onRefresh;
  final Future<void> Function(String usernameOrEmail, String password) onLogin;
  final VoidCallback onDemo;

  @override
  State<_PremiumLoginScreen> createState() => _PremiumLoginScreenState();
}

class _PremiumLoginScreenState extends State<_PremiumLoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(children: [
            const _LuxuryBackground(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _GlowCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(colors: [_purple, _neon]),
                              boxShadow: [BoxShadow(color: _purple.withOpacity(.62), blurRadius: 34, spreadRadius: 2)],
                            ),
                            child: const Center(child: Text('EMP', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('EMP\nCONTROL', style: TextStyle(fontSize: 34, height: .84, letterSpacing: 2.2, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            const Text('Your Server. Your World.', style: TextStyle(color: _muted, fontSize: 15)),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _StatusPill(text: _Header._modeLabel(widget.mode), color: widget.mode == ConnectionMode.connected ? Colors.greenAccent : _neon),
                              _StatusPill(text: widget.apiUrl, color: _purple, subtle: true),
                            ]),
                          ])),
                          IconButton(onPressed: widget.onRefresh, icon: const Icon(Icons.refresh, color: _softWhite)),
                        ]),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.22),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _purple.withOpacity(.28)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            const Text('Enter Control Panel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            const Text('Demo mode works without backend. Real server control requires backend + plugin.', style: TextStyle(color: _muted, height: 1.35)),
                            const SizedBox(height: 18),
                            TextField(
                              controller: username,
                              decoration: _loginDecoration('Username or Email', Icons.person_rounded),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: password,
                              decoration: _loginDecoration('Password', Icons.lock_rounded),
                              obscureText: true,
                              onSubmitted: (_) => _submit(),
                            ),
                            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
                            const SizedBox(height: 18),
                            FilledButton(
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                              onPressed: busy ? null : _submit,
                              child: Text(busy ? 'Connecting...' : 'Enter Control Panel', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                            TextButton(onPressed: busy ? null : widget.onDemo, child: const Text('Continue in Demo Mode')),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );

  InputDecoration _loginDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _neon),
        filled: true,
        fillColor: Colors.white.withOpacity(.055),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _purple.withOpacity(.25))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _purple.withOpacity(.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _neon, width: 1.4)),
      );

  Future<void> _submit() async {
    setState(() { busy = true; error = null; });
    try {
      await widget.onLogin(username.text, password.text);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mode, required this.apiUrl, required this.user, required this.onLogin, required this.onLogout, required this.onRefresh});
  final ConnectionMode mode;
  final String apiUrl;
  final EmpUser? user;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
        child: _GlowCard(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [_purple, _neon]),
                boxShadow: [BoxShadow(color: _purple.withOpacity(.55), blurRadius: 28, spreadRadius: 2)],
              ),
              child: const Center(child: Text('EMP', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('EMP\nCONTROL', style: TextStyle(fontSize: 26, height: .86, letterSpacing: 1.7, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Your Server. Your World.', style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _StatusPill(text: _modeLabel(mode), color: mode == ConnectionMode.connected ? Colors.greenAccent : _neon),
                _StatusPill(text: apiUrl, color: _purple, subtle: true),
              ]),
            ])),
            Column(children: [
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: _softWhite)),
              FilledButton.tonal(onPressed: user == null ? onLogin : onLogout, child: Text(user == null ? 'Login' : 'Logout')),
            ]),
          ]),
        ),
      );

  static String _modeLabel(ConnectionMode mode) => switch (mode) {
        ConnectionMode.loading => 'CONNECTING',
        ConnectionMode.connected => 'BACKEND CONNECTED',
        ConnectionMode.offlineDemo => 'LOCAL MODE / OFFLINE READY',
        ConnectionMode.error => 'LOCAL DEMO MODE',
      };
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({required this.servers, required this.selectedIndex, required this.loading, required this.onSelect, required this.onControl, required this.onOpenFeature});
  final List<DashboardServer> servers;
  final int selectedIndex;
  final bool loading;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onControl;
  final ValueChanged<String> onOpenFeature;

  @override
  Widget build(BuildContext context) {
    final server = servers[_safeIndex(selectedIndex, servers.length)];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Server Network', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: servers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _ServerChip(server: servers[index], selected: index == selectedIndex, onTap: () => onSelect(index)),
          ),
        ),
        const SizedBox(height: 18),
        _SelectedServerCard(server: server),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _ControlButton(label: 'Start Server', icon: Icons.play_arrow_rounded, onTap: () => onControl('Start Server'))),
          const SizedBox(width: 10),
          Expanded(child: _ControlButton(label: 'Stop Server', icon: Icons.stop_rounded, danger: true, onTap: () => onControl('Stop Server'))),
          const SizedBox(width: 10),
          Expanded(child: _ControlButton(label: 'Restart Server', icon: Icons.restart_alt_rounded, onTap: () => onControl('Restart Server'))),
        ]),
        const SizedBox(height: 20),
        const Text('Control Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 720 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.28,
          children: const [
            _FeatureSpec('Console', Icons.terminal_rounded, 'Owner command center'),
            _FeatureSpec('Players', Icons.groups_rounded, 'Online roster'),
            _FeatureSpec('Plugins', Icons.extension_rounded, 'Plugin insight'),
            _FeatureSpec('Settings', Icons.tune_rounded, 'Server policy'),
            _FeatureSpec('Files', Icons.folder_lock_rounded, 'Disabled in MVP'),
            _FeatureSpec('Stats', Icons.query_stats_rounded, 'Live health'),
          ].map((feature) => _FeatureCard(spec: feature, onTap: () => onOpenFeature(feature.title))).toList(),
        ),
      ]),
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip({required this.server, required this.selected, required this.onTap});
  final DashboardServer server;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 148,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(colors: selected ? [_panel2, const Color(0xFF32135C)] : [_panel, const Color(0xFF14101E)]),
            border: Border.all(color: selected ? _neon : Colors.white10, width: selected ? 1.4 : 1),
            boxShadow: selected ? [BoxShadow(color: _purple.withOpacity(.52), blurRadius: 26, spreadRadius: 1)] : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _OnlineDot(online: server.online),
              const Spacer(),
              Text('${server.playersOnline}/${server.maxPlayers}', style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
            const Spacer(),
            Text(server.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(server.mode, style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        ),
      );
}

class _SelectedServerCard extends StatelessWidget {
  const _SelectedServerCard({required this.server});
  final DashboardServer server;

  @override
  Widget build(BuildContext context) => _GlowCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _StatusPill(text: server.online ? 'SERVER ONLINE' : 'SERVER OFFLINE', color: server.online ? Colors.greenAccent : Colors.redAccent),
            const Spacer(),
            Text('${server.pingMs} ms', style: const TextStyle(color: _muted)),
          ]),
          const SizedBox(height: 16),
          Text(server.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: .5)),
          Text('${server.mode} • ${server.software} • ${server.version}', style: const TextStyle(color: _muted)),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _MetricTile(label: 'Players', value: '${server.playersOnline}/${server.maxPlayers}', icon: Icons.people_alt_rounded),
            _MetricTile(label: 'CPU', value: '${server.cpuPercent}%', icon: Icons.memory_rounded),
            _MetricTile(label: 'RAM', value: '${server.ramPercent}%', icon: Icons.storage_rounded),
            _MetricTile(label: 'TPS', value: server.tps.toStringAsFixed(1), icon: Icons.speed_rounded),
          ]),
        ]),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: (MediaQuery.of(context).size.width - 72) / 2,
        constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.045), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
        child: Row(children: [
          Icon(icon, color: _neon),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: _muted, fontSize: 12))]),
        ]),
      );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.label, required this.icon, required this.onTap, this.danger = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          minHeight: 86,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: danger ? [const Color(0xFF3A1118), const Color(0xFF251018)] : [_purple.withOpacity(.95), _panel2]),
            border: Border.all(color: danger ? Colors.redAccent.withOpacity(.35) : _neon.withOpacity(.5)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]),
        ),
      );
}

class _FeatureSpec {
  const _FeatureSpec(this.title, this.icon, this.subtitle);
  final String title;
  final IconData icon;
  final String subtitle;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.spec, required this.onTap});
  final _FeatureSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _panel.withOpacity(.88), borderRadius: BorderRadius.circular(22), border: Border.all(color: spec.title == 'Files' ? Colors.white10 : _purple.withOpacity(.32))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(spec.icon, color: spec.title == 'Files' ? _muted : _neon, size: 30),
            const Spacer(),
            Text(spec.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(spec.subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        ),
      );
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage({required this.mode, required this.server, required this.api});
  final ConnectionMode mode;
  final DashboardServer server;
  final ApiClient api;

  @override
  Widget build(BuildContext context) => _EventListPage(
        title: 'Activity',
        subtitle: mode == ConnectionMode.connected && api.currentUser != null ? 'Live logs when backend data is available' : 'Mock activity shown in Local Demo Mode',
        events: demoActivity(server),
      );
}

class _SecurityPage extends StatelessWidget {
  const _SecurityPage({required this.mode, required this.server, required this.api});
  final ConnectionMode mode;
  final DashboardServer server;
  final ApiClient api;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Security', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _GlowCard(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SecurityRow(label: 'OP Protection', value: 'Enabled', icon: Icons.verified_user_rounded),
            _SecurityRow(label: 'Dangerous Commands', value: 'Monitoring', icon: Icons.gpp_maybe_rounded),
            _SecurityRow(label: 'Panic Mode', value: 'Ready', icon: Icons.emergency_rounded),
          ])),
          const SizedBox(height: 16),
          _EventListPage(title: 'Recent Security Events', subtitle: mode == ConnectionMode.connected && api.currentUser != null ? 'Backend events will appear here' : 'Demo security events', events: demoSecurity(server), embedded: true),
        ]),
      );
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [Icon(icon, color: _neon), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), _StatusPill(text: value, color: Colors.greenAccent, subtle: true)]),
      );
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.mode, required this.api, required this.user, required this.error});
  final ConnectionMode mode;
  final ApiClient api;
  final EmpUser? user;
  final String? error;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: _GlowCard(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('EMP CONTROL', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Your Server. Your World.', style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
            _InfoLine('API URL', api.baseUrl),
            _InfoLine('Connection Mode', mode == ConnectionMode.connected ? 'Backend Connected' : 'Local Demo Mode'),
            _InfoLine('User Mode', mode == ConnectionMode.connected ? "${user?.role ?? 'Unknown'} Account" : 'Demo Owner'),
            _InfoLine('Remote Controls', mode == ConnectionMode.connected ? 'Backend/plugin required' : 'Preview only'),
            if (error != null) _InfoLine('Last Error', error!),
            const SizedBox(height: 16),
            const Text('Real monitoring/control requires the EMP Control API and EMPControlAgent plugin. The APK opens offline with mock servers so you can preview the dashboard immediately.', style: TextStyle(color: _muted, height: 1.4)),
          ]),
        ),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 135, child: Text(label, style: const TextStyle(color: _muted))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)))]),
      );
}

class _EventListPage extends StatelessWidget {
  const _EventListPage({required this.title, required this.subtitle, required this.events, this.embedded = false});
  final String title;
  final String subtitle;
  final List<String> events;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: embedded ? 20 : 26, fontWeight: FontWeight.w900)),
      Text(subtitle, style: const TextStyle(color: _muted)),
      const SizedBox(height: 14),
      ...events.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GlowCard(subtle: true, padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.bolt_rounded, color: _neon), const SizedBox(width: 12), Expanded(child: Text(event))])),
          )),
    ]);
    return embedded ? content : SingleChildScrollView(padding: const EdgeInsets.all(18), child: content);
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onChanged});
  final DashboardTab tab;
  final ValueChanged<DashboardTab> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _panel.withOpacity(.94), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white10)),
        child: Row(children: DashboardTab.values.map((item) {
          final selected = item == tab;
          return Expanded(child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onChanged(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: selected ? _purple.withOpacity(.35) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(_tabIcon(item), color: selected ? _neon : _muted), const SizedBox(height: 3), Text(_tabLabel(item), style: TextStyle(color: selected ? _softWhite : _muted, fontSize: 11, fontWeight: FontWeight.w700))]),
            ),
          ));
        }).toList()),
      );

  static IconData _tabIcon(DashboardTab tab) => switch (tab) { DashboardTab.dashboard => Icons.dashboard_rounded, DashboardTab.activity => Icons.receipt_long_rounded, DashboardTab.security => Icons.shield_rounded, DashboardTab.about => Icons.info_rounded };
  static String _tabLabel(DashboardTab tab) => switch (tab) { DashboardTab.dashboard => 'Dashboard', DashboardTab.activity => 'Activity', DashboardTab.security => 'Security', DashboardTab.about => 'About' };
}

class _GlowCard extends StatelessWidget {
  const _GlowCard({required this.child, required this.padding, this.subtle = false});
  final Widget child;
  final EdgeInsets padding;
  final bool subtle;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_panel, _panel2]),
          border: Border.all(color: subtle ? Colors.white10 : _purple.withOpacity(.36)),
          boxShadow: subtle ? null : [BoxShadow(color: _purple.withOpacity(.28), blurRadius: 34, spreadRadius: 1)],
        ),
        child: child,
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color, this.subtle = false});
  final String text;
  final Color color;
  final bool subtle;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(subtle ? .10 : .16), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.42))),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      );
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: online ? Colors.greenAccent : Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (online ? Colors.greenAccent : Colors.redAccent).withOpacity(.7), blurRadius: 10)]));
}

class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground();
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          radialGradient: RadialGradient(center: Alignment(-.8, -.9), radius: 1.2, colors: [Color(0xFF2C0E55), _black]),
        ),
      );
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.server, required this.demo});
  final String title;
  final DashboardServer server;
  final bool demo;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(children: [
            const _LuxuryBackground(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                const SizedBox(height: 16),
                _GlowCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('${server.name} • ${demo ? 'Local Demo Mode' : 'Backend Connected'}', style: const TextStyle(color: _muted)),
                    const SizedBox(height: 16),
                    const Text(
                      'This premium placeholder keeps the MVP safe while backend/plugin integrations are connected. No server files or unsafe actions are exposed.',
                      style: TextStyle(color: _muted, height: 1.4),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
}

class DashboardServer {
  const DashboardServer({required this.name, required this.mode, required this.online, required this.playersOnline, required this.maxPlayers, required this.cpuPercent, required this.ramPercent, required this.pingMs, required this.tps, required this.version, required this.software});
  final String name;
  final String mode;
  final bool online;
  final int playersOnline;
  final int maxPlayers;
  final int cpuPercent;
  final int ramPercent;
  final int pingMs;
  final double tps;
  final String version;
  final String software;

  factory DashboardServer.fromEmpServer(EmpServer server) {
    final snapshot = server.snapshot ?? <String, dynamic>{};
    final health = (snapshot['health'] as Map?) ?? <String, dynamic>{};
    final performance = (snapshot['performance'] as Map?) ?? <String, dynamic>{};
    final players = (snapshot['players'] as Map?) ?? <String, dynamic>{};
    final network = (snapshot['network'] as Map?) ?? <String, dynamic>{};
    return DashboardServer(
      name: server.displayName,
      mode: 'Linked Server',
      online: server.status == 'ONLINE',
      playersOnline: _int(players['online'], 0),
      maxPlayers: _int(players['max'], 0),
      cpuPercent: _int(performance['cpuUsage'], 0),
      ramPercent: _int(performance['ramPercentage'], 0),
      pingMs: _int(network['webSocketLatency'], 0),
      tps: _double(health['tps1m'], 20),
      version: '${health['serverVersion'] ?? 'Unknown'}',
      software: '${health['paperVersion'] ?? 'Paper'}',
    );
  }
}

const demoServers = [
  DashboardServer(name: 'Lobby', mode: 'Hub', online: true, playersOnline: 42, maxPlayers: 250, cpuPercent: 18, ramPercent: 41, pingMs: 24, tps: 20.0, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'Survival', mode: 'Survival', online: true, playersOnline: 18, maxPlayers: 80, cpuPercent: 33, ramPercent: 64, pingMs: 31, tps: 19.8, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'BoxPvP', mode: 'PvP', online: true, playersOnline: 12, maxPlayers: 120, cpuPercent: 24, ramPercent: 52, pingMs: 28, tps: 19.9, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'Lifesteal', mode: 'Hardcore', online: false, playersOnline: 0, maxPlayers: 100, cpuPercent: 0, ramPercent: 0, pingMs: 0, tps: 0, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'SkyBlock', mode: 'Islands', online: true, playersOnline: 27, maxPlayers: 150, cpuPercent: 29, ramPercent: 58, pingMs: 36, tps: 19.7, version: '1.20.4', software: 'Paper'),
];

List<String> demoActivity(DashboardServer server) => [
  '${server.name}: heartbeat received 12s ago',
  '${server.name}: metrics snapshot cached locally',
  'Player count updated to ${server.playersOnline}/${server.maxPlayers}',
  'Demo mode: backend/plugin controls are preview only',
];

List<String> demoSecurity(DashboardServer server) => [
  '${server.name}: OP protection enabled',
  'Dangerous command monitor ready',
  'No unauthorized OP changes detected in demo data',
];

int _safeIndex(int index, int length) => length <= 0 ? 0 : index.clamp(0, length - 1).toInt();
int _int(dynamic value, int fallback) => value is num ? value.round() : fallback;
double _double(dynamic value, double fallback) => value is num ? value.toDouble() : fallback;
