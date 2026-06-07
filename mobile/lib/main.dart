import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'backend/voice_backend_client.dart';

void main() => runApp(const StrawIOVoiceChatApp());

const _background = Color(0xFF050607);
const _surface = Color(0xFF101214);
const _surfaceSoft = Color(0xFF171A1D);
const _gold = Color(0xFFE2B84F);
const _goldBright = Color(0xFFFFD978);
const _cyan = Color(0xFF5ED7E8);
const _text = Color(0xFFF4F1E8);
const _muted = Color(0xFF9B9C9F);
const _danger = Color(0xFFFF6B6B);

class StrawIOVoiceChatApp extends StatelessWidget {
  const StrawIOVoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrawIO VoiceChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _gold,
          secondary: _cyan,
          surface: _surface,
          error: _danger,
        ),
      ),
      home: const VoiceChatHomePage(),
    );
  }
}

class VoiceChatHomePage extends StatefulWidget {
  const VoiceChatHomePage({super.key});

  @override
  State<VoiceChatHomePage> createState() => _VoiceChatHomePageState();
}

class _VoiceChatHomePageState extends State<VoiceChatHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final VoiceBackendClient _backend;
  StreamSubscription<BackendSnapshot>? _subscription;
  BackendSnapshot _snapshot =
      const BackendSnapshot(state: BackendState.initializing);
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _backend = VoiceBackendClient();
    _subscription = _backend.snapshots.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });
    unawaited(_backend.initialize());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_backend.dispose());
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _showLinkDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Link Minecraft account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Run /voice link in Minecraft, then enter the temporary code.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Link code',
                hintText: 'STR-123456',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Link'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;

    setState(() => _linking = true);
    try {
      await _backend.claim(code);
    } on BackendException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _ViewStatus.fromSnapshot(_snapshot);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundGlow()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final padding = constraints.maxWidth < 420 ? 20.0 : 28.0;
                final width = math.min(
                  constraints.maxWidth - padding * 2,
                  560.0,
                );
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(padding, 20, padding, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width),
                      child: Column(
                        children: [
                          _BrandHeader(animation: _pulse),
                          const SizedBox(height: 28),
                          _StatusCard(status: status),
                          if (_snapshot.state == BackendState.unlinked ||
                              _snapshot.state == BackendState.expired) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _linking ? null : _showLinkDialog,
                                icon: _linking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.link_rounded),
                                label: Text(
                                  _linking
                                      ? 'Linking...'
                                      : 'Link Minecraft Account',
                                ),
                              ),
                            ),
                          ],
                          if (_snapshot.state == BackendState.unavailable) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _backend.initialize,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry Connection'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const _StudioCreditCard(),
                          const SizedBox(height: 24),
                          const _FooterMessage(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewStatus {
  const _ViewStatus({
    required this.headline,
    required this.player,
    required this.server,
    required this.status,
    required this.accent,
  });

  final String headline;
  final String player;
  final String server;
  final String status;
  final Color accent;

  factory _ViewStatus.fromSnapshot(BackendSnapshot snapshot) {
    return switch (snapshot.state) {
      BackendState.initializing => const _ViewStatus(
          headline: 'Initializing secure connection',
          player: 'Not detected',
          server: 'Waiting for Minecraft',
          status: 'Initializing',
          accent: _gold,
        ),
      BackendState.unavailable => const _ViewStatus(
          headline: 'Voice backend unavailable',
          player: 'Not detected',
          server: 'Waiting for Minecraft',
          status: 'Offline',
          accent: _danger,
        ),
      BackendState.unlinked || BackendState.expired => _ViewStatus(
          headline: 'Link your account once to continue',
          player: snapshot.player ?? 'Not linked',
          server: 'Waiting for Minecraft',
          status: 'Link required',
          accent: _gold,
        ),
      BackendState.linking => const _ViewStatus(
          headline: 'Linking Minecraft account',
          player: 'Verifying code',
          server: 'Waiting for Minecraft',
          status: 'Linking',
          accent: _gold,
        ),
      BackendState.connecting => _ViewStatus(
          headline: 'Connecting automatically',
          player: snapshot.player ?? 'Detecting player',
          server: snapshot.server ?? 'Waiting for Minecraft',
          status: 'Connecting',
          accent: _gold,
        ),
      BackendState.connected => _ViewStatus(
          headline: snapshot.online
              ? 'Connected automatically'
              : 'Linked and waiting for Minecraft',
          player: snapshot.player ?? 'Linked player',
          server: snapshot.server ?? 'Waiting for Minecraft',
          status: snapshot.online ? 'Connected Automatically' : 'Standby',
          accent: snapshot.online ? _cyan : _gold,
        ),
      BackendState.disconnected => _ViewStatus(
          headline: 'Connection lost — reconnecting',
          player: snapshot.player ?? 'Linked player',
          server: snapshot.server ?? 'Waiting for Minecraft',
          status: 'Reconnecting',
          accent: _danger,
        ),
      BackendState.error => _ViewStatus(
          headline: snapshot.message ?? 'Connection unavailable',
          player: snapshot.player ?? 'Not detected',
          server: snapshot.server ?? 'Waiting for Minecraft',
          status: 'Error',
          accent: _danger,
        ),
    };
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _gold.withValues(alpha: 0.22 + animation.value * 0.18),
                  _gold.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: child,
          ),
          child: const _MicrophoneMark(),
        ),
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            children: [
              TextSpan(text: 'Straw', style: TextStyle(color: _text)),
              TextSpan(text: 'IO', style: TextStyle(color: _goldBright)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'VOICECHAT',
          style: TextStyle(
            color: _goldBright,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 4.2,
          ),
        ),
      ],
    );
  }
}

class _MicrophoneMark extends StatelessWidget {
  const _MicrophoneMark();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 74,
        height: 96,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(38),
          border: Border.all(color: _goldBright, width: 2),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.28),
              blurRadius: 24,
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: _goldBright, size: 48),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final _ViewStatus status;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: status.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(Icons.graphic_eq_rounded, color: status.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  status.headline,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _StatusRow(
            icon: Icons.person_outline_rounded,
            label: 'Player',
            value: status.player,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.dns_outlined,
            label: 'Server',
            value: status.server,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.radio_button_checked_rounded,
            label: 'Status',
            value: status.status,
            valueColor: status.accent,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _gold),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? _text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioCreditCard extends StatelessWidget {
  const _StudioCreditCard();
  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.grass_rounded, color: _goldBright),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This project was developed by',
                  style: TextStyle(color: _muted, fontSize: 12.5),
                ),
                SizedBox(height: 3),
                Text(
                  'StrawIO Studio',
                  style: TextStyle(
                    color: _goldBright,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Minecraft & Discord Development Studio',
                  style: TextStyle(color: _text, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterMessage extends StatelessWidget {
  const _FooterMessage();
  @override
  Widget build(BuildContext context) {
    return const Text(
      'The app works automatically while you play.',
      textAlign: TextAlign.center,
      style: TextStyle(color: _muted, fontSize: 12.5),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.78),
          radius: 1.15,
          colors: [
            _gold.withValues(alpha: 0.10),
            _background.withValues(alpha: 0.94),
            _background,
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}
