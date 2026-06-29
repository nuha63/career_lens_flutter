import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// Lightweight connectivity checker for CareerLens.
///
/// Attempts a HEAD request to the backend /health endpoint; any network-level
/// error is treated as "offline".  The result is cached for [_cacheDuration]
/// to avoid hammering the network on rapid successive calls.
///
/// Usage:
///   final online = await ConnectivityService().checkConnectivity();
///   final quick  = ConnectivityService().isOnlineCached; // last known state
class ConnectivityService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  // ── Internal state ─────────────────────────────────────────────────────────
  bool      _isOnline      = true;   // optimistic default
  DateTime? _lastCheck;
  static const Duration _cacheDuration = Duration(seconds: 5);
  static const Duration _timeout       = Duration(seconds: 4);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Synchronous read of the last known connectivity state.
  /// May be up to [_cacheDuration] stale — safe to call from `build()`.
  bool get isOnlineCached => _isOnline;

  /// Asynchronously checks whether the backend is reachable.
  ///
  /// Result is cached for [_cacheDuration]. Subsequent calls within that window
  /// return immediately without hitting the network.
  Future<bool> checkConnectivity() async {
    final now = DateTime.now();
    if (_lastCheck != null && now.difference(_lastCheck!) < _cacheDuration) {
      return _isOnline;
    }

    bool result = false;
    try {
      final response = await http
          .get(Uri.parse('${AppConstants.baseUrl}/health'))
          .timeout(_timeout);
      result = response.statusCode < 500;
    } on SocketException {
      result = false;
    } on HttpException {
      result = false;
    } catch (_) {
      result = false;
    }

    _isOnline  = result;
    _lastCheck = now;
    debugPrint('📶 Connectivity: ${_isOnline ? "online ✅" : "offline ❌"}');
    return _isOnline;
  }

  /// Force an immediate connectivity re-check (ignores cache window).
  Future<bool> forceCheck() async {
    _lastCheck = null;
    return checkConnectivity();
  }
}
