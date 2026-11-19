import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_item.dart';
import '../services/notification_service.dart';
import '../services/quote_api_service.dart';

class AppProvider extends ChangeNotifier {
  static const String _userKey = 'jiwoo_user_session';
  static const String _activitiesCacheKey = 'jiwoo_activities_cache';
  static const int _pageSize = 6;

  final QuoteApiService _quoteService = QuoteApiService();

  String? _userName;
  String? _userEmail;
  List<ActivityItem> _allActivities = [];
  int _visibleCount = _pageSize;
  String _dailyQuote = 'Memuat kutipan harian...';
  bool _isLoadingQuote = false;
  bool _isInitialized = false;

  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isLoggedIn => _userName != null && _userEmail != null;
  bool get isInitialized => _isInitialized;
  bool get isLoadingQuote => _isLoadingQuote;
  String get dailyQuote => _dailyQuote;

  List<ActivityItem> get activities =>
      _allActivities.take(_visibleCount).toList(growable: false);

  bool get hasMoreActivities => _visibleCount < _allActivities.length;
  int get totalActivitiesCount => _allActivities.length;

  Future<void> initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_userKey);
    if (rawUser != null) {
      final decoded = jsonDecode(rawUser) as Map<String, dynamic>;
      _userName = decoded['name'] as String?;
      _userEmail = decoded['email'] as String?;
    }

    final rawCache = prefs.getStringList(_activitiesCacheKey);
    if (rawCache != null && rawCache.isNotEmpty) {
      _allActivities = rawCache.map((e) => ActivityItem.fromJson(e)).toList();
    } else {
      _allActivities = List.generate(
        10,
        (index) => ActivityItem(
          id: 'seed-${index + 1}',
          title: 'Target Rutinitas #${index + 1}',
          category: index % 2 == 0 ? 'Proyek' : 'Evaluasi',
          notes: 'Catatan progres dan evaluasi langkah harian ke-${index + 1}.',
          isCompleted: index == 0,
          createdAt: DateTime.now().subtract(Duration(hours: index * 3)),
        ),
      );
      await _persistCache();
    }

    _visibleCount = _pageSize.clamp(0, _allActivities.length);
    _isInitialized = true;
    notifyListeners();

    await refreshQuote();
  }

  String? validateLogin(String name, String email) {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.length < 2) {
      return 'Nama minimal terdiri dari 2 karakter.';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  Future<String?> login(String name, String email) async {
    final error = validateLogin(name, email);
    if (error != null) return error;

    _userName = name.trim();
    _userEmail = email.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userKey,
      jsonEncode({'name': _userName, 'email': _userEmail}),
    );

    notifyListeners();
    await NotificationService.showActivityNotification(
      id: 101,
      title: 'Selamat Datang di Jiwoo',
      body: 'Halo $_userName, sesi login kamu aktif.',
    );
    return null;
  }

  Future<void> logout() async {
    _userName = null;
    _userEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    notifyListeners();
  }

  String? validateActivityPayload(String title, String category, String notes) {
    if (title.trim().length < 3) {
      return 'Judul aktivitas wajib diisi minimal 3 karakter.';
    }
    if (category.trim().isEmpty) {
      return 'Kategori aktivitas wajib dipilih.';
    }
    if (notes.trim().length < 4) {
      return 'Catatan aktivitas minimal 4 karakter.';
    }
    return null;
  }

  Future<String?> addActivity({
    required String title,
    required String category,
    required String notes,
  }) async {
    final validationError = validateActivityPayload(title, category, notes);
    if (validationError != null) return validationError;

    final newItem = ActivityItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      category: category.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );

    _allActivities.insert(0, newItem);
    _visibleCount = (_visibleCount + 1).clamp(0, _allActivities.length);
    await _persistCache();
    notifyListeners();

    await NotificationService.showActivityNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title: 'Aktivitas Tersimpan',
      body: '"${newItem.title}" ditambahkan ke daftar.',
    );
    return null;
  }

  Future<String?> updateActivity({
    required String id,
    required String title,
    required String category,
    required String notes,
    required bool isCompleted,
  }) async {
    final validationError = validateActivityPayload(title, category, notes);
    if (validationError != null) return validationError;

    final index = _allActivities.indexWhere((item) => item.id == id);
    if (index == -1) return 'Data aktivitas tidak ditemukan.';

    _allActivities[index] = _allActivities[index].copyWith(
      title: title.trim(),
      category: category.trim(),
      notes: notes.trim(),
      isCompleted: isCompleted,
    );

    await _persistCache();
    notifyListeners();
    return null;
  }

  Future<void> toggleComplete(String id) async {
    final index = _allActivities.indexWhere((item) => item.id == id);
    if (index == -1) return;

    _allActivities[index] = _allActivities[index].copyWith(
      isCompleted: !_allActivities[index].isCompleted,
    );
    await _persistCache();
    notifyListeners();
  }

  Future<void> deleteActivity(String id) async {
    _allActivities.removeWhere((item) => item.id == id);
    if (_visibleCount > _allActivities.length) {
      _visibleCount = _allActivities.length;
    }
    await _persistCache();
    notifyListeners();
  }

  void loadMoreActivities() {
    if (!hasMoreActivities) return;
    _visibleCount = (_visibleCount + _pageSize).clamp(0, _allActivities.length);
    notifyListeners();
  }

  Future<void> refreshQuote() async {
    _isLoadingQuote = true;
    notifyListeners();
    _dailyQuote = await _quoteService.fetchDailyQuote();
    _isLoadingQuote = false;
    notifyListeners();
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _activitiesCacheKey,
      _allActivities.map((e) => e.toJson()).toList(),
    );
  }
}
