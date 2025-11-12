// lib/api.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // debugPrint

class ApiServiceDio {
  static const String baseUrl = 'https://supernotable-lorenza-unsieged.ngrok-free.dev/app';
  final Dio dio;

  ApiServiceDio()
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (code) => true,
        )) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint(obj.toString()),
    ));
  }

  // 1. Registration
  Future<int?> register(String name) async {
    final res = await dio.post('/registration', data: {'name': name});

    debugPrint('[REG] status=${res.statusCode} body=${res.data}');

    if (res.statusCode == 200) {
      return res.data['s_id'][0][0];
    }
    return null;
  }

  // 2. Upload
  Future<bool> upload(int sId, String title, String text, File imageFile) async {
    final formData = FormData.fromMap({
      's_id': sId,
      'title': title,
      'text': text,
      'img': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      ),
    });

    final startedAt = DateTime.now();

    final res = await dio.post(
      '/upload',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0) {
          final pct = (sent / total * 100).toStringAsFixed(0);
          debugPrint('[UPLOAD] $sent / $total bytes ($pct%)');
        } else {
          debugPrint('[UPLOAD] $sent bytes (total unknown)');
        }
      },
    );

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;

    // 최종 결과 요약 로그
    debugPrint('[UPLOAD_DONE] status=${res.statusCode} elapsed=${elapsedMs}ms');
    debugPrint('[UPLOAD_DONE] body=${res.data}');

    return res.statusCode == 200;
  }
}
