import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AppUpdateManagerScreen extends StatefulWidget {
  const AppUpdateManagerScreen({super.key});

  @override
  State<AppUpdateManagerScreen> createState() => _AppUpdateManagerScreenState();
}

class _AppUpdateManagerScreenState extends State<AppUpdateManagerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _latestVersionController = TextEditingController();
  final _latestVersionCodeController = TextEditingController();
  final _minSupportedVersionController = TextEditingController();
  final _urlController = TextEditingController();
  final List<TextEditingController> _whatsNewControllers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCurrentAppUpdate();
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

  Future<void> _loadCurrentAppUpdate() async {
    setState(() => _isLoading = true);
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref().child('appUpdate').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        _latestVersionController.text = data['latestVersion'] ?? '';
        _latestVersionCodeController.text =
            data['latestVersionCode']?.toString() ?? '';
        _minSupportedVersionController.text = data['minSupportedVersion'] ?? '';
        _urlController.text = data['url'] ?? '';

        // Load what's new items
        if (data['whatsNew'] != null) {
          final whatsNew = data['whatsNew'] as Map<dynamic, dynamic>;
          _whatsNewControllers.clear();
          whatsNew.forEach((key, value) {
            _whatsNewControllers
                .add(TextEditingController(text: value.toString()));
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error loading app update data');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAppUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final whatsNewMap = <String, String>{};
      for (int i = 0; i < _whatsNewControllers.length; i++) {
        whatsNewMap[i.toString()] = _whatsNewControllers[i].text;
      }

      await FirebaseDatabase.instance.ref().child('appUpdate').set({
        'latestVersion': _latestVersionController.text,
        'latestVersionCode': int.parse(_latestVersionCodeController.text),
        'minSupportedVersion': _minSupportedVersionController.text,
        'url': _urlController.text,
        'whatsNew': whatsNewMap,
      });

      _showSuccessSnackBar('App update information saved successfully');
    } catch (e) {
      _showErrorSnackBar('Error saving app update data');
    }
    setState(() => _isLoading = false);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addNewWhatsNewItem() {
    setState(() {
      _whatsNewControllers.add(TextEditingController());
    });
  }

  void _removeWhatsNewItem(int index) {
    setState(() {
      _whatsNewControllers[index].dispose();
      _whatsNewControllers.removeAt(index);
    });
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String? Function(String?)? validator}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
        ),
        validator: validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'App Update Manager',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadCurrentAppUpdate,
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  'Latest Version',
                                  _latestVersionController,
                                ),
                                _buildTextField(
                                  'Latest Version Code',
                                  _latestVersionCodeController,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'This field is required';
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Please enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                                _buildTextField(
                                  'Minimum Supported Version',
                                  _minSupportedVersionController,
                                ),
                                _buildTextField(
                                  'Download URL',
                                  _urlController,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "What's New",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Consola',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add,
                                          color: Colors.blue),
                                      onPressed: _addNewWhatsNewItem,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ..._whatsNewControllers
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final controller = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            'Change ${index + 1}',
                                            controller,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _removeWhatsNewItem(index),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveAppUpdate,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.save),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _latestVersionController.dispose();
    _latestVersionCodeController.dispose();
    _minSupportedVersionController.dispose();
    _urlController.dispose();
    for (var controller in _whatsNewControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
