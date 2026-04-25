import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final dynamic errors;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'device_name': 'flutter-mobile',
      },
    );
  }

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _request('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _request('PUT', path, body: body);
  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);
  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _request('DELETE', path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'DELETE':
          response = await http.delete(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        default:
          throw UnsupportedError('Method $method not supported');
      }
    } on SocketException catch (error) {
      throw ApiException(
        'Falha de rede ao ligar a $uri: ${error.message}',
        errors: {'path': path, 'url': uri.toString()},
      );
    } on HandshakeException catch (error) {
      throw ApiException(
        'Falha SSL/TLS ao ligar a $uri: $error',
        errors: {'path': path, 'url': uri.toString()},
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        'Erro HTTP ao ligar a $uri: ${error.message}',
        errors: {'path': path, 'url': uri.toString()},
      );
    }

    final rawBody = response.body;
    Map<String, dynamic> json = <String, dynamic>{};

    if (rawBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        } else {
          throw const FormatException('Expected JSON object');
        }
      } on FormatException {
        throw ApiException(
          'Resposta inválida do servidor (${response.statusCode}). Verifique a URL da API.',
          statusCode: response.statusCode,
          errors: {
            'path': path,
            'response': rawBody.length > 200
                ? '${rawBody.substring(0, 200)}...'
                : rawBody,
          },
        );
      }
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        json['message']?.toString() ?? 'Erro na API.',
        statusCode: response.statusCode,
        errors: json['errors'],
      );
    }

    return json;
  }
}
