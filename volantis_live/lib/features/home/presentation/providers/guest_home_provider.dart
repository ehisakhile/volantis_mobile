import 'package:flutter/foundation.dart';
import '../../data/models/company_model.dart';
import '../../data/models/guest_home_models.dart';
import '../../data/services/home_guest_service.dart';

class GuestHomeProvider extends ChangeNotifier {
  final HomeGuestService _guestService = HomeGuestService();

  List<CompanyModel> _companies = [];
  List<ActiveLivestream> _livestreams = [];
  bool _isLoading = false;
  String? _error;

  List<CompanyModel> get companies => _companies;
  List<ActiveLivestream> get livestreams => _livestreams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([_fetchCompanies(), _fetchLivestreams()]);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchCompanies() async {
    final (companies, error) = await _guestService.getCompanies(
      limit: 50,
      offset: 0,
    );

    if (error != null) {
      _error = error;
    } else if (companies != null) {
      _companies = companies;
    }
  }

  Future<void> _fetchLivestreams() async {
    final (livestreams, error) = await _guestService.getActiveLivestreams(
      limit: 50,
      offset: 0,
    );

    if (error != null && _error == null) {
      _error = error;
    } else if (livestreams != null) {
      _livestreams = livestreams;
    }
  }

  Future<void> refresh() async {
    _companies = [];
    _livestreams = [];
    await init();
  }
}
