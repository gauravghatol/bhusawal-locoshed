import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/loco_firebase_service.dart';
import '../services/authentication_manager.dart';

// A simple data class to hold the data for a single row.
class ScheduledLocoRowData {
  List<String> cells;
  ScheduledLocoRowData({required this.cells});
}

class ScheduledLocosPage extends StatefulWidget {
  const ScheduledLocosPage({super.key});

  @override
  State<ScheduledLocosPage> createState() => _ScheduledLocosPageState();
}

class _ScheduledLocosPageState extends State<ScheduledLocosPage> {
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

  // State variable to hold the current scale/zoom factor of the table.
  double _scaleFactor = 1.0;

  // State variable to hold the list of data rows for the table.
  final List<ScheduledLocoRowData> _dataRows = [
    ScheduledLocoRowData(cells: ["IA", "22952"]),
    ScheduledLocoRowData(cells: ["IB", "----"]),
    ScheduledLocoRowData(cells: ["IC", "42471 (IC0), 44039 (IC0)"]),
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
    LocoFirebaseService.getScheduledLocosDataStream().listen(
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
      // Cancel any existing timer
      _debounceTimer?.cancel();

      // Start a new timer for 1.5 seconds
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
        _saveData();
      });
    }
  }

  void _updateControllersFromFirebase(Map<String, String> data) {
    if (_isUpdatingFromFirebase) return;
    _isUpdatingFromFirebase = true;

    // Update controllers
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

    // Sync Firebase data with local data rows
    _syncDataRowsWithFirebase(data);

    _isUpdatingFromFirebase = false;
  }

  void _syncDataRowsWithFirebase(Map<String, String> firebaseData) {
    // Keep the default rows but update their values from Firebase
    List<ScheduledLocoRowData> updatedRows = [];

    // Check default rows (IA, IB, IC) - only add them if they have non-empty data
    for (int i = 0; i < 3; i++) {
      String scheduleType = ['IA', 'IB', 'IC'][i];
      String locoValue = firebaseData['${scheduleType}_loco'] ?? '';

      // Only add default rows if they have data in Firebase or are new (no Firebase data yet)
      if (locoValue.isNotEmpty ||
          !firebaseData.containsKey('${scheduleType}_loco')) {
        // Use default values only if Firebase doesn't have the data yet
        if (locoValue.isEmpty &&
            !firebaseData.containsKey('${scheduleType}_loco')) {
          locoValue = i == 0
              ? '22952'
              : i == 1
              ? '----'
              : '42471 (IC0), 44039 (IC0)';
        }
        if (locoValue.isNotEmpty) {
          updatedRows.add(
            ScheduledLocoRowData(cells: [scheduleType, locoValue]),
          );
        }
      }
    }

    // Add any additional rows from Firebase (new_schedule_X)
    Set<String> additionalRowKeys = {};
    for (String key in firebaseData.keys) {
      if (key.startsWith('new_schedule_') &&
          (key.endsWith('_schedule_type') || key.endsWith('_loco'))) {
        String rowKey = key
            .replaceAll('_schedule_type', '')
            .replaceAll('_loco', '');
        additionalRowKeys.add(rowKey);
      }
    }

    // Sort additional rows numerically
    List<String> sortedKeys = additionalRowKeys.toList();
    sortedKeys.sort((a, b) {
      final RegExp regExp = RegExp(r'new_schedule_(\d+)');
      final aMatch = regExp.firstMatch(a);
      final bMatch = regExp.firstMatch(b);
      if (aMatch != null && bMatch != null) {
        return int.parse(
          aMatch.group(1)!,
        ).compareTo(int.parse(bMatch.group(1)!));
      }
      return a.compareTo(b);
    });

    // Add Firebase rows to local state - only if they have data
    for (String rowKey in sortedKeys) {
      String scheduleType = firebaseData['${rowKey}_schedule_type'] ?? rowKey;
      String locoValue = firebaseData['${rowKey}_loco'] ?? '';
      // Only add the row if it has actual data (not deleted/empty)
      if (scheduleType.isNotEmpty && locoValue.isNotEmpty) {
        updatedRows.add(ScheduledLocoRowData(cells: [scheduleType, locoValue]));
      }
    }

    // Update local state if different
    if (!_areRowsEqual(_dataRows, updatedRows)) {
      setState(() {
        _dataRows.clear();
        _dataRows.addAll(updatedRows);
      });
    }
  }

  bool _areRowsEqual(
    List<ScheduledLocoRowData> rows1,
    List<ScheduledLocoRowData> rows2,
  ) {
    if (rows1.length != rows2.length) return false;
    for (int i = 0; i < rows1.length; i++) {
      if (rows1[i].cells[0] != rows2[i].cells[0] ||
          rows1[i].cells[1] != rows2[i].cells[1]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveData() async {
    if (!_useFirebase || _pendingUpdates.isEmpty) return;
    try {
      await LocoFirebaseService.updateScheduledLoco(_pendingUpdates);
      setState(() {
        _pendingUpdates.clear();
        _hasUnsavedChanges = false;
      });
    } catch (e) {
      _showFirebaseErrorDialog('Save failed: $e');
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

  Future<void> _deleteRowFromFirebase(String rowKey) async {
    debugPrint('Deleting row from Firebase: $rowKey');

    if (!_useFirebase || _isViewer) return;

    try {
      // Collect all field keys that belong to this row
      List<String> fieldsToDelete = ['_schedule_type', '_loco'];
      Map<String, String> deletionUpdates = {};

      for (String field in fieldsToDelete) {
        String fullKey = '$rowKey$field';
        deletionUpdates[fullKey] = ''; // Set to empty string to delete
      }

      // Use updateScheduledLoco to delete the row data
      await LocoFirebaseService.updateScheduledLoco(deletionUpdates);

      debugPrint('Successfully deleted row $rowKey from Firebase');
    } catch (e) {
      debugPrint('Failed to delete row $rowKey from Firebase: $e');
      _showFirebaseErrorDialog('Failed to delete row: $e');
    }
  }

  void _showLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please login to edit the schedule.'),
            const SizedBox(height: 16),
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

  // Function to add a new, empty row to the table.
  void _addNewRow() {
    if (_isViewer) return;

    // Find the highest existing new_schedule number
    int maxNumber = 0;
    for (String key in _dataFromFirebase.keys) {
      if (key.startsWith('new_schedule_')) {
        final RegExp regExp = RegExp(r'new_schedule_(\d+)');
        final match = regExp.firstMatch(key);
        if (match != null) {
          int number = int.parse(match.group(1)!);
          if (number > maxNumber) {
            maxNumber = number;
          }
        }
      }
    }

    String newRowKey = 'new_schedule_${maxNumber + 1}';

    // Add to local data rows for immediate UI update
    setState(() {
      _dataRows.add(ScheduledLocoRowData(cells: [newRowKey, ""]));

      // Initialize in pending updates for Firebase save
      _pendingUpdates['${newRowKey}_schedule_type'] = newRowKey;
      _pendingUpdates['${newRowKey}_loco'] = '';
      _hasUnsavedChanges = true;
    });

    // Save to Firebase immediately
    if (_useFirebase) {
      _saveData()
          .then((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('New row "$newRowKey" added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          })
          .catchError((e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add row: $e'),
                backgroundColor: Colors.red,
              ),
            );
          });
    }
  } // Function to delete a row at a specific index.

  void _deleteRow(int index) {
    if (_isViewer) return;

    String rowKey =
        _dataRows[index].cells[0]; // Get the schedule type (IA, IB, IC, etc.)

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete row "$rowKey"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Remove from local state
              setState(() {
                _dataRows.removeAt(index);
              });

              // Remove from Firebase
              if (_useFirebase) {
                try {
                  Map<String, String> deletionUpdates = {
                    '${rowKey}_schedule_type': '',
                    '${rowKey}_loco': '',
                  };
                  await LocoFirebaseService.updateScheduledLoco(
                    deletionUpdates,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Row "$rowKey" deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete row: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Helper method to get Firebase value or fallback to default
  String _getFirebaseValue(String key, String defaultValue) {
    return _dataFromFirebase[key] ?? defaultValue;
  }

  // Helper method to update Firebase value
  void _updateFirebaseValue(String key, String value) {
    if (_isViewer || _isUpdatingFromFirebase) return;

    setState(() {
      if (value != (_dataFromFirebase[key] ?? '')) {
        _pendingUpdates[key] = value;
        _hasUnsavedChanges = true;
      } else {
        _pendingUpdates.remove(key);
        _hasUnsavedChanges = _pendingUpdates.isNotEmpty;
      }
    });

    if (_useFirebase && !_isViewer) {
      // Cancel any existing timer
      _debounceTimer?.cancel();

      // Start a new timer for 1.5 seconds
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
        _saveData();
      });
    }
  }

  // Helper method to build additional Firebase rows
  List<Widget> _buildFirebaseRows(
    double col1Width,
    double dataColWidth,
    double deleteColWidth,
    double dataRowHeight,
  ) {
    List<Widget> firebaseRows = [];

    // Look for additional new_schedule rows in Firebase
    Set<String> additionalRowKeys = {};
    for (String key in _dataFromFirebase.keys) {
      if (key.startsWith('new_schedule_') &&
          (key.endsWith('_schedule_type') || key.endsWith('_loco'))) {
        String rowKey = key
            .replaceAll('_schedule_type', '')
            .replaceAll('_loco', '');
        additionalRowKeys.add(rowKey);
      }
    }

    // Sort the additional rows
    List<String> sortedKeys = additionalRowKeys.toList();
    sortedKeys.sort((a, b) {
      final RegExp regExp = RegExp(r'new_schedule_(\d+)');
      final aMatch = regExp.firstMatch(a);
      final bMatch = regExp.firstMatch(b);
      if (aMatch != null && bMatch != null) {
        return int.parse(
          aMatch.group(1)!,
        ).compareTo(int.parse(bMatch.group(1)!));
      }
      return a.compareTo(b);
    });

    for (String rowKey in sortedKeys) {
      firebaseRows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEditableCell(
              _getFirebaseValue('${rowKey}_schedule_type', ''),
              width: col1Width,
              height: dataRowHeight,
              onChanged: (value) =>
                  _updateFirebaseValue('${rowKey}_schedule_type', value),
              enabled: !_isViewer,
            ),
            _buildEditableCell(
              _getFirebaseValue('${rowKey}_loco', ''),
              width: dataColWidth,
              height: dataRowHeight,
              onChanged: (value) =>
                  _updateFirebaseValue('${rowKey}_loco', value),
              enabled: !_isViewer,
            ),
            _isViewer
                ? SizedBox(width: deleteColWidth, height: dataRowHeight)
                : _buildDeleteCell(
                    onPressed: () => _deleteFirebaseRow(rowKey),
                    width: deleteColWidth,
                    height: dataRowHeight,
                  ),
          ],
        ),
      );
    }

    return firebaseRows;
  }

  // Method to delete Firebase row
  void _deleteFirebaseRow(String rowKey) {
    if (_isViewer) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete row "$rowKey"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRowFromFirebase(rowKey);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFF22223B);
    const Color appBarColor = Color(0xFFE43636);

    // Get the total screen width to make the table responsive.
    final double screenWidth = MediaQuery.of(context).size.width;

    // Calculate the total width of the table as a percentage of the screen width.
    final double tableWidth = screenWidth * 0.9;

    // Define column widths, adding a fixed width for the new delete button column.
    const double deleteColWidth = 70.0;
    final double remainingWidth = tableWidth - deleteColWidth;
    final double col1Width = remainingWidth * 0.3;
    final double dataColWidth = remainingWidth * 0.7;

    // Define row heights
    const double headerRowHeight = 70.0;
    const double dataRowHeight = 90.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isViewer ? 'Scheduled Locos (View Only)' : 'Scheduled Locos',
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
      // Add the Floating Action Button here
      floatingActionButton: _isViewer
          ? null
          : FloatingActionButton(
              onPressed: _addNewRow,
              backgroundColor: appBarColor,
              tooltip: 'Add Row',
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                child: Transform.scale(
                  scale: _scaleFactor,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Static Header ---
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildEditableCell(
                              "Schedule Type",
                              isHeader: true,
                              width: col1Width,
                              height: headerRowHeight,
                            ),
                            _buildEditableCell(
                              "Loco No.",
                              isHeader: true,
                              width: dataColWidth,
                              height: headerRowHeight,
                            ),
                            // Placeholder for the delete column in the header
                            SizedBox(
                              width: deleteColWidth,
                              height: headerRowHeight,
                            ),
                          ],
                        ),
                        // --- Dynamic Data Rows ---
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show static rows first with Firebase integration
                            for (int i = 0; i < _dataRows.length; i++)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildEditableCell(
                                    _getFirebaseValue(
                                      '${_dataRows[i].cells[0]}_schedule_type',
                                      _dataRows[i].cells[0],
                                    ),
                                    isRowHeader: true,
                                    width: col1Width,
                                    height: dataRowHeight,
                                    onChanged: (value) {
                                      _updateFirebaseValue(
                                        '${_dataRows[i].cells[0]}_schedule_type',
                                        value,
                                      );
                                    },
                                    enabled: !_isViewer,
                                  ),
                                  _buildEditableCell(
                                    _getFirebaseValue(
                                      '${_dataRows[i].cells[0]}_loco',
                                      _dataRows[i].cells[1],
                                    ),
                                    width: dataColWidth,
                                    height: dataRowHeight,
                                    onChanged: (value) {
                                      _updateFirebaseValue(
                                        '${_dataRows[i].cells[0]}_loco',
                                        value,
                                      );
                                    },
                                    enabled: !_isViewer,
                                  ),
                                  _isViewer
                                      ? SizedBox(
                                          width: deleteColWidth,
                                          height: dataRowHeight,
                                        )
                                      : _buildDeleteCell(
                                          onPressed: () => _deleteRow(i),
                                          width: deleteColWidth,
                                          height: dataRowHeight,
                                        ),
                                ],
                              ),
                            // Show additional Firebase rows
                            ..._buildFirebaseRows(
                              col1Width,
                              dataColWidth,
                              deleteColWidth,
                              dataRowHeight,
                            ),
                          ],
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

/// A helper widget to create an editable table cell with specific dimensions.
class _buildEditableCell extends StatefulWidget {
  final String initialValue;
  final bool isHeader;
  final bool isRowHeader;
  final double width;
  final double height;
  final Function(String)? onChanged;
  final bool enabled;

  const _buildEditableCell(
    this.initialValue, {
    this.isHeader = false,
    this.isRowHeader = false,
    required this.width,
    required this.height,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<_buildEditableCell> createState() => _buildEditableCellState();
}

class _buildEditableCellState extends State<_buildEditableCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_buildEditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color cellBackgroundColor = widget.isHeader
        ? const Color(0xFFE43636)
        : Colors.white;
    final Color cellTextColor = widget.isHeader ? Colors.white : Colors.black;
    final FontWeight fontWeight = (widget.isHeader || widget.isRowHeader)
        ? FontWeight.bold
        : FontWeight.normal;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: cellBackgroundColor,
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: TextFormField(
          controller: _controller,
          enabled: widget.enabled && !widget.isHeader,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          maxLines: null,
          expands: true,
          style: TextStyle(
            color: cellTextColor,
            fontWeight: fontWeight,
            fontSize: 22,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.0,
              vertical: 8.0,
            ),
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

/// A helper widget for the delete button cell.
class _buildDeleteCell extends StatelessWidget {
  final VoidCallback onPressed;
  final double width;
  final double height;

  const _buildDeleteCell({
    required this.onPressed,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onPressed,
          tooltip: 'Delete Row',
        ),
      ),
    );
  }
}
