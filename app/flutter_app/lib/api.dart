// lib/api.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiServiceDio {
  static const String baseUrl =
      'https://supernotable-lorenza-unsieged.ngrok-free.dev';

  final Dio dio;

  ApiServiceDio()
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            validateStatus: (code) => true,
          ),
        ) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );
  }

  // 1. Registration
  Future<int?> register(String name) async {
    final res = await dio.post('/app/registration', data: {'name': name});

    debugPrint('[REG] status=${res.statusCode} body=${res.data}');

    if (res.statusCode == 200) {
      return res.data['s_id'][0][0];
    }
    return null;
  }

  // 2. Upload
  Future<bool> upload(
      int sId, String title, String text, File imageFile) async {
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
      '/app/upload',
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

    final elapsedMs =
        DateTime.now().difference(startedAt).inMilliseconds;

    debugPrint(
        '[UPLOAD_DONE] status=${res.statusCode} elapsed=${elapsedMs}ms');
    debugPrint('[UPLOAD_DONE] body=${res.data}');

    return res.statusCode == 200;
  }

  // 3. 앱용 일기 목록 불러오기
  Future<List<Map<String, dynamic>>?> loadDiaries(int sId) async {
    final res = await dio.get('/app/load_diaries/$sId');

    debugPrint('[LOAD_DIARIES] status=${res.statusCode}');
    debugPrint('[LOAD_DIARIES] body=${res.data}');

    if (res.statusCode == 200 && res.data is List) {
      final List data = res.data as List;
      return data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return null;
  }
}
