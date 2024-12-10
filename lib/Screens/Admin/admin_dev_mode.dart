import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevModeScreen extends StatefulWidget {
  const DevModeScreen({super.key});

  @override
  State<DevModeScreen> createState() => _DevModeScreenState();
}

class _DevModeScreenState extends State<DevModeScreen> {
  Map<String, dynamic> _sharedPrefs = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSharedPrefs();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadSharedPrefs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1F1F1F),
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
                      child: const Text('Cancel'),
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
          : ListView(
              children: [
                ExpansionTile(
                  title: const Text(
                    'SharedPreferences',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                    ),
                  ),
                  collapsedBackgroundColor: const Color(0xFF1A1A1A),
                  backgroundColor: const Color(0xFF1A1A1A),
                  children: _sharedPrefs.entries.map((entry) {
                    return ListTile(
                      title: Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Consola',
                        ),
                      ),
                      subtitle: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontFamily: 'Consola',
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSharedPref(entry.key),
                      ),
                    );
                  }).toList(),
                ),

                // Additional Dev Tools
                ExpansionTile(
                  title: const Text(
                    'Network Info',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                    ),
                  ),
                  collapsedBackgroundColor: const Color(0xFF1A1A1A),
                  backgroundColor: const Color(0xFF1A1A1A),
                  children: [
                    ListTile(
                      title: const Text(
                        'API Base URL',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Consola',
                        ),
                      ),
                      subtitle: Text(
                        dotenv.env['API_URL'] ?? 'Not set',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontFamily: 'Consola',
                        ),
                      ),
                    ),
                  ],
                ),

                ExpansionTile(
                  title: const Text(
                    'App Info',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Consola',
                    ),
                  ),
                  collapsedBackgroundColor: const Color(0xFF1A1A1A),
                  backgroundColor: const Color(0xFF1A1A1A),
                  children: [
                    ListTile(
                      title: const Text(
                        'Package Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Consola',
                        ),
                      ),
                      subtitle: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data?.packageName ?? 'Loading...',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontFamily: 'Consola',
                            ),
                          );
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text(
                        'Version',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Consola',
                        ),
                      ),
                      subtitle: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          return Text(
                            '${snapshot.data?.version ?? 'Loading...'} (${snapshot.data?.buildNumber ?? ''})',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontFamily: 'Consola',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // Add more tools as needed
              ],
            ),
    );
  }
}
