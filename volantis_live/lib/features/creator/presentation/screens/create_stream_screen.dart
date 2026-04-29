import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/creator_provider.dart';
import '../../data/models/creator_stream_model.dart';
import '../widgets/audio_visualizer.dart';

class CreateStreamScreen extends StatefulWidget {
  final StreamType streamType;

  const CreateStreamScreen({super.key, required this.streamType});

  @override
  State<CreateStreamScreen> createState() => _CreateStreamScreenState();
}

class _CreateStreamScreenState extends State<CreateStreamScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isStarting = false;
  bool _isInitializing = true;

  static const _bg = Color(0xFF0B1326);
  static const _surface = Color(0xFF131B2E);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _success = Color(0xFF00E5A0);
  static const _error = Color(0xFFFF6B6B);

  bool _showRecordingPrompt = false;
  bool _wantsToRecord = false;
  bool _autoUpload = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeProviderIfNeeded();
  }

  Future<void> _initializeProviderIfNeeded() async {
    final provider = context.read<CreatorProvider>();
    if (provider.state == CreatorState.initial) {
      await provider.init();
    }
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator(color: _primary));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.streamType == StreamType.audio
              ? 'Audio Stream'
              : 'Video Stream',
          style: const TextStyle(
            color: _onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<CreatorProvider>(
        builder: (context, provider, child) {
          if (_isInitializing) {
            return _buildLoadingView();
          }
          if (provider.state == CreatorState.loading) {
            return _buildLoadingView();
          }
          if (provider.isStreaming) {
            return _buildLiveStreamingView(provider);
          }
          return _buildCreateStreamView(provider);
        },
      ),
    );
  }

  Widget _buildCreateStreamView(CreatorProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewCard(),
          const SizedBox(height: 24),
          _buildTitleField(),
          const SizedBox(height: 16),
          _buildDescriptionField(),
          const SizedBox(height: 24),
          _buildAudioSourceSection(provider),
          // const SizedBox(height: 24),
          // _buildRecordingSection(),
          const SizedBox(height: 32),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildLiveStreamingView(CreatorProvider provider) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildLiveHeader(provider),
                const SizedBox(height: 24),
                _buildVisualizerSection(provider),
                const SizedBox(height: 24),
                // _buildStatsSection(provider),
                // const SizedBox(height: 24),
                // _buildMixerControls(provider),
                // const SizedBox(height: 24),
                _buildStreamControls(provider),
              ],
            ),
          ),
        ),
        _buildBottomControls(provider),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.streamType == StreamType.audio
                  ? Icons.mic
                  : Icons.videocam,
              color: _primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.streamType == StreamType.audio
                ? 'Audio Only'
                : 'Video Stream',
            style: const TextStyle(
              color: _onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your viewers will see your stream in their feed',
            style: TextStyle(color: _onVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stream Title',
          style: TextStyle(
            color: _onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: _onSurface),
          decoration: InputDecoration(
            hintText: 'Give your stream a title...',
            hintStyle: TextStyle(color: _onVariant.withOpacity(0.5)),
            filled: true,
            fillColor: _glassCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description (optional)',
          style: TextStyle(
            color: _onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: _onSurface),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Tell viewers what your stream is about...',
            hintStyle: TextStyle(color: _onVariant.withOpacity(0.5)),
            filled: true,
            fillColor: _glassCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioSourceSection(CreatorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Source',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildAudioSourceToggle(
            'Microphone',
            Icons.mic,
            provider.useMicrophone,
            (value) => provider.setUseMicrophone(value),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSourceToggle(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? _primary.withOpacity(0.1) : _surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? _primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: value ? _primary : _onVariant, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: value ? _primary : _onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _onVariant.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged, activeColor: _primary),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recording',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Record your stream to save or upload automatically',
            style: TextStyle(color: _onVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildRecordingOption(
            'No thanks',
            Icons.close,
            !_wantsToRecord,
            () => setState(() {
              _wantsToRecord = false;
              _autoUpload = false;
            }),
          ),
          const SizedBox(height: 8),
          _buildRecordingOption(
            'Save locally',
            Icons.save,
            _wantsToRecord && !_autoUpload,
            () => setState(() {
              _wantsToRecord = true;
              _autoUpload = false;
            }),
          ),
          const SizedBox(height: 8),
          _buildRecordingOption(
            'Save & auto-upload',
            Icons.cloud_upload,
            _wantsToRecord && _autoUpload,
            () => setState(() {
              _wantsToRecord = true;
              _autoUpload = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingOption(
    String title,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.1) : _surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _primary : _onVariant, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: selected ? _primary : _onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: _primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _isStarting ? null : _startStream,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _isStarting ? _primary.withOpacity(0.5) : _primary,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: _isStarting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: _onPrimary,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broadcast_on_personal,
                    color: _onPrimary,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Go Live',
                    style: TextStyle(
                      color: _onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLiveHeader(CreatorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _success.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: _success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: _success,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            provider.currentStream?.title ?? 'Untitled Stream',
            style: const TextStyle(
              color: _onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            provider.formattedDuration,
            style: const TextStyle(
              color: _onVariant,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility, color: _onVariant, size: 18),
              const SizedBox(width: 4),
              Text(
                '${provider.streamingStats.viewerCount} viewers',
                style: const TextStyle(color: _onVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerSection(CreatorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Level',
            style: TextStyle(
              color: _onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: AudioVisualizer(
              // audioEngine: provider.mixerEngine,
              config: VisualizerConfig(
                barCount: 32,
                barSpacing: 3,
                barRadius: 4,
                accentColor: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamControls(CreatorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _glassCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildControlRow(
            provider.isMuted ? 'Unmute' : 'Mute',
            provider.isMuted ? Icons.mic_off : Icons.mic,
            provider.isMuted ? _error : _primary,
            provider.toggleMute,
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(CreatorProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: _stopStream,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: _error,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'End Stream',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startStream() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a stream title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    final provider = context.read<CreatorProvider>();
    final description = _descriptionController.text.trim();

    provider.acceptRecording(withAutoUpload: _autoUpload);

    bool success;
    if (widget.streamType == StreamType.audio) {
      success = await provider.startAudioStream(
        title: title,
        description: description.isNotEmpty ? description : null,
      );
    } else {
      success = await provider.startVideoStream(
        title: title,
        description: description.isNotEmpty ? description : null,
      );
    }

    if (mounted) {
      setState(() => _isStarting = false);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to start stream'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopStream() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('End Stream?', style: TextStyle(color: _onSurface)),
        content: const Text(
          'Are you sure you want to end your stream?',
          style: TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _error),
            child: const Text('End Stream'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<CreatorProvider>();
      final success = await provider.stopStream();
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
