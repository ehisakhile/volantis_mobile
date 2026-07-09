import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  static const _bg = Color(0xFF080D1A);
  static const _surface = Color(0xFF0F1629);
  static const _surfaceLight = Color(0xFF1A2235);
  static const _glassCard = Color(0xFF141D30);
  static const _surfaceHigh = Color(0xFF1E2940);
  static const _primary = Color(0xFF60A5FA);
  static const _primaryDark = Color(0xFF1E3A5F);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentPurple = Color(0xFFA78BFA);
  static const _onPrimary = Color(0xFFFFFFFF);
  static const _onSurface = Color(0xFFFFFFFF);
  static const _onSurfaceMedium = Color(0xFFCBD5E1);
  static const _onVariant = Color(0xFF94A3B8);
  static const _outlineVar = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            _buildSubtitle(),
            const SizedBox(height: 28),
            const _MeetingPreview(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            const _JoinCodeField(),
            const SizedBox(height: 20),
            const _UpcomingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        _buildHeaderIconButton(
          icon: Icons.person_rounded,
          onTap: () => context.go('/profile'),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_accentBlue, _accentPurple],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        _buildHeaderIconButton(
          icon: Icons.settings_rounded,
          onTap: () => context.go('/profile'),
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: _primary, size: 22),
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Padding(
      padding: EdgeInsets.only(left: 58),
      child: Text(
        'Start or join a private audio room.',
        style: TextStyle(
          color: _onVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _GradientButton(
            icon: Icons.video_call_rounded,
            label: 'New Room',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassButton(
            icon: Icons.keyboard_rounded,
            label: 'Join Code',
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ConnectScreen._accentBlue, ConnectScreen._accentPurple],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ConnectScreen._accentBlue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          color: ConnectScreen._surfaceLight.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ConnectScreen._outlineVar.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: ConnectScreen._primary, size: 22),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: const TextStyle(
                color: ConnectScreen._onSurfaceMedium,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingPreview extends StatelessWidget {
  const _MeetingPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ConnectScreen._glassCard,
            ConnectScreen._surface.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: const [
                    _ParticipantTile(name: 'You', color: Color(0xFF60A5FA)),
                    _ParticipantTile(name: 'Host', color: Color(0xFFA78BFA)),
                    _ParticipantTile(name: 'Guest', color: Color(0xFFF472B6)),
                    _ParticipantTile(name: 'Team', color: Color(0xFF34D399)),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ControlBar(),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final String name;
  final Color color;

  const _ParticipantTile({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ConnectScreen._surfaceHigh,
            ConnectScreen._surfaceLight.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              name.characters.first,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              color: ConnectScreen._onSurfaceMedium,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ModernControlButton(icon: Icons.mic_rounded, isActive: true),
          SizedBox(width: 16),
          _ModernControlButton(icon: Icons.videocam_rounded, isActive: false),
          SizedBox(width: 16),
          _ModernControlButton(icon: Icons.screen_share_rounded, isActive: false),
        ],
      ),
    );
  }
}

class _ModernControlButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;

  const _ModernControlButton({required this.icon, required this.isActive});

  @override
  State<_ModernControlButton> createState() => _ModernControlButtonState();
}

class _ModernControlButtonState extends State<_ModernControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: widget.isActive
              ? (_isHovered ? ConnectScreen._accentBlue : ConnectScreen._surfaceLight)
              : (_isHovered ? ConnectScreen._surfaceLight.withOpacity(0.8) : Colors.white.withOpacity(0.1)),
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isActive
                ? ConnectScreen._accentBlue.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: ConnectScreen._accentBlue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          widget.icon,
          color: widget.isActive ? Colors.white : ConnectScreen._onVariant,
          size: 22,
        ),
      ),
    );
  }
}

class _JoinCodeField extends StatelessWidget {
  const _JoinCodeField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ConnectScreen._surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ConnectScreen._outlineVar.withOpacity(0.4)),
      ),
      child: const TextField(
        enabled: false,
        style: TextStyle(color: ConnectScreen._onSurfaceMedium, fontSize: 15),
        decoration: InputDecoration(
          icon: Icon(Icons.link_rounded, color: ConnectScreen._primary, size: 22),
          hintText: 'Enter a room code or link',
          hintStyle: TextStyle(color: ConnectScreen._onVariant),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ConnectScreen._glassCard,
            ConnectScreen._surface.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ConnectScreen._accentBlue, ConnectScreen._accentPurple],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ConnectScreen._accentBlue.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rooms coming soon',
                  style: TextStyle(
                    color: ConnectScreen._onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'The API can plug into this surface when meeting creation and invites are ready.',
                  style: TextStyle(
                    color: ConnectScreen._onVariant,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}