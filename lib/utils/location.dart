import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

typedef LatLngPoint = ({double lat, double lng});

/// Location permission as the map needs it: decides between the
/// pre-permission card, the «open settings» card and a live position.
enum LocPermission { granted, denied, deniedForever, serviceOff }

/// Device location, best-effort and never blocking: every feature that uses
/// it (prefill «Откуда», default pin, «ближайшие») works without it too.
class LocationService {
  LatLngPoint? _last;
  double? _accuracy;

  /// Last fix from this session (no prompt, no wait).
  LatLngPoint? get last => _last;

  /// Accuracy (m) of [last], when the platform reported one.
  double? get accuracy => _accuracy;

  /// Current permission state — never prompts.
  Future<LocPermission> status() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocPermission.serviceOff;
      return _map(await Geolocator.checkPermission());
    } catch (_) {
      return LocPermission.denied;
    }
  }

  /// Shows the OS prompt once. Call only from an explicit user action.
  Future<LocPermission> request() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocPermission.serviceOff;
      return _map(await Geolocator.requestPermission());
    } catch (_) {
      return LocPermission.denied;
    }
  }

  /// Platform last-known fix — instant, may be stale or null. No prompt.
  Future<LatLngPoint?> lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return _last;
      _accuracy = p.accuracy;
      return _last = (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return _last;
    }
  }

  /// Fresh fix (8s timeout) when permission is already granted; else [last].
  Future<LatLngPoint?> refine() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _accuracy = p.accuracy;
      return _last = (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return _last;
    }
  }

  /// App settings (permission denied forever) or the system location switch.
  Future<bool> openSettings(LocPermission s) async {
    try {
      return s == LocPermission.serviceOff
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  static LocPermission _map(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => LocPermission.granted,
        LocationPermission.deniedForever => LocPermission.deniedForever,
        _ => LocPermission.denied,
      };

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
