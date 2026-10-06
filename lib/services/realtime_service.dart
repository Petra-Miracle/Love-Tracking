import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../config.dart';
import '../data/api_client.dart';

typedef RealtimeEventHandler = void Function(String eventName, Map<String, dynamic> data);

/// Pusher connection that follows the current user/couple channels.
///
/// Channels: `private-user-{userId}` and `private-couple-{coupleId}`.
class RealtimeService {
  RealtimeService({required this.api, required this.onEvent, required this.onReconnected});

  final ApiClient api;
  final RealtimeEventHandler onEvent;

  /// Called when the socket (re)connects, so missed events can be caught up via `GET /me`.
  final VoidCallback onReconnected;

  final _pusher = PusherChannelsFlutter.getInstance();
  final _channels = <String>{};
  bool _initialized = false;
  bool _connected = false;

  /// Serializes [sync] calls so subscriptions never race each other.
  Future<void> _queue = Future.value();

  void sync({String? userId, String? coupleId}) {
    _queue = _queue.then((_) => _sync(userId, coupleId)).catchError((Object e) {
      debugPrint('Realtime sync failed: $e');
    });
  }

  Future<void> _sync(String? userId, String? coupleId) async {
    final wanted = {
      if (userId != null) 'private-user-$userId',
      if (coupleId != null) 'private-couple-$coupleId',
    };

    if (wanted.isEmpty) {
      if (_connected) {
        for (final name in _channels.toList()) {
          await _pusher.unsubscribe(channelName: name);
        }
        _channels.clear();
        await _pusher.disconnect();
        _connected = false;
      }
      return;
    }

    await _ensureConnected();
    for (final name in _channels.difference(wanted).toList()) {
      await _pusher.unsubscribe(channelName: name);
      _channels.remove(name);
    }
    for (final name in wanted.difference(_channels)) {
      await _pusher.subscribe(channelName: name, onEvent: _handleEvent);
      _channels.add(name);
    }
  }

  Future<void> _ensureConnected() async {
    if (!_initialized) {
      await _pusher.init(
        apiKey: AppConfig.pusherKey,
        cluster: AppConfig.pusherCluster,
        onAuthorizer: _authorize,
        onConnectionStateChange: (current, previous) {
          if (current == 'CONNECTED' && previous != 'CONNECTED') onReconnected();
        },
        onError: (message, code, error) => debugPrint('Pusher error $code: $message'),
        onSubscriptionError: (message, error) => debugPrint('Pusher subscription error: $message'),
      );
      _initialized = true;
    }
    if (!_connected) {
      await _pusher.connect();
      _connected = true;
    }
  }

  Future<dynamic> _authorize(String channelName, String socketId, dynamic options) async {
    try {
      return await api.pusherAuth(socketId: socketId, channelName: channelName);
    } catch (e) {
      debugPrint('Pusher auth failed for $channelName: $e');
      return null;
    }
  }

  void _handleEvent(dynamic event) {
    if (event is! PusherEvent || event.eventName.startsWith('pusher:')) return;
    final raw = event.data;
    final Object? data = raw is String && raw.isNotEmpty ? jsonDecode(raw) : raw;
    onEvent(event.eventName, data is Map ? Map<String, dynamic>.from(data) : const {});
  }
}
