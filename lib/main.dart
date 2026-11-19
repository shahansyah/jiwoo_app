import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/activity_item.dart';
import 'providers/app_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  final provider = AppProvider();
  await provider.initApp();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const JiwooApp(),
    ),
  );
}

class JiwooApp extends StatelessWidget {
  const JiwooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jiwoo Smart Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Consumer<AppProvider>(
        builder: (context, auth, _) {
          if (!auth.isInitialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return auth.isLoggedIn ? const HomePage() : const LoginPage();
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _errorMessage;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _submitting = true;
    });

    final error = await context
        .read<AppProvider>()
        .login(_nameController.text, _emailController.text);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _errorMessage = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk — Jiwoo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.track_changes,
                      size: 56, color: Colors.indigo),
                  const SizedBox(height: 12),
                  const Text(
                    'Jiwoo Smart Planner',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Catatan harian dengan Pomodoro Timer, Pengingat Jadwal, dan Statistik Progres',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _handleLogin,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = [
    'Semua',
    'Proyek',
    'Kuliah',
    'Latihan',
    'Evaluasi',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 120) {
        context.read<AppProvider>().loadMoreActivities();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }

  Future<void> _exportReport(BuildContext context, AppProvider provider) async {
    final report = provider.generateMarkdownReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan progres harian disalin ke clipboard (Markdown)!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final items = provider.activities;
    final percent = (provider.completionRate * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${provider.userName ?? 'Pengguna'}'),
        actions: [
          IconButton(
            tooltip: 'Salin Laporan Harian',
            onPressed: () => _exportReport(context, provider),
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: 'Perbarui Kutipan API',
            onPressed: provider.isLoadingQuote ? null : provider.refreshQuote,
            icon: const Icon(Icons.format_quote),
          ),
          IconButton(
            tooltip: 'Profil & Statistik',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 600 ? 32.0 : 16.0;
          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: 16),
            itemCount: items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dashboard Statistik & Streak
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Ringkasan Produktivitas',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.local_fire_department,
                                      size: 16, color: Colors.deepOrange),
                                  label: Text(
                                      'Streak ${provider.productivityStreak} Hari'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: provider.completionRate,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Selesai: ${provider.completedCount}/${provider.totalActivitiesCount} ($percent%) • Total Fokus: ${provider.totalFocusMinutes} menit',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Kutipan API
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kutipan Harian (Public API)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            provider.isLoadingQuote
                                ? const LinearProgressIndicator()
                                : Text(provider.dailyQuote),
                          ],
                        ),
                      ),
                    ),

                    // Pencarian Real-time
                    TextField(
                      controller: _searchController,
                      onChanged: provider.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Cari judul, catatan, atau kategori...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: provider.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.setSearchQuery('');
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter Kategori
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterOptions.map((cat) {
                          final selected =
                              provider.selectedCategoryFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: selected,
                              onSelected: (_) => provider.setCategoryFilter(cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }

              if (index == items.length + 1) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: provider.hasMoreActivities
                        ? FilledButton.tonal(
                            onPressed: provider.loadMoreActivities,
                            child: const Text('Muat Lebih Banyak (Pagination)'),
                          )
                        : Text(
                            'Menampilkan ${items.length} dari ${provider.filteredCount} aktivitas',
                          ),
                  ),
                );
              }

              final item = items[index - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Checkbox(
                    value: item.isCompleted,
                    onChanged: (_) => provider.toggleComplete(item.id),
                  ),
                  title: Row(
                    children: [
                      if (item.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.push_pin,
                              size: 16, color: Colors.indigo),
                        ),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.category} • ${item.notes}'),
                      if (item.deadline != null || item.focusMinutes > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (item.deadline != null)
                                Text(
                                  'Deadline: ${_formatDateTime(item.deadline!)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.deepOrange),
                                ),
                              if (item.focusMinutes > 0)
                                Text(
                                  'Fokus: ${item.focusMinutes}m',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.teal),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: item.isPinned ? 'Lepas Pin' : 'Sematkan Prioritas',
                    icon: Icon(
                      item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: item.isPinned ? Colors.indigo : null,
                    ),
                    onPressed: () => provider.togglePin(item.id),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailPage(activityId: item.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddActivityPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}

class AddActivityPage extends StatefulWidget {
  final ActivityItem? existingItem;

  const AddActivityPage({super.key, this.existingItem});

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final List<String> _categories = ['Proyek', 'Kuliah', 'Latihan', 'Evaluasi'];
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late String _selectedCategory;
  late bool _isCompleted;
  late bool _isPinned;
  DateTime? _selectedDeadline;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingItem?.title ?? '');
    _notesController =
        TextEditingController(text: widget.existingItem?.notes ?? '');
    _selectedCategory = widget.existingItem?.category ?? 'Proyek';
    _isCompleted = widget.existingItem?.isCompleted ?? false;
    _isPinned = widget.existingItem?.isPinned ?? false;
    _selectedDeadline = widget.existingItem?.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedDeadline ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;

    setState(() {
      _selectedDeadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveForm() async {
    final provider = context.read<AppProvider>();
    final String? err;

    if (widget.existingItem == null) {
      err = await provider.addActivity(
        title: _titleController.text,
        category: _selectedCategory,
        notes: _notesController.text,
        isPinned: _isPinned,
        deadline: _selectedDeadline,
      );
    } else {
      err = await provider.updateActivity(
        id: widget.existingItem!.id,
        title: _titleController.text,
        category: _selectedCategory,
        notes: _notesController.text,
        isCompleted: _isCompleted,
        isPinned: _isPinned,
        deadline: _selectedDeadline,
        clearDeadline: _selectedDeadline == null,
      );
    }

    if (!mounted) return;
    if (err != null) {
      setState(() => _errorText = err);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Aktivitas' : 'Tambah Aktivitas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Aktivitas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Sematkan di Paling Atas (Pin Prioritas)'),
              value: _isPinned,
              onChanged: (v) => setState(() => _isPinned = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text(
                _selectedDeadline == null
                    ? 'Atur Pengingat Deadline (Opsional)'
                    : 'Deadline: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year} ${_selectedDeadline!.hour.toString().padLeft(2, '0')}:${_selectedDeadline!.minute.toString().padLeft(2, '0')}',
              ),
              trailing: _selectedDeadline != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedDeadline = null),
                    )
                  : null,
              onTap: _pickDeadline,
            ),
            if (isEdit)
              SwitchListTile(
                title: const Text('Tandai Selesai'),
                value: _isCompleted,
                onChanged: (v) => setState(() => _isCompleted = v),
              ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saveForm,
              child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Aktivitas'),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityDetailPage extends StatefulWidget {
  final String activityId;

  const ActivityDetailPage({super.key, required this.activityId});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  static const int _defaultSeconds = 25 * 60;
  int _remainingSeconds = _defaultSeconds;
  Timer? _timer;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer(ActivityItem item) {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }

    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _isRunning = false;
          _remainingSeconds = _defaultSeconds;
        });
        await context.read<AppProvider>().recordFocusSession(item.id, 25);
      } else {
        if (!mounted) return;
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _defaultSeconds;
    });
  }

  String _formatClock(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final item = provider.findById(widget.activityId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Aktivitas')),
        body: const Center(child: Text('Aktivitas tidak ditemukan.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail & Focus Timer'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddActivityPage(existingItem: item),
                ),
              );
            },
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: 'Hapus',
            onPressed: () async {
              await provider.deleteActivity(item.id);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Kategori: ${item.category} • Prioritas: ${item.isPinned ? 'Dipin' : 'Normal'}'),
            const SizedBox(height: 6),
            Text('Status: ${item.isCompleted ? 'Selesai' : 'Berjalan'} • Total Fokus: ${item.focusMinutes} menit'),
            const SizedBox(height: 16),
            const Text('Catatan:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(item.notes),
            const SizedBox(height: 24),

            // Smart Focus Timer (Pomodoro)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text(
                      'Smart Focus Timer (Pomodoro 25 Menit)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatClock(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _toggleTimer(item),
                          icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                          label: Text(_isRunning ? 'Jeda' : 'Mulai Fokus'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _resetTimer,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          provider.recordFocusSession(item.id, 25),
                      child: const Text('Catat +25 Menit Fokus Manual'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final breakdown = provider.categoryBreakdown;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Statistik')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nama: ${provider.userName ?? '-'}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text('Email: ${provider.userEmail ?? '-'}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Distribusi Kategori Aktivitas:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...breakdown.entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                trailing: Text('${entry.value} item'),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                await provider.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
