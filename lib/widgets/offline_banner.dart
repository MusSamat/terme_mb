import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Slim connectivity banner — 1:1 port of offline-banner.tsx. Fixed at the top,
/// driven by connectivity changes: offline → ink «Нет соединения»; on reconnect
/// it flashes a brand «Соединение восстановлено» for 2.6s.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;
  bool _restored = false;
  Timer? _flash;
  Timer? _verify;

  static bool _isOffline(List<ConnectivityResult> r) =>
      r.isEmpty || r.every((c) => c == ConnectivityResult.none);

  @override
  void initState() {
    super.initState();
    _conn.checkConnectivity().then(_apply);
    _sub = _conn.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final offline = _isOffline(results);

    if (!offline) {
      // Any live connection cancels a pending "offline" verification and, if we
      // were showing the banner, flashes the restored state.
      _verify?.cancel();
      if (!_offline) return;
      setState(() {
        _offline = false;
        _restored = true;
      });
      _flash?.cancel();
      _flash = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _restored = false);
      });
      return;
    }

    // Offline reported — but connectivity_plus emits a transient `none` during
    // cellular/Wi-Fi handoff. Don't trust it immediately: re-check after a short
    // delay and only show the banner if it's STILL down. Avoids false "no
    // connection" flashes on phones that actually have internet.
    if (_offline || _verify != null) return;
    _verify = Timer(const Duration(seconds: 3), () async {
      _verify = null;
      final again = await _conn.checkConnectivity();
      if (mounted && _isOffline(again)) {
        setState(() {
          _offline = true;
          _restored = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flash?.cancel();
    _verify?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline && !_restored) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: _offline ? (dark ? InkColors.c700 : InkColors.c800) : BrandColors.c600,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, bottom: 6, left: 16, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_offline ? Icons.wifi_off : Icons.wifi, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(_offline ? 'offline.no_connection'.tr() : 'offline.restored'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
