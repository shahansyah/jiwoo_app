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

  String _searchQuery = '';
  String _selectedCategoryFilter = 'Semua';

  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isLoggedIn => _userName != null && _userEmail != null;
  bool get isInitialized => _isInitialized;
  bool get isLoadingQuote => _isLoadingQuote;
  String get dailyQuote => _dailyQuote;
  String get searchQuery => _searchQuery;
  String get selectedCategoryFilter => _selectedCategoryFilter;

  List<ActivityItem> get _filteredSortedActivities {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _allActivities.where((item) {
      final matchesCategory = _selectedCategoryFilter == 'Semua' ||
          item.category == _selectedCategoryFilter;
      final matchesSearch = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.notes.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  List<ActivityItem> get activities =>
      _filteredSortedActivities.take(_visibleCount).toList(growable: false);

  bool get hasMoreActivities => _visibleCount < _filteredSortedActivities.length;
  int get totalActivitiesCount => _allActivities.length;
  int get filteredCount => _filteredSortedActivities.length;
  int get completedCount =>
      _allActivities.where((item) => item.isCompleted).length;
  int get totalFocusMinutes =>
      _allActivities.fold(0, (sum, item) => sum + item.focusMinutes);

  double get completionRate =>
      totalActivitiesCount == 0 ? 0.0 : completedCount / totalActivitiesCount;

  int get productivityStreak {
    final completedDates = _allActivities
        .where((e) => e.isCompleted)
        .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet();
    if (completedDates.isEmpty) return 0;

    int streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    while (completedDates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak == 0 ? 1 : streak;
  }

  Map<String, int> get categoryBreakdown {
    final map = <String, int>{};
    for (final item in _allActivities) {
      map[item.category] = (map[item.category] ?? 0) + 1;
    }
    return map;
  }

  ActivityItem? findById(String id) {
    for (final item in _allActivities) {
      if (item.id == id) return item;
    }
    return null;
  }

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
      final categories = ['Proyek', 'Kuliah', 'Latihan', 'Evaluasi'];
      _allActivities = List.generate(
        8,
        (index) => ActivityItem(
          id: 'seed-${index + 1}',
          title: 'Target Produktivitas #${index + 1}',
          category: categories[index % categories.length],
          notes: 'Rencana kerja terstruktur dan catatan progres sesi ke-${index + 1}.',
          isCompleted: index < 2,
          isPinned: index == 0,
          focusMinutes: index == 0 ? 25 : 0,
          createdAt: DateTime.now().subtract(Duration(hours: index * 4)),
        ),
      );
      await _persistCache();
    }

    _visibleCount = _pageSize.clamp(0, _filteredSortedActivities.length);
    _isInitialized = true;
    notifyListeners();

    await refreshQuote();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _visibleCount = _pageSize.clamp(0, _filteredSortedActivities.length);
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _selectedCategoryFilter = category;
    _visibleCount = _pageSize.clamp(0, _filteredSortedActivities.length);
    notifyListeners();
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
      body: 'Halo $_userName, workspace produktivitas kamu siap.',
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
    bool isPinned = false,
    DateTime? deadline,
  }) async {
    final validationError = validateActivityPayload(title, category, notes);
    if (validationError != null) return validationError;

    final newItem = ActivityItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      category: category.trim(),
      notes: notes.trim(),
      isPinned: isPinned,
      deadline: deadline,
      createdAt: DateTime.now(),
    );

    _allActivities.insert(0, newItem);
    _visibleCount = (_visibleCount + 1).clamp(0, _filteredSortedActivities.length);
    await _persistCache();
    notifyListeners();

    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000;
    await NotificationService.showActivityNotification(
      id: notifId,
      title: 'Aktivitas Tersimpan',
      body: '"${newItem.title}" ditambahkan ke daftar.',
    );

    if (deadline != null) {
      await NotificationService.scheduleDeadlineReminder(
        id: notifId + 1,
        title: 'Pengingat Deadline Jiwoo',
        body: 'Waktunya menyelesaikan: ${newItem.title}',
        scheduledTime: deadline,
      );
    }
    return null;
  }

  Future<String?> updateActivity({
    required String id,
    required String title,
    required String category,
    required String notes,
    required bool isCompleted,
    required bool isPinned,
    DateTime? deadline,
    bool clearDeadline = false,
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
      isPinned: isPinned,
      deadline: deadline,
      clearDeadline: clearDeadline,
    );

    if (deadline != null && !clearDeadline) {
      final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000;
      await NotificationService.scheduleDeadlineReminder(
        id: notifId,
        title: 'Pengingat Deadline Jiwoo',
        body: 'Waktunya menyelesaikan: ${title.trim()}',
        scheduledTime: deadline,
      );
    }

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

  Future<void> togglePin(String id) async {
    final index = _allActivities.indexWhere((item) => item.id == id);
    if (index == -1) return;

    _allActivities[index] = _allActivities[index].copyWith(
      isPinned: !_allActivities[index].isPinned,
    );
    await _persistCache();
    notifyListeners();
  }

  Future<void> recordFocusSession(String id, int minutes) async {
    final index = _allActivities.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final item = _allActivities[index];
    _allActivities[index] = item.copyWith(
      focusMinutes: item.focusMinutes + minutes,
    );
    await _persistCache();
    notifyListeners();

    await NotificationService.showActivityNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title: 'Sesi Fokus Selesai!',
      body: '+$minutes menit fokus tercatat untuk "${item.title}".',
    );
  }

  Future<void> deleteActivity(String id) async {
    _allActivities.removeWhere((item) => item.id == id);
    if (_visibleCount > _filteredSortedActivities.length) {
      _visibleCount = _filteredSortedActivities.length;
    }
    await _persistCache();
    notifyListeners();
  }

  void loadMoreActivities() {
    if (!hasMoreActivities) return;
    _visibleCount =
        (_visibleCount + _pageSize).clamp(0, _filteredSortedActivities.length);
    notifyListeners();
  }

  String generateMarkdownReport() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final percent = (completionRate * 100).round();
    final buffer = StringBuffer()
      ..writeln('# Laporan Progres Harian — Jiwoo')
      ..writeln('- **Pengguna:** ${_userName ?? 'Pengguna'}')
      ..writeln('- **Tanggal:** $dateStr')
      ..writeln(
          '- **Progres:** $completedCount/$totalActivitiesCount selesai ($percent%)')
      ..writeln('- **Streak:** $productivityStreak hari | **Total Fokus:** $totalFocusMinutes menit')
      ..writeln('')
      ..writeln('## Daftar Aktivitas');

    for (final item in _allActivities) {
      final box = item.isCompleted ? '[x]' : '[ ]';
      final pinTag = item.isPinned ? ' [PIN]' : '';
      buffer.writeln('- $box **${item.title}** (${item.category})$pinTag — ${item.notes}');
    }
    return buffer.toString();
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
