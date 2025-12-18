import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:oradosales/presentation/api_constants/api_constants.dart';
import 'package:oradosales/presentation/auth/model/login_model.dart';
import 'package:oradosales/presentation/auth/model/reg_model.dart';
import 'package:http/http.dart' as http; // Make sure http is imported

class AgentService {
  Future<Agent> registerAgent({
    required String name,
    required String email,
    required String phone,
    required String password,
    required File license,
    required File rcBook,
    required File pollutionCertificate,
    required File profilePicture,
    required File insurance,
  }) async {
    var uri = Uri.parse(ApiConstants.registerAgent());

    var request =
        http.MultipartRequest('POST', uri)
          ..fields['name'] = name
          ..fields['email'] = email
          ..fields['phone'] = phone
          ..fields['password'] = password
          ..files.add(
            await http.MultipartFile.fromPath('license', license.path),
          )
          ..files.add(await http.MultipartFile.fromPath('rcBook', rcBook.path))
          ..files.add(
            await http.MultipartFile.fromPath(
              'pollutionCertificate',
              pollutionCertificate.path,
            ),
          )
          ..files.add(
            await http.MultipartFile.fromPath(
              'profilePicture',
              profilePicture.path,
            ),
          )
          ..files.add(
            await http.MultipartFile.fromPath('insurance', insurance.path),
          );

    try {
      log('AgentService: Sending registration request to $uri');
      log('AgentService: Request fields: ${request.fields}');
      log(
        'AgentService: Request files: ${request.files.map((f) => f.filename).toList()}',
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      log(
        'AgentService: Received response with status code: ${response.statusCode}',
      );
      // IMPORTANT: Inspect this log carefully!
      log('AgentService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseJson = jsonDecode(response.body);

        // Check for the expected key and ensure it's a Map
        Map<String, dynamic>? agentData;

        if (responseJson.containsKey('agent') &&
            responseJson['agent'] is Map<String, dynamic>) {
          agentData = responseJson['agent'];
        } else if (responseJson.containsKey('user') &&
            responseJson['user'] is Map<String, dynamic>) {
          agentData = responseJson['user'];
        } else {
          // If the agent data is directly at the root (unlikely with 'agent' or 'user' keys present)
          // Consider if the entire responseJson IS the Agent data
          // This case might be if the backend directly returns the Agent object without wrapping it
          agentData = responseJson; // Treat the whole response as agent data
          // You might want to add a more specific check here if you know your backend
          // will ONLY return the direct agent object and not other top-level keys.
        }

        if (agentData != null) {
          log('AgentService: Agent registration successful!');
          log('AgentService: Parsed agent data: $agentData');
          return Agent.fromJson(agentData); // Pass the correct map to fromJson
        } else {
          throw Exception(
            'Backend response missing expected agent/user data structure or data is null.',
          );
        }
      } else {
        log(
          'AgentService ERROR: Failed to register agent. Status Code: ${response.statusCode}',
        );
        log('AgentService ERROR: Response body: ${response.body}');
        throw Exception('Failed to register agent: ${response.body}');
      }
    } catch (e) {
      log(
        'AgentService EXCEPTION: An unexpected error occurred during registration: $e',
      );
      rethrow;
    }
  }

  Future<LoginResponse> login(String identifier, String password) async {
    final url = Uri.parse(ApiConstants.loginAgent());
    final headers = {'Content-Type': 'application/json'};
    // Some backends use `input` (or other key) instead of `identifier`.
    // Sending both keeps compatibility without breaking servers that ignore unknown fields.
    final body = jsonEncode({
      'identifier': identifier,
      'input': identifier,
      'password': password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        // If the server returns a 200 OK response, parse the JSON.
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        log('Login API Success Response: $responseData');
        return LoginResponse.fromJson(responseData);
      } else {
        // If the server did not return a 200 OK response,
        // throw an exception with the error message from the server.
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          log(
            'Login API Error Response (${response.statusCode}): $errorData',
          );
          throw Exception(errorData['message'] ?? 'Failed to login');
        } catch (_) {
          // Non-JSON error responses (HTML/plain text) shouldn't mask the real error.
          log(
            'Login API Non-JSON Error Response (${response.statusCode}): ${response.body}',
          );
          throw Exception(
            'Login failed (${response.statusCode}). Please try again.',
          );
        }
      }
    } catch (e) {
      // Handle network errors or other exceptions
      log('Login API Network/Other Error: $e');
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> logoutAgent({
    required String fcmToken,
    required String token,
  }) async {
    final url = Uri.parse('https://orado-backend.onrender.com/agent/logout');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // 🔐 Pass token in header
    };
    final body = jsonEncode({'fcmToken': fcmToken});

    try {
      final response = await http.post(url, headers: headers, body: body);
      log(
        'AgentService: Logout API response ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode != 200) {
        throw Exception('Logout failed: ${response.body}');
      }
    } catch (e) {
      log('AgentService: Logout API error: $e');
      rethrow;
    }
  }
}
