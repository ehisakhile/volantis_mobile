import 'package:flutter/foundation.dart';
import '../../../../services/api_service.dart';
import '../../data/models/category_model.dart';
import '../../data/services/category_service.dart';

class CategoryPreferencesProvider extends ChangeNotifier {
  late final CategoryService _categoryService;
  
  List<CategoryModel> _allCategories = [];
  List<CategoryModel> _userPreferences = [];
  Set<int> _selectedCategoryIds = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSaving = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMorePages = false;
  bool _hasCheckedPreferences = false;
  bool _preferencesPromptShown = false;

  CategoryPreferencesProvider() {
    _categoryService = CategoryService(ApiService.instance);
  }

  List<CategoryModel> get allCategories => _allCategories;
  List<CategoryModel> get userPreferences => _userPreferences;
  Set<int> get selectedCategoryIds => _selectedCategoryIds;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get hasMorePages => _hasMorePages;
  bool get hasCheckedPreferences => _hasCheckedPreferences;
  bool get preferencesPromptShown => _preferencesPromptShown;

  Future<void> checkUserPreferences() async {
    if (_hasCheckedPreferences && _preferencesPromptShown) {
      return;
    }
    
    try {
      _userPreferences = await _categoryService.getUserPreferences();
      _hasCheckedPreferences = true;
      notifyListeners();
    } catch (e) {
      _hasCheckedPreferences = true;
      _userPreferences = [];
      notifyListeners();
    }
  }

  bool get hasUserPreferences => _userPreferences.isNotEmpty;

  void markPreferencesPromptShown() {
    _preferencesPromptShown = true;
    notifyListeners();
  }

  void resetPreferencesCheck() {
    _hasCheckedPreferences = false;
    notifyListeners();
  }

  void resetPreferencesPrompt() {
    _preferencesPromptShown = false;
    _hasCheckedPreferences = false;
    notifyListeners();
  }

  Future<void> loadCategories({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _currentPage = 1;
      _allCategories = [];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _categoryService.getCategories(
        page: _currentPage,
        limit: 20,
      );
      
      if (refresh) {
        _allCategories = response.items;
      } else {
        _allCategories.addAll(response.items);
      }
      
      _totalPages = response.totalPages;
      _hasMorePages = _currentPage < _totalPages;
      _currentPage++;
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreCategories() async {
    if (_isLoadingMore || !_hasMorePages) return;
    
    _isLoadingMore = true;
    notifyListeners();

    try {
      final response = await _categoryService.getCategories(
        page: _currentPage,
        limit: 20,
      );
      
      _allCategories.addAll(response.items);
      _totalPages = response.totalPages;
      _hasMorePages = _currentPage < _totalPages;
      _currentPage++;
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void toggleCategory(int categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  bool isCategorySelected(int categoryId) {
    return _selectedCategoryIds.contains(categoryId);
  }

  Future<bool> savePreferences() async {
    if (_selectedCategoryIds.isEmpty) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _categoryService.setUserPreferences(_selectedCategoryIds.toList());
      
      // Reload preferences to confirm
      _userPreferences = await _categoryService.getUserPreferences();
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void setSelectedCategories(List<int> categoryIds) {
    _selectedCategoryIds = categoryIds.toSet();
    notifyListeners();
  }

  void clearSelection() {
    _selectedCategoryIds.clear();
    notifyListeners();
  }

  Future<void> loadCategoriesWithPreferences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await _categoryService.getUserPreferences();
      _userPreferences = prefs;
      _selectedCategoryIds = prefs.map((c) => c.id).toSet();

      final response = await _categoryService.getCategories(
        page: _currentPage,
        limit: 20,
      );
      
      _allCategories = response.items;
      _totalPages = response.totalPages;
      _hasMorePages = _currentPage < _totalPages;
      _currentPage++;
      
      _hasCheckedPreferences = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _hasCheckedPreferences = true;
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}