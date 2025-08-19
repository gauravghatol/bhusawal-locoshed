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
  // State variable to hold the current scale/zoom factor of the table.
  double _scaleFactor = 1.0;

  // State variable to hold the list of data rows for the table.
  final List<ScheduledLocoRowData> _dataRows = [];

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

  // Dynamic row management
  List<String> rowKeys = [];
  static const List<String> _defaultRowKeys = ['IA', 'IB', 'IC'];

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
            _isLoading = false;
          });
          _updateControllersFromFirebase(data);
          _detectAndInitializeAllRows();
        }
      },
      onError: (error) {
        debugPrint('Firebase stream error: $error');
        if (mounted) {
          setState(() => _isLoading = false);
          _showFirebaseErrorDialog('Connection lost: $error');
        }
      },
    );
  }

  void _detectAndInitializeAllRows() {
    debugPrint('=== SCHEDULED LOCOS: Detecting and initializing all rows ===');

    List<String> detectedRowKeys = [];
    Set<String> newScheduleRowKeys = {};

    // Check default rows
    for (String defaultKey in _defaultRowKeys) {
      bool hasData = false;
      bool hasControllers = false;

      // Check if default row has data in Firebase
      for (String field in ['_schedule_type', '_loco']) {
        String fullKey = '$defaultKey$field';
        if (((_dataFromFirebase[fullKey] ?? '').isNotEmpty)) {
          hasData = true;
          break;
        }
      }

      // Check if default row has controllers
      for (String field in ['_schedule_type', '_loco']) {
        String fullKey = '$defaultKey$field';
        if (_controllers.containsKey(fullKey)) {
          hasControllers = true;
          break;
        }
      }

      debugPrint(
        'Default row $defaultKey: hasData=$hasData, hasControllers=$hasControllers',
      );

      if (hasData || hasControllers) {
        detectedRowKeys.add(defaultKey);
      }
    }

    // Check for new_schedule rows from controllers
    debugPrint(
      'Checking ${_controllers.length} controllers for new_schedule rows...',
    );
    for (String controllerKey in _controllers.keys) {
      if (controllerKey.startsWith('new_schedule_') &&
          controllerKey.endsWith('_schedule_type')) {
        String rowKey = controllerKey.replaceAll('_schedule_type', '');
        newScheduleRowKeys.add(rowKey);
        debugPrint('Added row $rowKey from existing controller $controllerKey');
      }
    }

    // Check for new_schedule rows from Firebase data
    for (String dataKey in _dataFromFirebase.keys) {
      if (dataKey.startsWith('new_schedule_') &&
          (dataKey.endsWith('_schedule_type') || dataKey.endsWith('_loco')) &&
          ((_dataFromFirebase[dataKey] ?? '').isNotEmpty)) {
        String rowKey = dataKey
            .replaceAll('_schedule_type', '')
            .replaceAll('_loco', '');
        if (rowKey.startsWith('new_schedule_')) {
          newScheduleRowKeys.add(rowKey);
        }
      }
    }

    // Sort new_schedule rows numerically
    List<String> sortedNewScheduleRows = newScheduleRowKeys.toList();
    sortedNewScheduleRows.sort(
      (a, b) => _getNumber(a).compareTo(_getNumber(b)),
    );

    debugPrint(
      'Final detected ${sortedNewScheduleRows.length} dynamic rows: $sortedNewScheduleRows',
    );

    setState(() {
      rowKeys = [...detectedRowKeys, ...sortedNewScheduleRows];
      // Only update _dataRows length, don't sync with controller values
      // Controllers manage their own state independently
      while (_dataRows.length < rowKeys.length) {
        _dataRows.add(ScheduledLocoRowData(cells: ["", ""]));
      }
      while (_dataRows.length > rowKeys.length) {
        _dataRows.removeLast();
      }
    });
  }

  int _getNumber(String rowKey) {
    final match = RegExp(r'new_schedule_(\d+)').firstMatch(rowKey);
    return match != null ? int.parse(match.group(1)!) : 0;
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

  Future<void> _deleteRowFromFirebase(String rowKey) async {
    if (!_useFirebase) return;

    try {
      debugPrint('Deleting Firebase data for row: $rowKey');

      // Delete all fields for this row
      List<String> fieldsToDelete = [];
      for (String key in _dataFromFirebase.keys) {
        if (key.startsWith('${rowKey}_')) {
          fieldsToDelete.add(key);
        }
      }

      if (fieldsToDelete.isNotEmpty) {
        await LocoFirebaseService.deleteRowFields(fieldsToDelete);

        // Update local data
        setState(() {
          for (String field in fieldsToDelete) {
            _dataFromFirebase.remove(field);
            _pendingUpdates.remove(field);
          }
        });

        debugPrint(
          'Successfully deleted ${fieldsToDelete.length} fields for row $rowKey',
        );
      } else {
        debugPrint('No Firebase fields found for row $rowKey');
      }
    } catch (e) {
      debugPrint('Error deleting row from Firebase: $e');
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

  // Function to add a new, empty row to the table.
  void _addNewRow() {
    debugPrint('Starting to generate unique key...');

    // Log current state for debugging
    debugPrint('Existing controllers: ${_controllers.keys.toList()}');
    debugPrint('Firebase data keys: ${_dataFromFirebase.keys.toList()}');
    debugPrint('Current rowKeys: $rowKeys');

    // Find the highest existing number and add 1
    int maxNumber = 0;
    for (String key in rowKeys) {
      if (key.startsWith('new_schedule_')) {
        int number = _getNumber(key);
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    // Check Firebase data as well
    for (String key in _dataFromFirebase.keys) {
      if (key.startsWith('new_schedule_')) {
        String rowKey = key
            .replaceAll('_schedule_type', '')
            .replaceAll('_loco', '');
        int number = _getNumber(rowKey);
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    String newKey = 'new_schedule_${maxNumber + 1}';

    debugPrint('Adding new row: $newKey');

    setState(() {
      rowKeys.add(newKey);
      _dataRows.add(ScheduledLocoRowData(cells: ["", ""]));
    });

    // Initialize controllers for both fields
    String scheduleTypeFieldKey = '${newKey}_schedule_type';
    if (!_controllers.containsKey(scheduleTypeFieldKey)) {
      final scheduleTypeController = TextEditingController();
      scheduleTypeController.text = '';
      scheduleTypeController.addListener(
        () => _onFieldChanged(scheduleTypeFieldKey),
      );
      _controllers[scheduleTypeFieldKey] = scheduleTypeController;
      debugPrint(
        'Created new controller for $scheduleTypeFieldKey with text: ""',
      );
    }

    String locoFieldKey = '${newKey}_loco';
    if (!_controllers.containsKey(locoFieldKey)) {
      final locoController = TextEditingController();
      locoController.text = '';
      locoController.addListener(() => _onFieldChanged(locoFieldKey));
      _controllers[locoFieldKey] = locoController;
      debugPrint('Created new controller for $locoFieldKey with text: ""');
    }

    debugPrint(
      'Finished adding new row $newKey - total controllers: ${_controllers.length}',
    );

    // Log the row addition for audit tracking
    LocoFirebaseService.logRowAction('Add Row', newKey, 'Scheduled Locos');
  }

  // Function to delete a row at a specific index.
  void _deleteRow(int index) {
    if (index < 0 || index >= rowKeys.length) {
      debugPrint('Invalid row index: $index');
      return;
    }

    String rowKeyToDelete = rowKeys[index];
    debugPrint('Attempting to delete row: $rowKeyToDelete at index $index');

    // Show confirmation dialog for any row (including default rows)
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete row "$rowKeyToDelete"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmDeleteRow(rowKeyToDelete, index);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteRow(String rowKey, int index) {
    debugPrint('Confirming deletion of row: $rowKey');

    // Remove from local state
    setState(() {
      rowKeys.remove(rowKey);
      _dataRows.removeAt(index);
    });

    // Remove controllers for all fields in this row
    List<String> fieldsToDelete = ['_schedule_type', '_loco'];
    for (String field in fieldsToDelete) {
      String fullKey = '$rowKey$field';
      if (_controllers.containsKey(fullKey)) {
        _controllers[fullKey]?.dispose();
        _controllers.remove(fullKey);
        debugPrint('Removed controller for $fullKey');
      }
    }

    // Delete from Firebase
    _deleteRowFromFirebase(rowKey);

    // Log the row deletion for audit tracking
    LocoFirebaseService.logRowAction('Delete Row', rowKey, 'Scheduled Locos');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Row "$rowKey" deleted successfully'),
        backgroundColor: Colors.green,
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          title: Text(
            _isViewer ? 'Scheduled Locos (View Only)' : 'Scheduled Locos',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 32,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
          if (_isViewer)
            IconButton(
              icon: const Icon(Icons.login, color: Colors.white, size: 32),
              tooltip: 'Login to Edit',
              onPressed: _showLoginDialog,
            )
          else ...[
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
              onPressed: _saveData,
            ),
          ],
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
                      SizedBox(width: deleteColWidth, height: headerRowHeight),
                    ],
                  ),
                  // --- Dynamic Data Rows ---
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < rowKeys.length; i++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildEditableCell(
                              '',
                              width: col1Width,
                              height: dataRowHeight,
                              controllerKey: '${rowKeys[i]}_schedule_type',
                            ),
                            _buildEditableCell(
                              '',
                              width: dataColWidth,
                              height: dataRowHeight,
                              controllerKey: '${rowKeys[i]}_loco',
                            ),
                            _buildDeleteCell(
                              onPressed: () => _deleteRow(i),
                              width: deleteColWidth,
                              height: dataRowHeight,
                            ),
                          ],
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

  /// A helper widget to create an editable table cell with specific dimensions.
  Widget _buildEditableCell(
    String initialValue, {
    bool isHeader = false,
    bool isRowHeader = false,
    required double width,
    required double height,
    String? controllerKey,
  }) {
    final Color cellBackgroundColor = isHeader
        ? const Color(0xFFE43636)
        : Colors.white;
    final Color cellTextColor = isHeader ? Colors.white : Colors.black;
    final FontWeight fontWeight = (isHeader || isRowHeader)
        ? FontWeight.bold
        : FontWeight.normal;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: cellBackgroundColor,
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: isHeader
            ? Center(
                child: Text(
                  initialValue,
                  style: TextStyle(
                    color: cellTextColor,
                    fontWeight: fontWeight,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : TextFormField(
                controller: controllerKey != null
                    ? _controllers[controllerKey]
                    : null,
                enabled: !_isViewer,
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
              ),
      ),
    );
  }

  /// A helper widget for the delete button cell.
  Widget _buildDeleteCell({
    required VoidCallback onPressed,
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: _isViewer
            ? const SizedBox()
            : IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onPressed,
                tooltip: 'Delete Row',
              ),
      ),
    );
  }
}
