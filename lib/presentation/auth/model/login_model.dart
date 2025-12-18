class LoginAgent {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? profilePicture;
  final String role;
  final String applicationStatus;

  LoginAgent({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profilePicture,
    required this.role,
    required this.applicationStatus,
  });

  factory LoginAgent.fromJson(Map<String, dynamic> json) {
    return LoginAgent(
      id: (json['_id'] ?? json['id'] ?? json['agentId'] ?? '').toString(),
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: (json['phoneNumber'] ?? json['phone'] ?? '').toString(),
      profilePicture: json['profilePicture'],
      role: json['role'] ?? '',
      applicationStatus: json['applicationStatus'] ?? '',
    );
  }
}

class LoginResponse {
  final int statusCode;
  final String message;
  final String token;
  final LoginAgent agent;

  LoginResponse({
    required this.statusCode,
    required this.message,
    required this.token,
    required this.agent,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final dynamic rawAgent =
        json['agent'] ??
        json['user'] ??
        json['data'] ??
        json['profile'];

    final Map<String, dynamic> agentMap =
        rawAgent is Map<String, dynamic> ? rawAgent : <String, dynamic>{};

    return LoginResponse(
      statusCode: json['statusCode'] ?? 200,
      message: json['message'] ?? '',
      token: json['token'] ?? '',
      agent: LoginAgent.fromJson(agentMap),
    );
  }
}
