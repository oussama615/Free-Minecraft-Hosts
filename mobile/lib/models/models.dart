class EmpUser {
  EmpUser(this.id, this.username, this.displayName, this.role);
  final String id;
  final String username;
  final String displayName;
  final String role;
  factory EmpUser.fromJson(Map<String, dynamic> json) => EmpUser(json['id'] as String, json['username'] as String, json['displayName'] as String, json['role'] as String);
  bool get owner => role == 'OWNER';
  bool get adminOrOwner => role == 'OWNER' || role == 'ADMIN';
}

class EmpServer {
  EmpServer(this.id, this.displayName, this.status, this.snapshot, this.alerts);
  final String id;
  final String displayName;
  final String status;
  final Map<String, dynamic>? snapshot;
  final List<dynamic> alerts;
  factory EmpServer.fromJson(Map<String, dynamic> json) => EmpServer(
    json['id'] as String,
    json['displayName'] as String,
    json['status'] as String,
    json['latestSnapshot'] == null ? null : (json['latestSnapshot']['snapshot'] as Map<String, dynamic>?),
    (json['alerts'] as List<dynamic>?) ?? [],
  );
}
