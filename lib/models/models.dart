/// JSON models matching the backend contract
/// (see D:\Love-Tracking-BACKEND\PROMPT-BACKEND.md).
library;

double? _toDouble(Object? v) => v is num ? v.toDouble() : null;

class AppUser {
  const AppUser({required this.id, required this.email, required this.name, this.photoUrl});

  final String id;
  final String email;
  final String name;
  final String? photoUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        photoUrl: json['photoUrl'] as String?,
      );

  String get firstName => name.trim().isEmpty ? email : name.trim().split(' ').first;
}

class Couple {
  const Couple({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  factory Couple.fromJson(Map<String, dynamic> json) => Couple(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// battery state values: charging | discharging | full | unknown
/// network type values: wifi | mobile | ethernet | vpn | other | none
class DeviceStatus {
  const DeviceStatus({
    required this.userId,
    this.lat,
    this.lng,
    this.accuracy,
    this.speed,
    this.heading,
    this.battery,
    this.batteryState = 'unknown',
    this.networkType = 'none',
    this.carrier,
    this.mobileNetworkGen,
    this.sharingPaused = false,
    required this.updatedAt,
  });

  final String userId;
  final double? lat;
  final double? lng;
  final double? accuracy;

  /// Meters per second.
  final double? speed;
  final double? heading;
  final int? battery;
  final String batteryState;
  final String networkType;
  final String? carrier;
  final String? mobileNetworkGen;
  final bool sharingPaused;
  final DateTime updatedAt;

  bool get hasLocation => lat != null && lng != null && !sharingPaused;

  factory DeviceStatus.fromJson(Map<String, dynamic> json) => DeviceStatus(
        userId: json['userId'] as String? ?? '',
        lat: _toDouble(json['lat']),
        lng: _toDouble(json['lng']),
        accuracy: _toDouble(json['accuracy']),
        speed: _toDouble(json['speed']),
        heading: _toDouble(json['heading']),
        battery: (json['battery'] as num?)?.round(),
        batteryState: json['batteryState'] as String? ?? 'unknown',
        networkType: json['networkType'] as String? ?? 'none',
        carrier: json['carrier'] as String?,
        mobileNetworkGen: json['mobileNetworkGen'] as String?,
        sharingPaused: json['sharingPaused'] as bool? ?? false,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  /// Body for `PUT /status` (server fills userId and updatedAt).
  Map<String, dynamic> toUploadJson() => {
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'battery': battery,
        'batteryState': batteryState,
        'networkType': networkType,
        'carrier': carrier,
        'mobileNetworkGen': mobileNetworkGen,
        'sharingPaused': sharingPaused,
      };

  /// Used to pass the local status from the background isolate to the UI.
  Map<String, dynamic> toJson() => {
        ...toUploadJson(),
        'userId': userId,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

class Invite {
  const Invite({required this.code, required this.expiresAt, required this.link});

  final String code;
  final DateTime expiresAt;
  final String link;

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
        link: json['link'] as String,
      );
}

class Session {
  const Session({
    required this.user,
    this.couple,
    this.partner,
    this.partnerStatus,
    this.myStatus,
  });

  final AppUser user;
  final Couple? couple;
  final AppUser? partner;
  final DeviceStatus? partnerStatus;
  final DeviceStatus? myStatus;

  bool get isPaired => couple != null && partner != null;

  factory Session.fromMeJson(Map<String, dynamic> json) {
    Map<String, dynamic>? obj(String key) => json[key] as Map<String, dynamic>?;
    return Session(
      user: AppUser.fromJson(obj('user')!),
      couple: obj('couple') == null ? null : Couple.fromJson(obj('couple')!),
      partner: obj('partner') == null ? null : AppUser.fromJson(obj('partner')!),
      partnerStatus: obj('partnerStatus') == null ? null : DeviceStatus.fromJson(obj('partnerStatus')!),
      myStatus: obj('myStatus') == null ? null : DeviceStatus.fromJson(obj('myStatus')!),
    );
  }

  /// Applies a `{ couple, partner, partnerStatus }` payload (accept response / couple-paired event).
  Session paired(Map<String, dynamic> json) => Session(
        user: user,
        myStatus: myStatus,
        couple: Couple.fromJson(json['couple'] as Map<String, dynamic>),
        partner: AppUser.fromJson(json['partner'] as Map<String, dynamic>),
        partnerStatus: json['partnerStatus'] == null
            ? null
            : DeviceStatus.fromJson(json['partnerStatus'] as Map<String, dynamic>),
      );

  Session unpaired() => Session(user: user);

  Session withPartnerStatus(DeviceStatus status) => Session(
        user: user,
        couple: couple,
        partner: partner,
        partnerStatus: status,
        myStatus: myStatus,
      );
}
