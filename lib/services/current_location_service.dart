import 'package:geolocator/geolocator.dart';

/// Resolves location once and shares the result with screens that need it.
/// This prevents the map and listing form from triggering competing requests.
class CurrentLocationService {
  CurrentLocationService._();

  static final instance = CurrentLocationService._();

  Position? _position;
  Future<Position?>? _inFlight;

  Position? get cachedPosition => _position;

  Future<Position?> warm({bool requestPermission = true}) {
    if (_position != null) return Future.value(_position);
    return _inFlight ??=
        _resolve(requestPermission: requestPermission).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<Position?> refresh() async {
    _position = null;
    return warm();
  }

  Future<Position?> _resolve({required bool requestPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) _position = lastKnown;

    try {
      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      // A recent OS-cached position is still useful when GPS is slow indoors.
    }
    return _position;
  }
}
