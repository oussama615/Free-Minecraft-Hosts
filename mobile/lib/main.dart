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
const _success = Color(0xFF55FFB7);
const _danger = Color(0xFFFF5C8A);

enum ConnectionMode { loading, connected, localPreview }
enum DashboardTab { dashboard, activity, logs, security, about }
enum LogFilter { all, players, commands, security, server }

class PermissionKey {
  static const viewDashboard = 'view_dashboard';
  static const viewServerList = 'view_server_list';
  static const viewServerDetails = 'view_server_details';
  static const viewLiveStats = 'view_live_stats';
  static const viewActivity = 'view_activity';
  static const viewLogs = 'view_logs';
  static const viewSecurity = 'view_security';
  static const viewConsole = 'view_console';
  static const sendConsoleCommands = 'send_console_commands';
  static const useQuickCommands = 'use_quick_commands';
  static const executeStart = 'execute_start';
  static const executeStop = 'execute_stop';
  static const executeRestart = 'execute_restart';
  static const viewUsers = 'view_users';
  static const createUsers = 'create_users';
  static const editUsers = 'edit_users';
  static const deleteUsers = 'delete_users';
  static const manageRoles = 'manage_roles';
  static const managePermissions = 'manage_permissions';
  static const viewSettings = 'view_settings';
  static const editSettings = 'edit_settings';
  static const manageServerSettings = 'manage_server_settings';
  static const viewPlugins = 'view_plugins';
  static const managePlugins = 'manage_plugins';
  static const viewFiles = 'view_files';
  static const manageFiles = 'manage_files';
  static const backupManagement = 'backup_management';
  static const viewAlerts = 'view_alerts';
  static const manageAlerts = 'manage_alerts';
  static const viewAuditTrail = 'view_audit_trail';
  static const accessOwnerFeatures = 'access_owner_features';
}

const permissionGroups = <String, List<String>>{
  'Dashboard': [PermissionKey.viewDashboard, PermissionKey.viewServerList, PermissionKey.viewServerDetails, PermissionKey.viewLiveStats],
  'Activity / Logs / Security': [PermissionKey.viewActivity, PermissionKey.viewLogs, PermissionKey.viewSecurity],
  'Console / Commands': [PermissionKey.viewConsole, PermissionKey.sendConsoleCommands, PermissionKey.useQuickCommands, PermissionKey.executeStart, PermissionKey.executeStop, PermissionKey.executeRestart],
  'Users / Access': [PermissionKey.viewUsers, PermissionKey.createUsers, PermissionKey.editUsers, PermissionKey.deleteUsers, PermissionKey.manageRoles, PermissionKey.managePermissions],
  'Settings': [PermissionKey.viewSettings, PermissionKey.editSettings, PermissionKey.manageServerSettings],
  'Plugins / Files': [PermissionKey.viewPlugins, PermissionKey.managePlugins, PermissionKey.viewFiles, PermissionKey.manageFiles, PermissionKey.backupManagement],
  'Alerts / Monitoring': [PermissionKey.viewAlerts, PermissionKey.manageAlerts],
  'Audit / Owner': [PermissionKey.viewAuditTrail, PermissionKey.accessOwnerFeatures],
};

final allPermissions = permissionGroups.values.expand((items) => items).toSet();
final rolePresets = <String, Set<String>>{
  'Owner': allPermissions,
  'Admin': allPermissions.difference({PermissionKey.deleteUsers, PermissionKey.accessOwnerFeatures, PermissionKey.manageFiles}),
  'Moderator': {
    PermissionKey.viewDashboard,
    PermissionKey.viewServerList,
    PermissionKey.viewServerDetails,
    PermissionKey.viewLiveStats,
    PermissionKey.viewActivity,
    PermissionKey.viewLogs,
    PermissionKey.viewSecurity,
    PermissionKey.viewConsole,
    PermissionKey.sendConsoleCommands,
    PermissionKey.useQuickCommands,
  },
  'Viewer': {PermissionKey.viewDashboard, PermissionKey.viewServerList, PermissionKey.viewServerDetails, PermissionKey.viewLiveStats, PermissionKey.viewLogs},
  'Custom': <String>{},
};


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
          textTheme: ThemeData.dark().textTheme.apply(bodyColor: _softWhite, displayColor: _softWhite),
          snackBarTheme: const SnackBarThemeData(backgroundColor: _panel2, contentTextStyle: TextStyle(color: _softWhite)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withOpacity(.055),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _purple.withOpacity(.25))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _purple.withOpacity(.25))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _neon, width: 1.4)),
          ),
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
  List<AppAccount> users = demoUsers;
  List<ActivityRecord> activities = demoActivities;
  List<ServerLogRecord> logs = demoLogs;
  int selectedServer = 0;
  Set<String> permissions = {...allPermissions};
  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    setState(() => mode = ConnectionMode.loading);
    final online = await widget.api.healthCheck();
    if (!mounted) return;
    setState(() => mode = online ? ConnectionMode.connected : ConnectionMode.localPreview);
  }

  bool can(String permission) => permissions.contains(permission);
  bool get previewMode => mode != ConnectionMode.connected || widget.api.currentUser?.id == 'preview-owner';
  DashboardServer get currentServer => servers[_safeIndex(selectedServer, servers.length)];

  List<DashboardTab> get visibleTabs => [
        DashboardTab.dashboard,
        if (can(PermissionKey.viewActivity)) DashboardTab.activity,
        if (can(PermissionKey.viewLogs)) DashboardTab.logs,
        if (can(PermissionKey.viewSecurity)) DashboardTab.security,
        DashboardTab.about,
      ];

  @override
  Widget build(BuildContext context) {
    if (widget.api.currentUser == null) {
      return _PremiumLoginScreen(onLogin: _login, loading: mode == ConnectionMode.loading);
    }
    final tabs = visibleTabs;
    if (!tabs.contains(tab)) tab = DashboardTab.dashboard;
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          const _LuxuryBackground(),
          Column(children: [
            _Header(user: widget.api.currentUser!, onRefresh: _checkBackend, onLogout: _logout),
            Expanded(child: _body()),
            _BottomNav(tab: tab, tabs: tabs, onChanged: _changeTab),
          ]),
        ]),
      ),
    );
  }

  Widget _body() => switch (tab) {
        DashboardTab.dashboard => _DashboardPage(
            servers: servers,
            selectedIndex: selectedServer,
            permissions: permissions,
            onSelect: (index) => setState(() => selectedServer = index),
            onControl: _controlAction,
            onOpenFeature: _openFeature,
          ),
        DashboardTab.activity => _ActivityPage(records: activities),
        DashboardTab.logs => _LogsPage(logs: logs),
        DashboardTab.security => _SecurityPage(server: currentServer, events: demoSecurityEvents),
        DashboardTab.about => _AboutPage(mode: mode, user: widget.api.currentUser!, previewMode: previewMode),
      };

  Future<void> _login(String usernameOrEmail, String password) async {
    final name = usernameOrEmail.trim();
    if (name.isEmpty || password.isEmpty) {
      throw Exception('Enter your username/email and password.');
    }

    widget.api.currentUser = EmpUser('preview-owner', name, 'Owner', 'OWNER');
    _setOwnerPermissions();
    setState(() {
      tab = DashboardTab.dashboard;
      servers = demoServers;
      selectedServer = 0;
    });
    _recordActivity('User logged in', 'EMP Control');

    if (mode == ConnectionMode.connected) {
      _attemptBackendLogin(name, password);
    } else {
      setState(() => mode = ConnectionMode.localPreview);
    }
  }

  Future<void> _attemptBackendLogin(String usernameOrEmail, String password) async {
    try {
      await widget.api.login(usernameOrEmail, password);
      if (!mounted) return;
      _setOwnerPermissions();
      _recordActivity('Backend session verified', 'EMP Control API');
      await _loadRealServers();
    } catch (_) {
      if (!mounted) return;
      setState(() => mode = ConnectionMode.localPreview);
    }
  }

  Future<void> _loadRealServers() async {
    try {
      final realServers = await widget.api.servers();
      if (!mounted) return;
      setState(() {
        servers = realServers.isEmpty ? demoServers : realServers.map(DashboardServer.fromEmpServer).toList();
        selectedServer = 0;
        tab = DashboardTab.dashboard;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => servers = demoServers);
    }
  }

  void _setOwnerPermissions() => setState(() => permissions = {...allPermissions});

  Future<void> _logout() async {
    await widget.api.logout();
    setState(() {
      tab = DashboardTab.dashboard;
      servers = demoServers;
      selectedServer = 0;
      permissions = {...allPermissions};
    });
  }

  void _recordActivity(String action, String target) {
    final actor = widget.api.currentUser?.displayName ?? widget.api.currentUser?.username ?? 'User';
    setState(() => activities = [ActivityRecord(actor: actor, action: action, target: target, time: 'now'), ...activities].take(30).toList());
  }

  void _changeTab(DashboardTab value) {
    setState(() => tab = value);
    final label = switch (value) {
      DashboardTab.dashboard => 'dashboard',
      DashboardTab.activity => 'activity',
      DashboardTab.logs => 'logs',
      DashboardTab.security => 'security',
      DashboardTab.about => 'about',
    };
    _recordActivity('Opened $label', 'Navigation');
  }

  void _controlAction(String action, String permission) {
    if (!can(permission)) {
      _toast('$action is disabled for your role.');
      return;
    }
    _recordActivity('$action requested', currentServer.name);
    _toast(previewMode ? 'Connect backend and plugin for live control.' : '$action sent to backend.');
  }

  void _openFeature(String title) {
    _recordActivity('Opened $title', currentServer.name);
    if (title == 'Console') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => _ConsoleScreen(server: currentServer, canSend: can(PermissionKey.sendConsoleCommands), previewMode: previewMode, onCommand: (command) {
        _recordActivity('Sent command', command);
        setState(() => logs = [ServerLogRecord(time: 'now', type: 'Commands', actor: widget.api.currentUser?.displayName ?? 'User', message: command), ...logs]);
      })));
      return;
    }
    if (title == 'Users & Roles') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => _UsersPermissionsScreen(users: users, permissions: permissions, onChanged: (updatedUsers, updatedPermissions) {
        setState(() {
          users = updatedUsers;
          permissions = updatedPermissions;
        });
        _recordActivity('Edited permissions', 'Users & Roles');
      })));
      return;
    }
    if (title == 'Stats') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => _StatsScreen(server: currentServer)));
      return;
    }
    if (title == 'Files') {
      _toast('Files are not enabled in this MVP.');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PremiumDetailScreen(title: title, server: currentServer)));
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _PremiumLoginScreen extends StatefulWidget {
  const _PremiumLoginScreen({required this.onLogin, required this.loading});
  final Future<void> Function(String usernameOrEmail, String password) onLogin;
  final bool loading;

  @override
  State<_PremiumLoginScreen> createState() => _PremiumLoginScreenState();
}

class _PremiumLoginScreenState extends State<_PremiumLoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(children: [
            const _LuxuryBackground(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _GlowCard(
                    padding: const EdgeInsets.all(26),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                        BrandMark(size: 70),
                        SizedBox(width: 18),
                        Flexible(child: Text('EMP Control', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 34, letterSpacing: 1.1, fontWeight: FontWeight.w900))),
                      ]),
                      const SizedBox(height: 12),
                      const Center(child: Text('Your Server. Your World.', style: TextStyle(color: _muted, fontSize: 16))),
                      const SizedBox(height: 26),
                      const Text('Sign in to access your control panel.', textAlign: TextAlign.center, style: TextStyle(color: _softWhite, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      TextField(controller: username, decoration: const InputDecoration(labelText: 'Username or Email', prefixIcon: Icon(Icons.person_rounded))),
                      const SizedBox(height: 14),
                      TextField(controller: password, obscureText: true, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_rounded))),
                      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: _danger))),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        onPressed: busy ? null : _submit,
                        child: Text(busy || widget.loading ? 'Opening...' : 'Enter Control Panel', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );

  Future<void> _submit() async {
    setState(() { busy = true; error = null; });
    try {
      await widget.onLogin(username.text, password.text);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onRefresh, required this.onLogout});
  final EmpUser user;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Row(children: [
          const BrandMark(size: 52),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('EMP Control', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 24, letterSpacing: .8, fontWeight: FontWeight.w900)),
            Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: _softWhite)),
          IconButton(onPressed: onLogout, icon: const Icon(Icons.logout_rounded, color: _softWhite)),
        ]),
      );
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({required this.servers, required this.selectedIndex, required this.permissions, required this.onSelect, required this.onControl, required this.onOpenFeature});
  final List<DashboardServer> servers;
  final int selectedIndex;
  final Set<String> permissions;
  final ValueChanged<int> onSelect;
  final void Function(String action, String permission) onControl;
  final ValueChanged<String> onOpenFeature;

  bool can(String permission) => permissions.contains(permission);

  @override
  Widget build(BuildContext context) {
    final server = servers[_safeIndex(selectedIndex, servers.length)];
    final actions = [
      _ActionSpec('Start', Icons.play_arrow_rounded, PermissionKey.executeStart, false),
      _ActionSpec('Stop', Icons.stop_rounded, PermissionKey.executeStop, true),
      _ActionSpec('Restart', Icons.restart_alt_rounded, PermissionKey.executeRestart, false),
    ];
    final features = [
      _FeatureSpec('Console', Icons.terminal_rounded, 'Command center', PermissionKey.viewConsole),
      _FeatureSpec('Players', Icons.groups_rounded, 'Player roster', PermissionKey.viewServerDetails),
      _FeatureSpec('Plugins', Icons.extension_rounded, 'Plugin status', PermissionKey.viewPlugins),
      _FeatureSpec('Settings', Icons.tune_rounded, 'Server settings', PermissionKey.viewSettings),
      _FeatureSpec('Users & Roles', Icons.admin_panel_settings_rounded, 'Access control', PermissionKey.viewUsers),
      _FeatureSpec('Stats', Icons.query_stats_rounded, 'Live metrics', PermissionKey.viewLiveStats),
    ].where((feature) => can(feature.permission)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Servers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
        Row(children: actions.map((action) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _ControlButton(spec: action, enabled: can(action.permission), onTap: () => onControl(action.label, action.permission)),
        ))).toList()),
        const SizedBox(height: 20),
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 720 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: features.map((feature) => _FeatureCard(spec: feature, onTap: () => onOpenFeature(feature.title))).toList(),
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
            Row(children: [_OnlineDot(online: server.online), const Spacer(), Text('${server.playersOnline}/${server.maxPlayers}', style: const TextStyle(color: _muted, fontSize: 12))]),
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
          Row(children: [_StatusPill(text: server.online ? 'Online' : 'Offline', color: server.online ? _success : _danger), const Spacer(), Text('${server.pingMs} ms', style: const TextStyle(color: _muted))]),
          const SizedBox(height: 14),
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
        child: Row(children: [Icon(icon, color: _neon), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: _muted, fontSize: 12))])]),
      );
}

class _ActionSpec {
  const _ActionSpec(this.label, this.icon, this.permission, this.danger);
  final String label;
  final IconData icon;
  final String permission;
  final bool danger;
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.spec, required this.enabled, required this.onTap});
  final _ActionSpec spec;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : .42,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 86),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: spec.danger ? [const Color(0xFF3A1118), const Color(0xFF251018)] : [_purple.withOpacity(.95), _panel2]),
              border: Border.all(color: spec.danger ? _danger.withOpacity(.35) : _neon.withOpacity(.5)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(spec.icon, color: Colors.white), const SizedBox(height: 6), Text(spec.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]),
          ),
        ),
      );
}

class _FeatureSpec {
  const _FeatureSpec(this.title, this.icon, this.subtitle, this.permission);
  final String title;
  final IconData icon;
  final String subtitle;
  final String permission;
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
          decoration: BoxDecoration(color: _panel.withOpacity(.88), borderRadius: BorderRadius.circular(22), border: Border.all(color: _purple.withOpacity(.32))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(spec.icon, color: _neon, size: 30), const Spacer(), Text(spec.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(spec.subtitle, style: const TextStyle(color: _muted, fontSize: 12))]),
        ),
      );
}

class _ConsoleScreen extends StatefulWidget {
  const _ConsoleScreen({required this.server, required this.canSend, required this.previewMode, required this.onCommand});
  final DashboardServer server;
  final bool canSend;
  final bool previewMode;
  final ValueChanged<String> onCommand;

  @override
  State<_ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<_ConsoleScreen> {
  final input = TextEditingController();
  late List<String> output;
  final quick = ['/say', '/list', '/stop', '/restart', '/plugins'];

  @override
  void initState() {
    super.initState();
    output = [
      '[12:00:01 INFO]: Connected to ${widget.server.name} console view',
      '[12:00:02 INFO]: Type a command or use quick commands below',
    ];
  }

  void _send([String? value]) {
    final command = (value ?? input.text).trim();
    if (command.isEmpty) return;
    if (!widget.canSend) {
      setState(() => output.add('[DENIED]: Your role can view console but cannot send commands.'));
      return;
    }
    setState(() {
      output.add('> $command');
      output.add(widget.previewMode ? '[LOCAL]: $command staged for ${widget.server.name}' : '[SENT]: $command');
      input.clear();
    });
    widget.onCommand(command);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Stack(children: [
          const _LuxuryBackground(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _BackTitle(title: 'Console', subtitle: widget.server.name),
              const SizedBox(height: 12),
              Expanded(child: _GlowCard(
                padding: const EdgeInsets.all(14),
                child: ListView.builder(itemCount: output.length, itemBuilder: (_, index) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(output[index], style: const TextStyle(fontFamily: 'monospace', color: _softWhite))))),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: quick.map((command) => ActionChip(label: Text(command), onPressed: widget.canSend ? () => _send(command) : null)).toList()),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: TextField(controller: input, enabled: widget.canSend, onSubmitted: (value) => _send(value), decoration: InputDecoration(labelText: widget.canSend ? 'Command' : 'Sending disabled for this role'))), const SizedBox(width: 10), FilledButton(onPressed: widget.canSend ? () => _send() : null, child: const Text('Send'))]),
            ]),
          ),
        ])),
      );
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage({required this.records});
  final List<ActivityRecord> records;
  @override
  Widget build(BuildContext context) => _RecordsPage(title: 'Activity', subtitle: 'Control panel actions by users and admins', children: records.map((record) => _ActivityCard(record: record)).toList());
}

class _LogsPage extends StatefulWidget {
  const _LogsPage({required this.logs});
  final List<ServerLogRecord> logs;
  @override
  State<_LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<_LogsPage> {
  LogFilter filter = LogFilter.all;
  @override
  Widget build(BuildContext context) {
    final filtered = widget.logs.where((log) => filter == LogFilter.all || log.type.toLowerCase() == filter.name).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Logs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Server, player, command, security and system records', style: TextStyle(color: _muted)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: LogFilter.values.map((item) => ChoiceChip(label: Text(_filterLabel(item)), selected: filter == item, onSelected: (_) => setState(() => filter = item))).toList()),
        const SizedBox(height: 14),
        ...filtered.map((log) => _LogCard(log: log)),
      ]),
    );
  }

  String _filterLabel(LogFilter value) => switch (value) { LogFilter.all => 'All', LogFilter.players => 'Players', LogFilter.commands => 'Commands', LogFilter.security => 'Security', LogFilter.server => 'Server' };
}

class _SecurityPage extends StatelessWidget {
  const _SecurityPage({required this.server, required this.events});
  final DashboardServer server;
  final List<String> events;
  @override
  Widget build(BuildContext context) => _RecordsPage(title: 'Security', subtitle: '${server.name} protection status', children: [
        const _SecurityRow(label: 'OP Protection', value: 'Enabled', icon: Icons.verified_user_rounded),
        const _SecurityRow(label: 'Dangerous Commands', value: 'Monitoring', icon: Icons.gpp_maybe_rounded),
        const _SecurityRow(label: 'Panic Mode', value: 'Ready', icon: Icons.emergency_rounded),
        const SizedBox(height: 10),
        ...events.map((event) => _GlowCard(subtle: true, padding: const EdgeInsets.all(14), child: Text(event))),
      ]);
}

class _StatsScreen extends StatelessWidget {
  const _StatsScreen({required this.server});
  final DashboardServer server;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(children: [
            const _LuxuryBackground(),
            SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _BackTitle(title: 'Stats', subtitle: server.name),
                const SizedBox(height: 16),
                _SelectedServerCard(server: server),
                const SizedBox(height: 16),
                _GlowCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Live Metrics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    _InfoLine('Players', '${server.playersOnline}/${server.maxPlayers}'),
                    _InfoLine('CPU', '${server.cpuPercent}%'),
                    _InfoLine('RAM', '${server.ramPercent}%'),
                    _InfoLine('TPS', server.tps.toStringAsFixed(1)),
                    _InfoLine('Ping', '${server.pingMs} ms'),
                    _InfoLine('Software', '${server.software} ${server.version}'),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
}

class _UsersPermissionsScreen extends StatefulWidget {
  const _UsersPermissionsScreen({required this.users, required this.permissions, required this.onChanged});
  final List<AppAccount> users;
  final Set<String> permissions;
  final void Function(List<AppAccount> users, Set<String> permissions) onChanged;

  @override
  State<_UsersPermissionsScreen> createState() => _UsersPermissionsScreenState();
}

class _UsersPermissionsScreenState extends State<_UsersPermissionsScreen> {
  late List<AppAccount> users;
  late Set<String> permissions;

  @override
  void initState() {
    super.initState();
    users = widget.users.map((user) => user.copy()).toList();
    permissions = {...widget.permissions};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Stack(children: [
          const _LuxuryBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _BackTitle(title: 'Users & Roles', subtitle: 'Roles, presets and fine-grained permissions'),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: FilledButton.icon(onPressed: _createUser, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Create User'))), const SizedBox(width: 10), FilledButton.tonal(onPressed: _save, child: const Text('Save'))]),
              const SizedBox(height: 16),
              ...users.map((user) => _UserCard(user: user, onEdit: () => _editUser(user), onDelete: () => setState(() => users.remove(user)))),
              const SizedBox(height: 16),
              ...permissionGroups.entries.map((entry) => _PermissionGroup(title: entry.key, permissions: entry.value, enabled: permissions, onToggle: (permission) => setState(() => permissions.contains(permission) ? permissions.remove(permission) : permissions.add(permission)))),
            ]),
          ),
        ])),
      );

  void _save() {
    widget.onChanged(users, permissions);
    Navigator.pop(context);
  }

  void _createUser() => _showUserSheet(AppAccount(name: 'New User', email: 'new@example.com', role: 'Viewer'));
  void _editUser(AppAccount user) => _showUserSheet(user);

  void _showUserSheet(AppAccount account) {
    final name = TextEditingController(text: account.name);
    final email = TextEditingController(text: account.email);
    String role = account.role;
    showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => StatefulBuilder(builder: (context, setSheet) => Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: _panel, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('User Access', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')),
        const SizedBox(height: 10),
        TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: rolePresets.keys.map((preset) => ChoiceChip(label: Text(preset), selected: role == preset, onSelected: (_) => setSheet(() => role = preset))).toList()),
        const SizedBox(height: 16),
        FilledButton(onPressed: () { setState(() { account.name = name.text.trim().isEmpty ? account.name : name.text.trim(); account.email = email.text.trim().isEmpty ? account.email : email.text.trim(); account.role = role; if (!users.contains(account)) users.add(account); if (rolePresets[role]!.isNotEmpty) permissions = {...rolePresets[role]!}; }); Navigator.pop(context); }, child: const Text('Apply')),
      ]),
    )));
  }
}

class _PermissionGroup extends StatelessWidget {
  const _PermissionGroup({required this.title, required this.permissions, required this.enabled, required this.onToggle});
  final String title;
  final List<String> permissions;
  final Set<String> enabled;
  final ValueChanged<String> onToggle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _GlowCard(subtle: true, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: permissions.map((permission) => FilterChip(label: Text(permission), selected: enabled.contains(permission), onSelected: (_) => onToggle(permission))).toList()),
        ])),
      );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onEdit, required this.onDelete});
  final AppAccount user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _GlowCard(subtle: true, padding: const EdgeInsets.all(14), child: Row(children: [
          const BrandMark(size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900)), Text(user.email, style: const TextStyle(color: _muted, fontSize: 12))])),
          _StatusPill(text: user.role, color: _neon, subtle: true),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: _danger)),
        ])),
      );
}

class _RecordsPage extends StatelessWidget {
  const _RecordsPage({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: _muted)), const SizedBox(height: 14), ...children]));
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.record});
  final ActivityRecord record;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _GlowCard(subtle: true, padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.bolt_rounded, color: _neon), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(record.action, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${record.actor} • ${record.target}', style: const TextStyle(color: _muted, fontSize: 12))])), Text(record.time, style: const TextStyle(color: _muted, fontSize: 12))])));
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final ServerLogRecord log;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _GlowCard(subtle: true, padding: const EdgeInsets.all(14), child: Row(children: [Icon(_logIcon(log.type), color: _neon), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(log.message, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${log.time} • ${log.type}${log.actor == null ? '' : ' • ${log.actor}'}', style: const TextStyle(color: _muted, fontSize: 12))]))])));
  IconData _logIcon(String type) => switch (type) { 'Players' => Icons.person_rounded, 'Commands' => Icons.terminal_rounded, 'Security' => Icons.shield_rounded, _ => Icons.dns_rounded };
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _GlowCard(subtle: true, padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon, color: _neon), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))), _StatusPill(text: value, color: _success, subtle: true)])));
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.mode, required this.user, required this.previewMode});
  final ConnectionMode mode;
  final EmpUser user;
  final bool previewMode;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: _GlowCard(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EMP Control', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Your Server. Your World.', style: TextStyle(color: _muted)),
          const SizedBox(height: 18),
          _InfoLine('Connection', mode == ConnectionMode.connected && !previewMode ? 'Backend Connected' : 'Local Preview'),
          _InfoLine('User', '${user.displayName} • ${user.role}'),
          _InfoLine('Permissions', previewMode ? 'MVP preview permissions' : 'Backend account permissions'),
          const SizedBox(height: 14),
          const Text('Real server control requires the EMP Control API and EMPControlAgent plugin. Permissions shown in the app are UI/MVP preview until backend enforcement is connected.', style: TextStyle(color: _muted, height: 1.4)),
        ])),
      );
}

class _PremiumDetailScreen extends StatelessWidget {
  const _PremiumDetailScreen({required this.title, required this.server});
  final String title;
  final DashboardServer server;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              const _LuxuryBackground(),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackTitle(title: title, subtitle: server.name),
                    const SizedBox(height: 18),
                    _GlowCard(
                      padding: const EdgeInsets.all(18),
                      child: const Text(
                        'This section is ready for backend data and remains safe for MVP preview.',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _BackTitle extends StatelessWidget {
  const _BackTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(children: [IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: _muted))]))]);
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 115, child: Text(label, style: const TextStyle(color: _muted))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)))]));
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.tabs, required this.onChanged});
  final DashboardTab tab;
  final List<DashboardTab> tabs;
  final ValueChanged<DashboardTab> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _panel.withOpacity(.94), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white10)),
        child: Row(children: tabs.map((item) {
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

  IconData _tabIcon(DashboardTab tab) => switch (tab) { DashboardTab.dashboard => Icons.dashboard_rounded, DashboardTab.activity => Icons.receipt_long_rounded, DashboardTab.logs => Icons.list_alt_rounded, DashboardTab.security => Icons.shield_rounded, DashboardTab.about => Icons.info_rounded };
  String _tabLabel(DashboardTab tab) => switch (tab) { DashboardTab.dashboard => 'Dashboard', DashboardTab.activity => 'Activity', DashboardTab.logs => 'Logs', DashboardTab.security => 'Security', DashboardTab.about => 'About' };
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .32), gradient: const LinearGradient(colors: [_purple, _neon]), boxShadow: [BoxShadow(color: _purple.withOpacity(.58), blurRadius: size * .45, spreadRadius: 1)]),
        child: Center(child: Text('EMP', style: TextStyle(color: Colors.white, fontSize: size * .25, fontWeight: FontWeight.w900, letterSpacing: .8))),
      );
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
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(subtle ? .10 : .16), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.42))), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)));
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: online ? _success : _danger, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (online ? _success : _danger).withOpacity(.7), blurRadius: 10)]));
}

class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground();
  @override
  Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(-.8, -.9), radius: 1.2, colors: [Color(0xFF2C0E55), _black])));
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
    return DashboardServer(name: server.displayName, mode: 'Linked Server', online: server.status == 'ONLINE', playersOnline: _int(players['online'], 0), maxPlayers: _int(players['max'], 0), cpuPercent: _int(performance['cpuUsage'], 0), ramPercent: _int(performance['ramPercentage'], 0), pingMs: _int(network['webSocketLatency'], 0), tps: _double(health['tps1m'], 20), version: '${health['serverVersion'] ?? 'Unknown'}', software: '${health['paperVersion'] ?? 'Paper'}');
  }
}

class ActivityRecord {
  const ActivityRecord({required this.actor, required this.action, required this.target, required this.time});
  final String actor;
  final String action;
  final String target;
  final String time;
}

class ServerLogRecord {
  const ServerLogRecord({required this.time, required this.type, this.actor, required this.message});
  final String time;
  final String type;
  final String? actor;
  final String message;
}

class AppAccount {
  AppAccount({required this.name, required this.email, required this.role});
  String name;
  String email;
  String role;
  AppAccount copy() => AppAccount(name: name, email: email, role: role);
}

const demoServers = [
  DashboardServer(name: 'Lobby', mode: 'Hub', online: true, playersOnline: 42, maxPlayers: 250, cpuPercent: 18, ramPercent: 41, pingMs: 24, tps: 20.0, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'Survival', mode: 'Survival', online: true, playersOnline: 18, maxPlayers: 80, cpuPercent: 33, ramPercent: 64, pingMs: 31, tps: 19.8, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'BoxPvP', mode: 'PvP', online: true, playersOnline: 12, maxPlayers: 120, cpuPercent: 24, ramPercent: 52, pingMs: 28, tps: 19.9, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'Lifesteal', mode: 'Hardcore', online: false, playersOnline: 0, maxPlayers: 100, cpuPercent: 0, ramPercent: 0, pingMs: 0, tps: 0, version: '1.20.4', software: 'Paper'),
  DashboardServer(name: 'SkyBlock', mode: 'Islands', online: true, playersOnline: 27, maxPlayers: 150, cpuPercent: 29, ramPercent: 58, pingMs: 36, tps: 19.7, version: '1.20.4', software: 'Paper'),
];

final demoUsers = [AppAccount(name: 'xk7', email: 'owner@example.com', role: 'Owner'), AppAccount(name: 'Ari', email: 'ari@example.com', role: 'Admin'), AppAccount(name: 'Mina', email: 'mina@example.com', role: 'Moderator')];
const demoActivities = [
  ActivityRecord(actor: 'xk7', action: 'Opened dashboard', target: 'Network', time: '1m'),
  ActivityRecord(actor: 'xk7', action: 'Viewed logs', target: 'Survival', time: '4m'),
  ActivityRecord(actor: 'Ari', action: 'Edited permissions', target: 'Moderator role', time: '12m'),
  ActivityRecord(actor: 'Mina', action: 'Opened console', target: 'Lobby', time: '18m'),
];
const demoLogs = [
  ServerLogRecord(time: '12:04', type: 'Players', actor: 'Steve', message: 'player joined Survival'),
  ServerLogRecord(time: '12:06', type: 'Players', actor: 'Alex', message: 'player left Lobby'),
  ServerLogRecord(time: '12:07', type: 'Commands', actor: 'xk7', message: 'used /list'),
  ServerLogRecord(time: '12:10', type: 'Server', message: 'server warning: high entity count in world'),
  ServerLogRecord(time: '12:13', type: 'Server', message: 'plugin event: EMPControlAgent heartbeat received'),
  ServerLogRecord(time: '12:15', type: 'Security', actor: 'Console', message: 'dangerous command monitor checked /op attempt'),
];
const demoSecurityEvents = ['OP protection enabled', 'Dangerous command monitoring enabled', 'No unauthorized OP changes detected'];

int _safeIndex(int index, int length) => length <= 0 ? 0 : index.clamp(0, length - 1).toInt();
int _int(dynamic value, int fallback) => value is num ? value.round() : fallback;
double _double(dynamic value, double fallback) => value is num ? value.toDouble() : fallback;
