import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/loco_firebase_service.dart';
import '../services/authentication_manager.dart';
import 'components/todays_outage_view.dart';

// A simple data class to hold the data for a single row.
class TableRowData {
  List<String> cells;
  TableRowData({required this.cells});
}

class TodaysOutagePage extends StatefulWidget {
  const TodaysOutagePage({super.key});

  @override
  State<TodaysOutagePage> createState() => _TodaysOutagePageState();
}

class _TodaysOutagePageState extends State<TodaysOutagePage> {
  // Firebase integration variables
  final Map<String, TextEditingController> _controllers = {};
  bool _useFirebase = false;
  bool _isLoading = true;
  Map<String, String> _dataFromFirebase = {};
  final Map<String, String> _pendingUpdates = {};
  bool _hasUnsavedChanges = false;
  bool _isUpdatingFromFirebase = false;
  bool _isViewer = false;
  Timer? _debounceTimer;
  int _rebuildCounter = 0; // Force child widget to rebuild

  // State variable to hold the current scale/zoom factor of the table.
  double _scaleFactor = 1.0;

  // State variable to hold the list of data rows for the table (keeping for compatibility).
  final List<TableRowData> _dataRows = [
    TableRowData(cells: ["COG\n(71)", "64.00", "90.14", "63.80", "89.85"]),
    TableRowData(cells: ["GOODS\n(160)", "135.70", "84.81", "147.30", "92.06"]),
  ];

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
      bool canEdit = AuthenticationManager.canEdit;

      setState(() {
        _isViewer = !canEdit;
      });

      _initializeFirebaseStreams();

      // Set a timeout to stop loading if no data comes in 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
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
            _isLoading = false;
          });
          _updateControllersFromFirebase(data);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
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

  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveData();
    });
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

  Future<void> _deleteRowFromFirebase(
    String rowKey,
    List<String> colKeys,
  ) async {
    if (!_useFirebase) return;

    try {
      List<String> fieldKeysToDelete = [];
      fieldKeysToDelete.add('${rowKey}_label');
      for (String colKey in colKeys) {
        fieldKeysToDelete.add('${rowKey}_$colKey');
      }

      await LocoFirebaseService.deleteRowFields(fieldKeysToDelete);

      // Also remove from local data
      setState(() {
        for (String fieldKey in fieldKeysToDelete) {
          _dataFromFirebase.remove(fieldKey);
          _pendingUpdates.remove(fieldKey);
        }
      });
    } catch (e) {
      _showFirebaseErrorDialog('Failed to delete row: $e');
    }
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

  // Commented out for now - can be used for future login functionality
  /*
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
  */

  // Function to add a new, empty row to the table.
  void _addNewRow() {
    if (_isViewer) {
      return;
    }

    // Find the highest existing new_loco number to ensure new rows go to the bottom
    int maxIndex = 0;
    for (String key in _controllers.keys) {
      if (key.endsWith('_label') && key.startsWith('new_loco_')) {
        try {
          int num = int.parse(
            key.replaceAll('new_loco_', '').replaceAll('_label', ''),
          );
          if (num > maxIndex) maxIndex = num;
        } catch (e) {
          // Ignore invalid entries
        }
      }
    }

    String newKey = 'new_loco_${maxIndex + 1}';

    // Initialize controllers for the new row
    String labelFieldKey = '${newKey}_label';
    if (!_controllers.containsKey(labelFieldKey)) {
      final labelController = TextEditingController();
      labelController.text = '';
      labelController.addListener(() => _onFieldChanged(labelFieldKey));
      _controllers[labelFieldKey] = labelController;
    }

    List<String> colKeys = ['nos1', 'pct1', 'nos2', 'pct2'];
    for (String colKey in colKeys) {
      String fieldKey = '${newKey}_$colKey';
      if (!_controllers.containsKey(fieldKey)) {
        final controller = TextEditingController();
        controller.text = '';
        controller.addListener(() => _onFieldChanged(fieldKey));
        _controllers[fieldKey] = controller;
      }
    }

    // Log the row addition for audit tracking
    LocoFirebaseService.logRowAction('Add Row', newKey, "Today's Outage");

    // Force a rebuild to show the new row
    setState(() {
      _rebuildCounter++; // Force child widget to detect new controllers
    });
  }

  // Function to delete a row at a specific index (keeping for compatibility).
  void _deleteRow(int index) {
    setState(() {
      _dataRows.removeAt(index);
    });
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
        title: const Text(
          "Today's Outage",
          style: TextStyle(
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
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white, size: 32),
            tooltip: 'Zoom In',
            onPressed: () => setState(() => _scaleFactor += 0.1),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white, size: 32),
            tooltip: 'Zoom Out',
            onPressed: () => setState(() {
              if (_scaleFactor > 0.5) _scaleFactor -= 0.1;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white, size: 32),
            tooltip: 'Save',
            onPressed: () {
              // Save functionality handled by Firebase auto-save
            },
          ),
        ],
      ),
      // Add the Floating Action Button here
      floatingActionButton: _isViewer
          ? null
          : FloatingActionButton(
              onPressed: _addNewRow,
              backgroundColor: appBarColor,
              tooltip: 'Add Row',
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: Center(
        child: _useFirebase
            ? TodaysOutageView(
                key: ValueKey(_rebuildCounter),
                dataFromFirebase: _dataFromFirebase,
                controllers: _controllers,
                pendingUpdates: _pendingUpdates,
                isViewer: _isViewer,
                hasUnsavedChanges: _hasUnsavedChanges,
                useFirebase: _useFirebase,
                scaleFactor: _scaleFactor,
                onFieldChanged: _onFieldChanged,
                onSave: _saveData,
                onAddRow: _addNewRow,
                onDeleteRow: _deleteRowFromFirebase,
              )
            : _buildOriginalTable(),
      ),
    );
  }

  // Original table implementation as fallback
  Widget _buildOriginalTable() {
    return Transform.scale(
      scale: _scaleFactor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text("Type\n(Holding)")),
              DataColumn(label: Text("No's\n(Actual)")),
              DataColumn(label: Text("%\n(Actual)")),
              DataColumn(label: Text("No's\n(Outage)")),
              DataColumn(label: Text("%\n(Outage)")),
            ],
            rows: _dataRows.asMap().entries.map((entry) {
              int index = entry.key;
              TableRowData rowData = entry.value;
              return DataRow(
                cells: rowData.cells.asMap().entries.map((cellEntry) {
                  int cellIndex = cellEntry.key;
                  String cellData = cellEntry.value;
                  return DataCell(
                    cellIndex == 0
                        ? Text(cellData)
                        : TextFormField(
                            initialValue: cellData,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _dataRows[index].cells[cellIndex] = value;
                              });
                            },
                          ),
                  );
                }).toList(),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Delete Row"),
                        content: const Text(
                          "Are you sure you want to delete this row?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              _deleteRow(index);
                              Navigator.of(context).pop();
                            },
                            child: const Text("Delete"),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
