import 'package:flutter/services.dart';
import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';

part 'pusher.g.dart';

/// Used to listen to events sent through pusher
class Pusher {
  Pusher._();

  static const _channel = const MethodChannel('pusher');
  static const _eventChannel = const EventChannel('pusherStream');

  static void Function(ConnectionStateChange) _onConnectionStateChange;
  static void Function(ConnectionError) _onError;

  static Map<String, void Function(Event)> eventCallbacks =
      Map<String, void Function(Event)>();

  /// Setup app key and options
  static Future init(String appKey, PusherOptions options,
      {bool enableLogging = false}) async {
    assert(appKey != null);
    assert(options != null);

    _eventChannel.receiveBroadcastStream().listen(_handleEvent);

    final initArgs = jsonEncode(
        InitArgs(appKey, options, isLoggingEnabled: enableLogging).toJson());
    await _channel.invokeMethod('init', initArgs);
  }

  /// Connect the client to pusher
  static Future connect(
      {void Function(ConnectionStateChange) onConnectionStateChange,
      void Function(ConnectionError) onError}) async {
    _onConnectionStateChange = onConnectionStateChange;
    _onError = onError;
    await _channel.invokeMethod('connect');
  }

  /// Disconnect the client from pusher
  static Future disconnect() async {
    await _channel.invokeMethod('disconnect');
  }

  /// Subscribe to a channel
  /// Use the returned [Channel] to bind events
  static Future<Channel> subscribe(String channelName) async {
    await _channel.invokeMethod('subscribe', channelName);
    return Channel(name: channelName);
  }

  /// Unsubscribe from a channel
  static Future unsubscribe(String channelName) async {
    await _channel.invokeMethod('unsubscribe', channelName);
  }

  static Future _bind(String channelName, String eventName,
      {void Function(Event) onEvent}) async {
    final bindArgs = jsonEncode(
        BindArgs(channelName: channelName, eventName: eventName).toJson());
    eventCallbacks[channelName + eventName] = onEvent;
    await _channel.invokeMethod('bind', bindArgs);
  }

  static Future _unbind(String channelName, String eventName) async {
    final bindArgs = jsonEncode(
        BindArgs(channelName: channelName, eventName: eventName).toJson());
    eventCallbacks.remove(channelName + eventName);
    await _channel.invokeMethod('unbind', bindArgs);
  }

  static void _handleEvent([dynamic arguments]) {
    if (arguments == null || !(arguments is String)) {
      //TODO log
    }

    var message = PusherEventStreamMessage.fromJson(jsonDecode(arguments));

    if (message.isEvent) {
      var callback =
          eventCallbacks[message.event.channel + message.event.event];
      if (callback != null) {
        callback(message.event);
      } else {
        //TODO log
      }
    } else if (message.isConnectionStateChange) {
      if (_onConnectionStateChange != null) {
        _onConnectionStateChange(message.connectionStateChange);
      }
    } else if (message.isConnectionError) {
      if (_onError != null) {
        _onError(message.connectionError);
      }
    }
  }
}

@JsonSerializable()
class InitArgs {
  String appKey;
  PusherOptions options;
  bool isLoggingEnabled;

  InitArgs(this.appKey, this.options, {this.isLoggingEnabled = false});

  factory InitArgs.fromJson(Map<String, dynamic> json) =>
      _$InitArgsFromJson(json);

  Map<String, dynamic> toJson() => _$InitArgsToJson(this);
}

@JsonSerializable()
class BindArgs {
  String channelName;
  String eventName;

  BindArgs({this.channelName, this.eventName});

  factory BindArgs.fromJson(Map<String, dynamic> json) =>
      _$BindArgsFromJson(json);

  Map<String, dynamic> toJson() => _$BindArgsToJson(this);
}

@JsonSerializable()
class PusherOptions {
  String cluster;
  String host;
  int wsPort;
  int wssPort;

  PusherOptions({this.cluster, this.host, this.wsPort, this.wssPort});

  factory PusherOptions.fromJson(Map<String, dynamic> json) =>
      _$PusherOptionsFromJson(json);

  Map<String, dynamic> toJson() => _$PusherOptionsToJson(this);
}

@JsonSerializable()
class ConnectionStateChange {
  String currentState;
  String previousState;

  ConnectionStateChange({this.currentState, this.previousState});

  factory ConnectionStateChange.fromJson(Map<String, dynamic> json) =>
      _$ConnectionStateChangeFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionStateChangeToJson(this);
}

@JsonSerializable()
class ConnectionError {
  String message;
  String code;
  String exception;

  ConnectionError({this.message, this.code, this.exception});

  factory ConnectionError.fromJson(Map<String, dynamic> json) =>
      _$ConnectionErrorFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionErrorToJson(this);
}

@JsonSerializable()
class Event {
  String channel;
  String event;
  String data;

  Event({this.channel, this.event, this.data});

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);
}

class Channel {
  String name;

  Channel({this.name});

  /// Bind to listen for events sent on the given channel
  Future bind(String eventName, void Function(Event) onEvent) async {
    await Pusher._bind(name, eventName, onEvent: onEvent);
  }

  Future unbind(String eventName) async {
    await Pusher._unbind(name, eventName);
  }
}

@JsonSerializable()
class PusherEventStreamMessage {
  Event event;
  ConnectionStateChange connectionStateChange;
  ConnectionError connectionError;

  bool get isEvent => event != null;
  bool get isConnectionStateChange => connectionStateChange != null;
  bool get isConnectionError => connectionError != null;

  PusherEventStreamMessage(
      {this.event, this.connectionStateChange, this.connectionError});

  factory PusherEventStreamMessage.fromJson(Map<String, dynamic> json) =>
      _$PusherEventStreamMessageFromJson(json);

  Map<String, dynamic> toJson() => _$PusherEventStreamMessageToJson(this);
}
