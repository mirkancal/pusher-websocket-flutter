import Flutter
import UIKit
import PusherSwift

public class SwiftPusherPlugin: NSObject, FlutterPlugin, PusherDelegate {
    
    public static var pusher: Pusher?
    public static var isLoggingEnabled: Bool = false;
    public static var bindedEvents = [String:String]()
    public static var channels = [String:PusherChannel]()
    public static var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pusher", binaryMessenger: registrar.messenger())
        let instance = SwiftPusherPlugin()
        let eventChannel = FlutterEventChannel(name: "pusherStream", binaryMessenger: registrar.messenger())
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(StreamHandler())
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            setup(call, result: result)
        case "connect":
            connect(call, result: result)
        case "disconnect":
            disconnect(call, result: result)
        case "subscribe":
            subscribe(call, result: result)
        case "unsubscribe":
            unsubscribe(call, result: result)
        case "bind":
            bind(call, result: result)
        case "unbind":
            unbind(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func setup(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherPlugin.pusher {
            pusherObj.unbindAll();
            pusherObj.unsubscribeAll()
        }
        
        for (_, pusherChannel) in SwiftPusherPlugin.channels {
            pusherChannel.unbindAll()
        }
        
        SwiftPusherPlugin.channels.removeAll();
        SwiftPusherPlugin.bindedEvents.removeAll()
        
        do {
            let json = call.arguments as! String
            let jsonDecoder = JSONDecoder()
            let initArgs = try jsonDecoder.decode(InitArgs.self, from: json.data(using: .utf8)!)
            
            SwiftPusherPlugin.isLoggingEnabled = initArgs.isLoggingEnabled
            
            let options = PusherClientOptions(
                host: .cluster(initArgs.options.cluster)
            )
            
            SwiftPusherPlugin.pusher = Pusher(
                key: initArgs.appKey,
                options: options
            )
            SwiftPusherPlugin.pusher!.connection.delegate = self
            
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher init")
            }
        } catch {
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher init error:" + error.localizedDescription)
            }
        }
        result(nil);
    }
    
    public func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherPlugin.pusher {
            pusherObj.connect();
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher connect")
            }
        }
        result(nil);
    }
    
    public func disconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherPlugin.pusher {
            pusherObj.disconnect();
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher disconnect")
            }
        }
        result(nil);
    }
    
    public func subscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherPlugin.pusher {
            let channelName = call.arguments as! String
            let channel = pusherObj.subscribe(channelName)
            SwiftPusherPlugin.channels[channelName] = channel;
            
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher subscribe")
            }
        }
        result(nil);
    }
    
    public func unsubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherPlugin.pusher {
            let channelName = call.arguments as! String
            pusherObj.unsubscribe(channelName)
            SwiftPusherPlugin.channels.removeValue(forKey: "channelName")
            
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher unsubscribe")
            }
        }
        result(nil);
    }
    
    public func bind(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            let json = call.arguments as! String
            let jsonDecoder = JSONDecoder()
            let bindArgs = try jsonDecoder.decode(BindArgs.self, from: json.data(using: .utf8)!)
            
            let channel = SwiftPusherPlugin.channels[bindArgs.channelName]
            if let channelObj = channel {
                unbindIfBound(channelName: bindArgs.channelName, eventName: bindArgs.eventName)
                SwiftPusherPlugin.bindedEvents[bindArgs.channelName + bindArgs.eventName] = channelObj.bind(eventName: bindArgs.eventName, callback: { data in
                    do {
                        if let dataObj = data as? [String : AnyObject] {
                            let pushJsonData = try! JSONSerialization.data(withJSONObject: dataObj)
                            let pushJsonString = NSString(data: pushJsonData, encoding: String.Encoding.utf8.rawValue)
                            let event = Event(channel: bindArgs.channelName, event: bindArgs.eventName, data: pushJsonString! as String)
                            let message = PusherEventStreamMessage(event: event, connectionStateChange:  nil)
                            let jsonEncoder = JSONEncoder()
                            let jsonData = try jsonEncoder.encode(message)
                            let jsonString = String(data: jsonData, encoding: .utf8)
                            if let eventSinkObj = SwiftPusherPlugin.eventSink {
                                eventSinkObj(jsonString)
                                
                                if (SwiftPusherPlugin.isLoggingEnabled) {
                                    print("Pusher event: CH:\(bindArgs.channelName) EN:\(bindArgs.eventName) ED:\(jsonString ?? "no data")")
                                }
                            }
                        }
                    } catch {
                        if (SwiftPusherPlugin.isLoggingEnabled) {
                            print("Pusher bind error:" + error.localizedDescription)
                        }
                    }
                })
                if (SwiftPusherPlugin.isLoggingEnabled) {
                    print("Pusher bind")
                }
            }
        } catch {
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher bind error:" + error.localizedDescription)
            }
        }
        result(nil);
    }
    
    public func unbind(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            let json = call.arguments as! String
            let jsonDecoder = JSONDecoder()
            let bindArgs = try jsonDecoder.decode(BindArgs.self, from: json.data(using: .utf8)!)
            unbindIfBound(channelName: bindArgs.channelName, eventName: bindArgs.eventName)
        } catch {
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher unbind error:" + error.localizedDescription)
            }
        }
        result(nil);
    }
    
    private func unbindIfBound(channelName: String, eventName: String) {
        let channel = SwiftPusherPlugin.channels[channelName]
        if let channelObj = channel {
            let callbackId = SwiftPusherPlugin.bindedEvents[channelName + eventName]
            if let callbackIdObj = callbackId {
                channelObj.unbind(eventName: eventName, callbackId: callbackIdObj)
                SwiftPusherPlugin.bindedEvents.removeValue(forKey: channelName + eventName)
                
                if (SwiftPusherPlugin.isLoggingEnabled) {
                    print("Pusher unbind")
                }
            }
        }
    }
    
    public func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        do {
            let stateChange = ConnectionStateChange(currentState: new.stringValue(), previousState: old.stringValue())
            let message = PusherEventStreamMessage(event: nil, connectionStateChange: stateChange)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(message)
            let jsonString = String(data: jsonData, encoding: .utf8)
            if let eventSinkObj = SwiftPusherPlugin.eventSink {
                eventSinkObj(jsonString)
            }
        } catch {
            if (SwiftPusherPlugin.isLoggingEnabled) {
                print("Pusher changedConnectionState error:" + error.localizedDescription)
            }
        }
    }
}

class StreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftPusherPlugin.eventSink = events
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil;
    }
}

struct InitArgs: Codable {
    var appKey: String
    var options: Options
    var isLoggingEnabled: Bool
}

struct Options: Codable {
    var cluster: String
}

struct PusherEventStreamMessage: Codable {
    var event: Event?
    var connectionStateChange: ConnectionStateChange?
}

struct ConnectionStateChange: Codable {
    var currentState: String
    var previousState: String
}

struct Event: Codable {
    var channel: String
    var event: String
    var data: String
}

struct BindArgs: Codable {
    var channelName: String
    var eventName: String
}
