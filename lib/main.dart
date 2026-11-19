import 'package:flutter/material.dart';
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
      title: 'Jiwoo Tracker',
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
                    'Jiwoo Daily Planner',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final items = provider.activities;

    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${provider.userName ?? 'Pengguna'}'),
        actions: [
          IconButton(
            tooltip: 'Perbarui Kutipan API',
            onPressed: provider.isLoadingQuote ? null : provider.refreshQuote,
            icon: const Icon(Icons.format_quote),
          ),
          IconButton(
            tooltip: 'Profil & Logout',
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
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
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
                            'Menampilkan ${items.length} dari ${provider.totalActivitiesCount} aktivitas',
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
                  title: Text(
                    item.title,
                    style: TextStyle(
                      decoration:
                          item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text('${item.category} • ${item.notes}'),
                  trailing: const Icon(Icons.chevron_right),
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final provider = context.read<AppProvider>();
    final String? err;

    if (widget.existingItem == null) {
      err = await provider.addActivity(
        title: _titleController.text,
        category: _selectedCategory,
        notes: _notesController.text,
      );
    } else {
      err = await provider.updateActivity(
        id: widget.existingItem!.id,
        title: _titleController.text,
        category: _selectedCategory,
        notes: _notesController.text,
        isCompleted: _isCompleted,
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
            if (isEdit) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Tandai Selesai'),
                value: _isCompleted,
                onChanged: (v) => setState(() => _isCompleted = v),
              ),
            ],
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

class ActivityDetailPage extends StatelessWidget {
  final String activityId;

  const ActivityDetailPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    ActivityItem? item;
    for (final a in provider.activities) {
      if (a.id == activityId) {
        item = a;
        break;
      }
    }

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Aktivitas')),
        body: const Center(child: Text('Aktivitas tidak ditemukan.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Aktivitas'),
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
              await provider.deleteActivity(item!.id);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Kategori: ${item.category}'),
            const SizedBox(height: 8),
            Text('Status: ${item.isCompleted ? 'Selesai' : 'Berjalan'}'),
            const SizedBox(height: 16),
            const Text('Catatan:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(item.notes),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pengguna')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nama: ${provider.userName ?? '-'}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Email: ${provider.userEmail ?? '-'}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Total Aktivitas Tersimpan: ${provider.totalActivitiesCount}'),
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
