import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/creator_provider.dart';
import '../../data/models/creator_stream_model.dart';

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

  static const _bg = Color(0xFF0B1326);
  static const _surface = Color(0xFF131B2E);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _primary = Color(0xFF89CEFF);
  static const _onPrimary = Color(0xFF00344D);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewCard(),
            const SizedBox(height: 24),
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 32),
            _buildStartButton(),
          ],
        ),
      ),
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

      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to start stream'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
