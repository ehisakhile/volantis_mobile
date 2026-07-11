import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:permission_handler/permission_handler.dart';
import '../connect_colors.dart';

/// Pre-join consent sheet shown before entering a room
/// Allows user to enable/disable mic and camera, and optionally set display name
class PrejoinSheet extends StatefulWidget {
  final bool isGuest;
  final bool isLoading;

  const PrejoinSheet({
    super.key,
    this.isGuest = false,
    this.isLoading = false,
  });

  @override
  State<PrejoinSheet> createState() => _PrejoinSheetState();
}

class _PrejoinSheetState extends State<PrejoinSheet> {
  late bool _enableMic;
  late bool _enableCamera;
  String _guestName = '';
  bool _requestingMicPermission = false;
  bool _requestingCameraPermission = false;
  String? _cameraError;
  String? _micError;

  @override
  void initState() {
    super.initState();
    _enableMic = true;
    _enableCamera = true;
  }

  Future<void> _toggleMic() async {
    if (!_enableMic) {
      // Turning on - request permission
      setState(() => _requestingMicPermission = true);
      try {
        final status = await Permission.microphone.request();
        setState(() {
          _enableMic = status.isGranted;
          _micError = status.isDenied ? 'Microphone permission denied' : null;
          _requestingMicPermission = false;
        });
      } catch (e) {
        setState(() {
          _micError = 'Failed to request microphone permission';
          _requestingMicPermission = false;
        });
      }
    } else {
      // Turning off - no permission needed
      setState(() => _enableMic = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (!_enableCamera) {
      // Turning on - request permission
      setState(() => _requestingCameraPermission = true);
      try {
        final status = await Permission.camera.request();
        setState(() {
          _enableCamera = status.isGranted;
          _cameraError = status.isDenied ? 'Camera not available' : null;
          _requestingCameraPermission = false;
        });
      } catch (e) {
        setState(() {
          _cameraError = 'Failed to request camera permission';
          _requestingCameraPermission = false;
        });
      }
    } else {
      // Turning off - no permission needed
      setState(() => _enableCamera = false);
    }
  }

  bool get _isValid {
    if (widget.isGuest && _guestName.trim().length < 2) return false;
    return true;
  }

  void _handleJoin() {
    if (!_isValid) return;

    // Pass the settings back via Navigator
    Navigator.of(context).pop<PrejoinSettings>(
      PrejoinSettings(
        enableMic: _enableMic,
        enableCamera: _enableCamera,
        guestName: widget.isGuest ? _guestName.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: ConnectColors.bg,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ready to join?',
                  style: TextStyle(
                    color: ConnectColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    color: ConnectColors.textSecondary,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Volantis Live will use your camera and microphone so others can see and hear you. '
              'You can turn either off any time.',
              style: TextStyle(
                color: ConnectColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Guest name input (if guest)
            if (widget.isGuest) ...[
              Text(
                'Display Name',
                style: TextStyle(
                  color: ConnectColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => setState(() => _guestName = value),
                maxLength: 50,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9 ]'),
                  ),
                ],
                style: TextStyle(
                  color: ConnectColors.text,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: TextStyle(
                    color: ConnectColors.textTertiary,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: ConnectColors.bgCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ConnectColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ConnectColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: ConnectColors.accent,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Mic toggle
            _ToggleRow(
              label: 'Microphone',
              isEnabled: _enableMic,
              isLoading: _requestingMicPermission,
              error: _micError,
              onToggle: _toggleMic,
            ),
            const SizedBox(height: 12),

            // Camera toggle
            _ToggleRow(
              label: 'Camera',
              isEnabled: _enableCamera,
              isLoading: _requestingCameraPermission,
              error: _cameraError,
              onToggle: _toggleCamera,
            ),
            const SizedBox(height: 20),

            // Join button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (widget.isLoading || _requestingMicPermission || _requestingCameraPermission || !_isValid)
                    ? null
                    : _handleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConnectColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ConnectColors.disabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: widget.isLoading || _requestingMicPermission || _requestingCameraPermission
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Join now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle row for mic/camera settings
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool isEnabled;
  final bool isLoading;
  final String? error;
  final VoidCallback onToggle;

  const _ToggleRow({
    required this.label,
    required this.isEnabled,
    required this.isLoading,
    required this.onToggle,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ConnectColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(ConnectColors.accent),
                ),
              )
            else
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 50,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isEnabled ? ConnectColors.accent : ConnectColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isEnabled ? ConnectColors.accent : ConnectColors.border,
                    ),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: isEnabled ? 24 : 4,
                        top: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: TextStyle(
              color: ConnectColors.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// Settings returned from prejoin sheet
class PrejoinSettings {
  final bool enableMic;
  final bool enableCamera;
  final String? guestName;

  PrejoinSettings({
    required this.enableMic,
    required this.enableCamera,
    this.guestName,
  });
}
