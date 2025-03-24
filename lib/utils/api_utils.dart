// lib/utils/api_utils.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });
}

class ApiUtils {
  static const String baseUrl = 'https://api.turikumwe.rw/api';
  static const int timeoutSeconds = 30;

  /// Execute a GET request
  static Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint').replace(
        queryParameters: queryParams,
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: timeoutSeconds));

      return _processResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'An error occurred: ${e.toString()}',
      );
    }
  }

  /// Execute a POST request
  static Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      return _processResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'An error occurred: ${e.toString()}',
      );
    }
  }

  /// Execute a PUT request
  static Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      return _processResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'An error occurred: ${e.toString()}',
      );
    }
  }

  /// Execute a DELETE request
  static Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await http
          .delete(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      return _processResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'An error occurred: ${e.toString()}',
      );
    }
  }

  /// Process the HTTP response
  static ApiResponse<T> _processResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJson,
  ) {
    try {
      final statusCode = response.statusCode;
      final hasResponse = response.body.isNotEmpty;
      final responseJson = hasResponse ? jsonDecode(response.body) : null;

      if (statusCode >= 200 && statusCode < 300) {
        return ApiResponse(
          success: true,
          message: 'Success',
          statusCode: statusCode,
          data: fromJson != null && responseJson != null
              ? fromJson(responseJson)
              : responseJson as T?,
        );
      } else {
        final message = responseJson != null && responseJson['message'] != null
            ? responseJson['message']
            : 'Request failed with status: $statusCode';

        return ApiResponse(
          success: false,
          message: message,
          statusCode: statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error processing response: ${e.toString()}',
        statusCode: response.statusCode,
      );
    }
  }
}
