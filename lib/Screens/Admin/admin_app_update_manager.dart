import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      final DatabaseReference ref = FirebaseDatabase.instance.ref('appUpdate');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          _latestVersionController.text = data['latestVersion'] ?? '';
          _latestVersionCodeController.text =
              data['latestVersionCode']?.toString() ?? '';
          _minSupportedVersionController.text =
              data['minSupportedVersion'] ?? '';
          _urlController.text = data['url'] ?? '';

          // Load what's new items
          if (data['whatsNew'] != null && data['whatsNew'] is Map) {
            final whatsNew = data['whatsNew'] as Map<dynamic, dynamic>;
            _whatsNewControllers.clear();
            whatsNew.forEach((key, value) {
              _whatsNewControllers
                  .add(TextEditingController(text: value.toString()));
            });
          }
        } else {
          _showErrorSnackBar('Unexpected data format in app update');
        }
      } else {
        _showErrorSnackBar('No app update data found');
      }
    } catch (e) {
      print('Error loading app update: $e'); // Add detailed error logging
      _showErrorSnackBar('Error loading app update data: ${e.toString()}');
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

      await FirebaseDatabase.instance.ref('appUpdate').update({
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
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Consola'),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Consola'),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Consola',
          fontSize: 16,
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        cursorColor: Colors.white,
        cursorWidth: 1,
        cursorRadius: const Radius.circular(1),
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperStyle: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Consola',
          ),
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Consola',
            fontSize: 14,
          ),
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
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Consola',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF121212),
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
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                              'Version Information', Icons.update),
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
                                  helperText: 'e.g., 1.0.2',
                                ),
                                _buildTextField(
                                  'Latest Version Code',
                                  _latestVersionCodeController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  helperText: 'Integer value (e.g., 3)',
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
                                  helperText: 'e.g., 1.0.0',
                                ),
                                _buildTextField(
                                  'Download URL',
                                  _urlController,
                                  keyboardType: TextInputType.url,
                                  helperText: 'Full URL to the APK file',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle("What's New", Icons.new_releases),
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
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.add, size: 20),
                                      label: const Text('Add Change'),
                                      onPressed: _addNewWhatsNewItem,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
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
                                            helperText:
                                                'Describe the change or feature',
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
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _saveAppUpdate,
                              child: const Text(
                                'S A V E',
                                style: TextStyle(
                                  fontFamily: 'Consola',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
