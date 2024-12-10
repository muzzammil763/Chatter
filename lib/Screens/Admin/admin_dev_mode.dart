import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevModeScreen extends StatefulWidget {
  const DevModeScreen({super.key});

  @override
  State<DevModeScreen> createState() => _DevModeScreenState();
}

class _DevModeScreenState extends State<DevModeScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _sharedPrefs = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSharedPrefs();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  Future<void> _loadSharedPrefs() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final prefsMap = <String, dynamic>{};

    for (String key in keys) {
      prefsMap[key] = prefs.get(key);
    }

    setState(() {
      _sharedPrefs = prefsMap;
      _isLoading = false;
    });
  }

  Future<void> _deleteSharedPref(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await _loadSharedPrefs();
  }

  Future<void> _clearAllSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _loadSharedPrefs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.yellow,
          tilePadding: const EdgeInsets.all(8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Consola',
              fontWeight: FontWeight.bold,
            ),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Dev Mode',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSharedPrefs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.yellow),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1F1F1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'Clear All SharedPreferences',
                    style:
                        TextStyle(color: Colors.white, fontFamily: 'Consola'),
                  ),
                  content: const Text(
                    'This action cannot be undone. Are you sure?',
                    style:
                        TextStyle(color: Colors.white70, fontFamily: 'Consola'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _clearAllSharedPrefs();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildSection(
                        'SharedPreferences',
                        Icons.storage_rounded,
                        _sharedPrefs.entries.map((entry) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Consola',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        entry.value.toString(),
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontFamily: 'Consola',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _deleteSharedPref(entry.key),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      _buildSection(
                        'Network Info',
                        Icons.cloud_outlined,
                        [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Firebase API Key',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Consola',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dotenv.env['FIREBASE_API_KEY'] ?? 'Not set',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontFamily: 'Consola',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _buildSection(
                        'App Info',
                        Icons.info_outline,
                        [
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _buildInfoRow(
                                      'Package Name',
                                      snapshot.data?.packageName ??
                                          'Loading...',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      'Version',
                                      '${snapshot.data?.version ?? 'Loading...'} (${snapshot.data?.buildNumber ?? ''})',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Consola',
          ),
        ),
      ],
    );
  }
}
