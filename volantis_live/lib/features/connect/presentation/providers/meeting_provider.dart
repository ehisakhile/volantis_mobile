import 'package:flutter/foundation.dart';
import '../../data/models/meeting_model.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../data/meeting_code_parser.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

enum MeetingProviderState { idle, loading, error }

/// Provider for managing meeting creation and joining
class MeetingProvider extends ChangeNotifier {
  final MeetingRepository _repository = MeetingRepository();
  final AuthProvider _authProvider;

  MeetingProviderState _state = MeetingProviderState.idle;
  String? _errorMessage;

  MeetingProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == MeetingProviderState.loading;

  MeetingProvider(this._authProvider);

  /// Create an instant meeting (authenticated users only)
  Future<Meeting> createInstantMeeting({String? title}) async {
    _state = MeetingProviderState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      print('MeetingProvider: Creating instant meeting');
      final meeting = await _repository.createInstantMeeting(title: title);
      _state = MeetingProviderState.idle;
      notifyListeners();
      return meeting;
    } catch (e) {
      _state = MeetingProviderState.error;
      _errorMessage = e.toString();
      print('MeetingProvider: Create meeting error: $_errorMessage');
      notifyListeners();
      rethrow;
    }
  }

  /// Resolve a meeting join (for authenticated or guest users)
  /// Returns connection args: (token, url, room, displayName)
  Future<MeetingJoinArgs> resolveJoin(
    String codeOrLink, {
    String? guestName,
  }) async {
    _state = MeetingProviderState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      print('MeetingProvider: Resolving join for: $codeOrLink');

      // Parse the code/link
      final meetingId = extractMeetingId(codeOrLink);
      if (meetingId == null) {
        throw Exception('Invalid meeting code or link.');
      }

      print('MeetingProvider: Parsed meeting ID: $meetingId');

      // Get meeting details
      final meeting = await _repository.getMeeting(meetingId);
      print('MeetingProvider: Got meeting: ${meeting.niceId}');

      // Determine if user is authenticated
      final isAuthenticated = _authProvider.isAuthenticated;
      print('MeetingProvider: User authenticated: $isAuthenticated');

      MeetingJoinArgs args;
      if (isAuthenticated) {
        // Join as authenticated user
        final joined = await _repository.joinMeeting(meetingId);
        final livekit = joined.livekit;
        if (livekit == null) {
          throw Exception('Failed to get LiveKit credentials.');
        }
        print('MeetingProvider: Authenticated join successful');
        args = MeetingJoinArgs(
          token: livekit.token,
          url: livekit.livekitUrl,
          room: livekit.room,
          displayName: _authProvider.user?.username ?? 'User',
        );
      } else {
        // Join as guest
        if (guestName == null || guestName.isEmpty) {
          throw Exception('Display name required for guest join.');
        }
        final guestToken = await _repository.guestJoin(meetingId, guestName);
        print('MeetingProvider: Guest join successful');
        args = MeetingJoinArgs(
          token: guestToken.token,
          url: guestToken.livekitUrl,
          room: guestToken.room,
          displayName: guestToken.displayName,
        );
      }

      _state = MeetingProviderState.idle;
      notifyListeners();
      return args;
    } catch (e) {
      _state = MeetingProviderState.error;
      _errorMessage = e.toString();
      print('MeetingProvider: Resolve join error: $_errorMessage');
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// Arguments needed to join a LiveKit room
class MeetingJoinArgs {
  final String token;
  final String url;
  final String room;
  final String displayName;

  MeetingJoinArgs({
    required this.token,
    required this.url,
    required this.room,
    required this.displayName,
  });
}
