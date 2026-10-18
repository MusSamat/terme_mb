import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/self_user.dart';

/// Profile domain — /users/me updates, avatar upload, phone change, delete.
class ProfileService {
  ProfileService(this._dio);
  final Dio _dio;

  /// PATCH /users/me — update name / surname / bio / language / mode.
  Future<SelfUser> update({String? name, String? surname, String? bio, String? language, String? preferredMode}) async {
    final res = await _dio.patch<Map<String, dynamic>>('/users/me', data: {
      if (name != null) 'name': name,
      if (surname != null) 'surname': surname,
      if (bio != null) 'bio': bio,
      if (language != null) 'language': language,
      if (preferredMode != null) 'preferredMode': preferredMode,
    });
    return SelfUser.fromJson(res.data!);
  }

  /// POST /users/avatar — multipart image (jpeg/png). The endpoint returns just
  /// `{ avatarUrl }` (not a full user), so we return the URL and the caller
  /// merges it into the current profile.
  Future<String> uploadAvatar(File image) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        image.path,
        filename: image.path.split('/').last,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final res = await _dio.post<Map<String, dynamic>>('/users/avatar', data: form);
    return (res.data?['avatarUrl'] ?? '') as String;
  }

  /// DELETE /users/me — permanent account deletion.
  Future<void> deleteAccount() => _dio.delete('/users/me');

  /// GET /users/me/export — GDPR data export; returns the raw file bytes.
  Future<List<int>> exportData() async {
    final res = await _dio.get<List<int>>('/users/me/export',
        options: Options(responseType: ResponseType.bytes));
    return res.data ?? const [];
  }

  // ── Phone change (session + WhatsApp code to the NEW number) ─────────────
  /// PATCH /users/me/phone — sends a WhatsApp code to [newPhone] (also «resend»).
  Future<void> startPhoneChange(String newPhone) => _dio.patch('/users/me/phone', data: {'newPhone': newPhone});

  /// PATCH /users/me/phone/confirm — swaps the number; every other session is
  /// revoked and a fresh pair is issued (channel 'web' → refresh cookie).
  Future<String?> confirmPhoneChange(String newPhone, String code) async {
    final res = await _dio.patch<Map<String, dynamic>>('/users/me/phone/confirm',
        data: {'newPhone': newPhone, 'code': code, 'channel': 'web'});
    return res.data?['accessToken'] as String?;
  }
}
