import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/self_user.dart';

/// Profile domain — /users/me updates, avatar upload, phone change, delete.
class ProfileService {
  ProfileService(this._dio);
  final Dio _dio;

  /// PATCH /users/me — update name / bio / language.
  Future<SelfUser> update({String? name, String? bio, String? language}) async {
    final res = await _dio.patch<Map<String, dynamic>>('/users/me', data: {
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (language != null) 'language': language,
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

  // ── Phone change (start → OTP → confirm) ─────────────────────────────────
  /// PATCH /users/me/phone — re-auth with the current password, then OTP is sent.
  Future<void> startPhoneChange(String newPhone, String currentPassword) =>
      _dio.patch('/users/me/phone', data: {
        'newPhone': newPhone,
        'reAuthProof': {'provider': 'phone', 'password': currentPassword},
      });

  /// POST /users/me/phone/send-otp — (re)send the code to the new number.
  Future<void> sendPhoneOtp(String phone) =>
      _dio.post('/users/me/phone/send-otp', data: {'phone': phone});

  /// PATCH /users/me/phone/confirm — confirm with the 6-digit code.
  Future<void> confirmPhoneChange(String newPhone, String code) =>
      _dio.patch('/users/me/phone/confirm', data: {'newPhone': newPhone, 'code': code});
}
