import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Service for managing Shorebird code push updates
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Get the current patch information
  Future<Patch?> getCurrentPatch() async {
    try {
      return await _updater.readCurrentPatch();
    } catch (e) {
      print('Failed to read current patch: $e');
      return null;
    }
  }

  /// Check for available updates
  Future<UpdateStatus> checkForUpdate() async {
    try {
      return await _updater.checkForUpdate();
    } catch (e) {
      print('Failed to check for update: $e');
      return UpdateStatus.upToDate; // Default to up to date on error
    }
  }

  /// Download and apply update
  Future<void> update() async {
    try {
      await _updater.update();
    } on UpdateException catch (e) {
      print('Update failed: $e');
      rethrow;
    }
  }

  /// Check for updates and apply if available
  Future<bool> checkAndUpdate() async {
    final status = await checkForUpdate();
    if (status == UpdateStatus.outdated) {
      await update();
      return true;
    }
    return false;
  }
}