// api_services.dart
import 'dart:convert';
import 'dart:developer';
import 'package:oradosales/presentation/home/home/model/cod_history_model.dart';
import 'package:oradosales/presentation/home/home/model/home_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import '../model/cod_model.dart';
import '../model/cod_submit_model.dart'; // Import for debugPrint

class AgentHomeService {
  final String baseUrl = 'https://orado.online/backend/agent/home-data';

  Future<AgentHomeModel?> fetchAgentHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('userToken');

    if (token == null || token.isEmpty) {
      debugPrint('Error: Authentication token not found in SharedPreferences.');
      throw Exception('Authentication required. Please log in.');
    }

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});

      debugPrint('API Response Status Code: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        if (jsonBody['status'] == 'success') {
          return AgentHomeModel.fromJson(jsonBody['data']);
        } else {
          // Backend returned 200 but with a 'status' other than 'success'
          final message = jsonBody['message'] ?? 'Unknown error from server';
          debugPrint('Backend reported: $message');
          throw Exception('Failed to fetch agent home data: $message');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token. Please log in again.');
      } else if (response.statusCode == 404) {
        throw Exception('API endpoint not found.');
      } else {
        // Handle other HTTP status codes
        throw Exception('Failed to fetch agent home data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error during API call: $e");
      // Re-throw to be caught by the provider
      rethrow;
    }
  }

  Future<AgentCODModel> fetchCODData(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('userToken');

    if (token == null || token.isEmpty) {
      debugPrint('Error: Authentication token not found in SharedPreferences.');
      throw Exception('Authentication required. Please log in.');
    }

    final url = Uri.parse("https://orado-backend.onrender.com/agent/$id/cod-dashboard");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        // API directly returns JSON object
        return AgentCODModel.fromJson(jsonBody);
      } else {
        debugPrint('Error: Server responded with status code ${response.statusCode}');
        throw Exception('Failed to fetch COD data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching COD data: $e');
      throw Exception('Failed to fetch COD data: $e');
    }}



  Future<AgentCODHistoryModel> fetchCODHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('userToken');

    if (token == null || token.isEmpty) {
      debugPrint('Error: Authentication token not found in SharedPreferences.');
      throw Exception('Authentication required. Please log in.');
    }

    final url = Uri.parse("https://orado-backend.onrender.com/agent/$id/cod-history");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        // API directly returns JSON object
        return AgentCODHistoryModel.fromJson(jsonBody);
      } else {
        debugPrint('Error: Server responded with status code ${response.statusCode}');
        throw Exception('Failed to fetch COD data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching COD data: $e');
      throw Exception('Failed to fetch COD data: $e');
    }}

  Future<String> submitCOD({
    required String agentId,
    required double droppedAmount,
    required String dropMethod,
    required String dropNotes,
    // required double latitude,
    // required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('userToken');
    final url = Uri.parse("https://orado-backend.onrender.com/agent/$agentId/cod-submit");

    final body = jsonEncode({
      "droppedAmount": droppedAmount,
      "dropMethod": dropMethod,
      "dropNotes": dropNotes,
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: body,
    );

    log("Request Body: $body");
    log("Response: ${response.body}");


    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonBody = json.decode(response.body);
      return jsonBody['message'] ?? "COD submitted successfully";




    } else {
      throw Exception('Failed to submit COD: ${response.statusCode}');
    }
  }

}
