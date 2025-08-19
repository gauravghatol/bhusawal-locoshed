import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/loco_firebase_service.dart';
import '../services/authentication_manager.dart';
import 'components/loco_shed_view.dart';

class LocoShedPage extends StatefulWidget {
  const LocoShedPage({super.key});

  @override
  State<LocoShedPage> createState() => _LocoShedPageState();
}

class _LocoShedPageState extends State<LocoShedPage> {
  final Map<String, TextEditingController> _controllers = {};
  bool _useFirebase = false;
  bool _isLoading = true;
  Map<String, String> _dataFromFirebase = {};
  final Map<String, String> _pendingUpdates = {};
  bool _hasUnsavedChanges = false;
  bool _isUpdatingFromFirebase = false;
  bool _isViewer = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseServices();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeFirebaseServices() async {
    try {
      _useFirebase = true;

      // Authentication is already done globally, just check if user can edit
      setState(() {
        _isViewer = !AuthenticationManager.canEdit;
      });

      _initializeFirebaseStreams();

      // Set a timeout to stop loading if no data comes in 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
          debugPrint(
            'Firebase initialization timed out - proceeding without data',
          );
        }
      });

      debugPrint('Firebase services initialized - Viewer mode: $_isViewer');
    } catch (e) {
      debugPrint('Firebase setup failed: $e');
      _useFirebase = false;
      setState(() => _isLoading = false);
      _showFirebaseErrorDialog(e.toString());
    }
  }

  void _initializeFirebaseStreams() {
    LocoFirebaseService.getDataStream().listen(
      (data) {
        if (mounted) {
          setState(() {
            _dataFromFirebase = data;
            _isLoading =
                false; // Stop loading as soon as we get any data (even empty)
          });
          _updateControllersFromFirebase(data);
        }
      },
      onError: (error) {
        debugPrint('Firebase stream error: $error');
        if (mounted) {
          setState(() => _isLoading = false); // Stop loading on error too
          _showFirebaseErrorDialog('Connection lost: $error');
        }
      },
    );
  }

  void _onFieldChanged(String key) {
    if (_isViewer || _isUpdatingFromFirebase) return;

    final newValue = _controllers[key]?.text ?? '';
    final currentValue = _dataFromFirebase[key] ?? '';

    setState(() {
      if (newValue != currentValue) {
        _pendingUpdates[key] = newValue;
        _hasUnsavedChanges = true;
      } else {
        _pendingUpdates.remove(key);
        _hasUnsavedChanges = _pendingUpdates.isNotEmpty;
      }
    });

    if (_useFirebase && !_isViewer) {
      _debouncedSave();
    }
  }

  void _updateControllersFromFirebase(Map<String, String> data) {
    if (_isUpdatingFromFirebase) return;
    _isUpdatingFromFirebase = true;
    for (String key in data.keys) {
      if (!_controllers.containsKey(key)) {
        final controller = TextEditingController();
        controller.addListener(() => _onFieldChanged(key));
        _controllers[key] = controller;
      }
      if (!_pendingUpdates.containsKey(key)) {
        _controllers[key]!.text = data[key] ?? '';
      }
    }
    _isUpdatingFromFirebase = false;
  }

  Future<void> _saveData() async {
    if (!_useFirebase || _pendingUpdates.isEmpty) return;
    try {
      await LocoFirebaseService.batchUpdatePositions(_pendingUpdates);
      setState(() {
        _pendingUpdates.clear();
        _hasUnsavedChanges = false;
      });
    } catch (e) {
      _showFirebaseErrorDialog('Save failed: $e');
    }
  }

  void _debouncedSave() {
    // Cancel the previous timer if it exists
    _debounceTimer?.cancel();

    // Start a new timer for 1.5 seconds
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveData();
    });
  }

  void _showFirebaseErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login to Edit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AuthenticationManager.signInWithEmailAndPassword(
                  emailController.text.trim(),
                  passwordController.text,
                );
                setState(() {
                  _isViewer = !AuthenticationManager.canEdit;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged in successfully! You can now edit.'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFF22223B);
    const Color appBarColor = Color(0xFFE43636);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isViewer ? 'Loco Shed (View Only)' : 'Loco Shed',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 32,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          if (_isViewer)
            IconButton(
              icon: const Icon(Icons.login, color: Colors.white, size: 32),
              tooltip: 'Login to Edit',
              onPressed: _showLoginDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white, size: 32),
              tooltip: 'Save',
              onPressed: _saveData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LocoShedView(
              controllers: _controllers,
              dataFromFirebase: _dataFromFirebase,
              pendingUpdates: _pendingUpdates,
              hasUnsavedChanges: _hasUnsavedChanges,
              useFirebase: _useFirebase,
              onFieldChanged: _onFieldChanged,
              onSave: _saveData,
              isViewer: _isViewer,
            ),
    );
  }
}
