import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

typedef LatLngPoint = ({double lat, double lng});

/// Device location, best-effort and never blocking: every feature that uses
/// it (prefill «Откуда», default pin, «ближайшие») works without it too.
class LocationService {
  LatLngPoint? _last;

  /// Last fix from this session (no prompt, no wait).
  LatLngPoint? get last => _last;

  /// Asks for permission once (when-in-use) and returns the position, or null
  /// when location is off / denied / times out.
  Future<LatLngPoint?> current({bool ask = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _last;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && ask) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return _last;
      }
      final known = await Geolocator.getLastKnownPosition();
      if (known != null) _last = (lat: known.latitude, lng: known.longitude);
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return _last = (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return _last;
    }
  }

  /// True when the user has already granted location (no prompt).
  Future<bool> granted() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// Kyrgyzstan bounds — the API only accepts points inside them.
bool inKyrgyzstan(LatLngPoint p) => p.lat >= 39 && p.lat <= 43.5 && p.lng >= 69 && p.lng <= 81;
