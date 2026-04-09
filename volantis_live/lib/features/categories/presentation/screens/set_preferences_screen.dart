import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/category_model.dart';
import '../providers/category_preferences_provider.dart';

class SetPreferencesScreen extends StatefulWidget {
  final VoidCallback? onPreferencesSet;

  const SetPreferencesScreen({super.key, this.onPreferencesSet});

  @override
  State<SetPreferencesScreen> createState() => _SetPreferencesScreenState();
}

class _SetPreferencesScreenState extends State<SetPreferencesScreen> {
  final ScrollController _scrollController = ScrollController();

  static const _bg = Color(0xFF0B1326);
  static const _surface = Color(0xFF131B2E);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _surfaceBright = Color(0xFF2D3449);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _secondary = Color(0xFFD2BBFF);
  static const _tertiary = Color(0xFFFFB3AD);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _outlineVar = Color(0xFF3E4850);
  static const _onPrimary = Color(0xFF00344D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CategoryPreferencesProvider>();
      provider.loadCategoriesWithPreferences();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<CategoryPreferencesProvider>().loadMoreCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned(
            top: -40,
            right: -60,
            child: _GlowBlob(color: Color(0x0D89CEFF), size: 260),
          ),
          const Positioned(
            bottom: 120,
            left: -80,
            child: _GlowBlob(color: Color(0x08D2BBFF), size: 220),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSubtitle(),
                Expanded(
                  child: Consumer<CategoryPreferencesProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading &&
                          provider.allCategories.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _primary,
                            strokeWidth: 2,
                          ),
                        );
                      }

                      if (provider.error != null &&
                          provider.allCategories.isEmpty) {
                        return _buildError(provider.error!);
                      }

                      return _buildCategoriesList(provider);
                    },
                  ),
                ),
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _onVariant,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Choose Your Interests',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 22,
                letterSpacing: -1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Select categories to personalize your content feed',
              style: TextStyle(
                color: _onVariant.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(CategoryPreferencesProvider provider) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount:
          provider.allCategories.length + (provider.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= provider.allCategories.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
            ),
          );
        }
        return _CategoryCard(
          category: provider.allCategories[index],
          isSelected: provider.isCategorySelected(
            provider.allCategories[index].id,
          ),
          onTap: () =>
              provider.toggleCategory(provider.allCategories[index].id),
        );
      },
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _tertiary),
            const SizedBox(height: 16),
            Text(
              'Failed to load categories',
              style: const TextStyle(
                color: _onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _onVariant,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                context.read<CategoryPreferencesProvider>().loadCategories(
                  refresh: true,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: _onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Consumer<CategoryPreferencesProvider>(
      builder: (context, provider, _) {
        final hasSelection = provider.selectedCategoryIds.isNotEmpty;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: _surface,
            border: Border(
              top: BorderSide(color: _surfaceBright.withOpacity(0.5), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (provider.selectedCategoryIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${provider.selectedCategoryIds.length} selected',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: hasSelection && !provider.isSaving
                      ? () => _savePreferences(provider)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: hasSelection ? _primary : _surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: hasSelection
                          ? [
                              BoxShadow(
                                color: _primary.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: provider.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: _onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Preferences',
                            style: TextStyle(
                              color: hasSelection ? _onPrimary : _outline,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _savePreferences(CategoryPreferencesProvider provider) async {
    final success = await provider.savePreferences();
    if (success && mounted) {
      provider.resetPreferencesPrompt();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _onPrimary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Preferences saved successfully!',
                  style: TextStyle(color: _onPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      if (widget.onPreferencesSet != null) {
        widget.onPreferencesSet!();
      } else {
        Navigator.of(context).pop();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.error ?? 'Failed to save preferences',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  static const _bg = Color(0xFF0B1326);
  static const _surface = Color(0xFF131B2E);
  static const _glassCard = Color(0xFF171F33);
  static const _surfaceHigh = Color(0xFF222A3D);
  static const _surfaceBright = Color(0xFF2D3449);
  static const _primary = Color(0xFF89CEFF);
  static const _primaryCont = Color(0xFF0EA5E9);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _onVariant = Color(0xFFBEC8D2);
  static const _outline = Color(0xFF88929B);
  static const _onPrimary = Color(0xFF00344D);

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return _primary;
    }
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'book': Icons.book_rounded,
      'cross': Icons.add_rounded,
      'home': Icons.home_rounded,
      'users': Icons.people_rounded,
      'graduation-cap': Icons.school_rounded,
      'star': Icons.star_rounded,
      'gamepad': Icons.sports_esports_rounded,
      'music': Icons.music_note_rounded,
      'heartbeat': Icons.favorite_rounded,
      'headphones': Icons.headphones_rounded,
      'newspaper': Icons.newspaper_rounded,
      'radio': Icons.radio_rounded,
      'hands': Icons.pan_tool_rounded,
      'trophy': Icons.emoji_events_rounded,
      'chalkboard': Icons.draw_rounded,
      'tools': Icons.build_rounded,
      'mic': Icons.mic_rounded,
    };
    return iconMap[iconName] ?? Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _parseColor(category.color);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? categoryColor.withOpacity(0.15) : _glassCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? categoryColor.withOpacity(0.5)
                : Colors.white.withOpacity(0.04),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconData(category.icon),
                color: categoryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _onVariant.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? categoryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? categoryColor : _outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
