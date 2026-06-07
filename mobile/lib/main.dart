import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const StrawIOVoiceChatApp());
}

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
        fontFamily: 'sans',
      ),
      home: const VoiceChatHomePage(),
    );
  }
}

enum VoiceConnectionState {
  initializing,
  waitingForMinecraft,
  minecraftDetected,
  waitingForSupportedServer,
  connecting,
  connected,
  disconnected,
  unsupportedServer,
  error,
}

class VoiceStatus {
  const VoiceStatus({
    required this.state,
    required this.playerName,
    required this.serverName,
  });

  final VoiceConnectionState state;
  final String? playerName;
  final String? serverName;

  String get headline => switch (state) {
        VoiceConnectionState.initializing => 'Initializing secure connection',
        VoiceConnectionState.waitingForMinecraft =>
          'Auto-detecting supported Minecraft server',
        VoiceConnectionState.minecraftDetected => 'Minecraft detected',
        VoiceConnectionState.waitingForSupportedServer =>
          'Waiting for a supported server',
        VoiceConnectionState.connecting => 'Connecting automatically',
        VoiceConnectionState.connected => 'Connected automatically',
        VoiceConnectionState.disconnected => 'Connection lost',
        VoiceConnectionState.unsupportedServer => 'Unsupported server',
        VoiceConnectionState.error => 'Connection unavailable',
      };

  String get stateLabel => switch (state) {
        VoiceConnectionState.initializing => 'Initializing',
        VoiceConnectionState.waitingForMinecraft => 'Standby',
        VoiceConnectionState.minecraftDetected => 'Minecraft detected',
        VoiceConnectionState.waitingForSupportedServer => 'Waiting',
        VoiceConnectionState.connecting => 'Connecting',
        VoiceConnectionState.connected => 'Connected Automatically',
        VoiceConnectionState.disconnected => 'Disconnected',
        VoiceConnectionState.unsupportedServer => 'Unsupported',
        VoiceConnectionState.error => 'Error',
      };

  Color get accent => switch (state) {
        VoiceConnectionState.connected => _cyan,
        VoiceConnectionState.error || VoiceConnectionState.disconnected =>
          _danger,
        _ => _gold,
      };
}

class VoiceChatHomePage extends StatefulWidget {
  const VoiceChatHomePage({super.key});

  @override
  State<VoiceChatHomePage> createState() => _VoiceChatHomePageState();
}

class _VoiceChatHomePageState extends State<VoiceChatHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  // Production starts safely in standby. Real values will come from the future
  // backend and Minecraft plugin, never from hardcoded player data.
  final VoiceStatus _status = const VoiceStatus(
    state: VoiceConnectionState.waitingForMinecraft,
    playerName: null,
    serverName: null,
  );

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundGlow()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 420 ? 20.0 : 28.0;
                final maxWidth = math.min(constraints.maxWidth - (horizontalPadding * 2), 560.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        children: [
                          _BrandHeader(animation: _pulseController),
                          const SizedBox(height: 28),
                          _StatusCard(status: _status),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final glow = 0.22 + (animation.value * 0.18);
            return Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withValues(alpha: glow),
                    _gold.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: child,
            );
          },
          child: const _MicrophoneMark(),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            children: [
              TextSpan(text: 'Straw', style: TextStyle(color: _text)),
              TextSpan(text: 'IO', style: TextStyle(color: _goldBright)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoldLine(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'VOICECHAT',
                style: TextStyle(
                  color: _goldBright,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4.2,
                  shadows: [
                    Shadow(
                      color: _gold.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            const _GoldLine(),
          ],
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final offset in const [-45.0, -33.0, 33.0, 45.0])
            Transform.translate(
              offset: Offset(offset, 0),
              child: Container(
                width: 3,
                height: offset.abs() > 40 ? 28 : 44,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          Container(
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
        ],
      ),
    );
  }
}

class _GoldLine extends StatelessWidget {
  const _GoldLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, _gold.withValues(alpha: 0.8)],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final VoiceStatus status;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.headline,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'The app connects automatically when a supported session is available.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _StatusRow(
            icon: Icons.person_outline_rounded,
            label: 'Player',
            value: status.playerName ?? 'Not detected',
          ),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.dns_outlined,
            label: 'Server',
            value: status.serverName ?? 'Waiting for Minecraft',
          ),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.radio_button_checked_rounded,
            label: 'Status',
            value: status.stateLabel,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.045)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _gold),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
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
      compact: true,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _gold.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.grass_rounded, color: _goldBright, size: 28),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          color: _gold.withValues(alpha: 0.8),
          size: 15,
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'The app works automatically while you play.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 20),
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
          BoxShadow(
            color: _gold.withValues(alpha: 0.045),
            blurRadius: 24,
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
