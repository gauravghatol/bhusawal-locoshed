import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/loco_firebase_service.dart';

class ScheduledLocosView extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, String> dataFromFirebase;
  final Map<String, String> pendingUpdates;
  final bool hasUnsavedChanges;
  final bool useFirebase;
  final bool isViewer;
  final Function(String) onFieldChanged;
  final VoidCallback onSave;
  final Function(String) onDeleteRow;

  const ScheduledLocosView({
    super.key,
    required this.controllers,
    required this.dataFromFirebase,
    required this.pendingUpdates,
    required this.hasUnsavedChanges,
    required this.useFirebase,
    required this.onFieldChanged,
    required this.onSave,
    required this.isViewer,
    required this.onDeleteRow,
  });

  @override
  State<ScheduledLocosView> createState() => _ScheduledLocosViewState();
}

class _ScheduledLocosViewState extends State<ScheduledLocosView> {
  // Default system rows that should always exist
  static const List<String> _defaultRowKeys = ['IA', 'IB', 'IC'];

  // Dynamic row management
  List<String> rowKeys = [];

  @override
  void initState() {
    super.initState();
    _detectAndInitializeAllRows();
  }

  @override
  void didUpdateWidget(ScheduledLocosView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-detect rows when widget updates (e.g., new Firebase data)
    if (widget.dataFromFirebase != oldWidget.dataFromFirebase) {
      _detectAndInitializeAllRows();
    }
  }

  void _detectAndInitializeAllRows() {
    debugPrint('=== SCHEDULED LOCOS: Detecting and initializing all rows ===');

    // Start with default rows
    List<String> detectedRowKeys = [];
    Set<String> newScheduleRowKeys = {};

    // Check default rows
    for (String defaultKey in _defaultRowKeys) {
      bool hasData = false;
      bool hasControllers = false;

      // Check if default row has data in Firebase
      for (String field in ['_schedule_type', '_loco']) {
        String fullKey = '$defaultKey$field';
        if ((widget.dataFromFirebase[fullKey] ?? '').isNotEmpty) {
          hasData = true;
          break;
        }
      }

      // Check if default row has controllers
      for (String field in ['_schedule_type', '_loco']) {
        String fullKey = '$defaultKey$field';
        if (widget.controllers.containsKey(fullKey)) {
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
      'Checking ${widget.controllers.length} controllers for new_schedule rows...',
    );
    for (String controllerKey in widget.controllers.keys) {
      if (controllerKey.startsWith('new_schedule_') &&
          controllerKey.endsWith('_schedule_type')) {
        String rowKey = controllerKey.replaceAll('_schedule_type', '');
        newScheduleRowKeys.add(rowKey);
        debugPrint('Added row $rowKey from existing controller $controllerKey');
      }
    }

    // Check for new_schedule rows from Firebase data
    for (String dataKey in widget.dataFromFirebase.keys) {
      if (dataKey.startsWith('new_schedule_') &&
          (dataKey.endsWith('_schedule_type') || dataKey.endsWith('_loco')) &&
          (widget.dataFromFirebase[dataKey] ?? '').isNotEmpty) {
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
    });
  }

  int _getNumber(String rowKey) {
    final match = RegExp(r'new_schedule_(\d+)').firstMatch(rowKey);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  Widget _buildEditableField(
    String key, {
    int maxLength = 16,
    double width = 120,
    double height = 56,
    TextAlign align = TextAlign.center,
  }) {
    if (!widget.controllers.containsKey(key)) {
      final controller = TextEditingController();
      controller.text = widget.dataFromFirebase[key] ?? '';
      controller.addListener(() => widget.onFieldChanged(key));
      widget.controllers[key] = controller;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: widget.isViewer ? Colors.grey[300] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.pendingUpdates.containsKey(key)
              ? Colors.orange
              : Colors.grey,
          width: 2,
        ),
      ),
      child: TextField(
        controller: widget.controllers[key],
        enabled: !widget.isViewer,
        textAlign: align,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.all(8),
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxLength),
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s/.-]')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with status
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Rows: ${rowKeys.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (widget.hasUnsavedChanges)
                const Text(
                  'Unsaved Changes',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              border: TableBorder.all(color: Colors.grey),
              columnWidths: const {
                0: FixedColumnWidth(150),
                1: FixedColumnWidth(200),
                2: FixedColumnWidth(200),
                3: FixedColumnWidth(100),
              },
              children: [
                // Header row
                const TableRow(
                  decoration: BoxDecoration(color: Colors.grey),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Row',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Schedule Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Loco',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),

                // Data rows
                ...rowKeys.asMap().entries.map((entry) {
                  int i = entry.key;
                  String rowKey = entry.value;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          rowKey.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildEditableField('${rowKey}_schedule_type'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildEditableField('${rowKey}_loco'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: widget.isViewer
                            ? const SizedBox()
                            : IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Row',
                                onPressed: () => _deleteRow(i),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),

        // Add button
        if (!widget.isViewer)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Row'),
              onPressed: _addRow,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  void _addRow() {
    debugPrint('Starting to generate unique key...');

    // Log current state for debugging
    debugPrint('Existing controllers: ${widget.controllers.keys.toList()}');
    debugPrint('Firebase data keys: ${widget.dataFromFirebase.keys.toList()}');
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
    for (String key in widget.dataFromFirebase.keys) {
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
    });

    // Initialize controllers for both fields
    String scheduleTypeFieldKey = '${newKey}_schedule_type';
    if (!widget.controllers.containsKey(scheduleTypeFieldKey)) {
      final scheduleTypeController = TextEditingController();
      scheduleTypeController.text = '';
      scheduleTypeController.addListener(
        () => widget.onFieldChanged(scheduleTypeFieldKey),
      );
      widget.controllers[scheduleTypeFieldKey] = scheduleTypeController;
      debugPrint(
        'Created new controller for $scheduleTypeFieldKey with text: ""',
      );
    }

    String locoFieldKey = '${newKey}_loco';
    if (!widget.controllers.containsKey(locoFieldKey)) {
      final locoController = TextEditingController();
      locoController.text = '';
      locoController.addListener(() => widget.onFieldChanged(locoFieldKey));
      widget.controllers[locoFieldKey] = locoController;
      debugPrint('Created new controller for $locoFieldKey with text: ""');
    }

    debugPrint(
      'Finished adding new row $newKey - total controllers: ${widget.controllers.length}',
    );

    // Log the row addition for audit tracking
    LocoFirebaseService.logRowAction('Add Row', newKey, 'Scheduled Locos');
  }

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
                _confirmDeleteRow(rowKeyToDelete);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteRow(String rowKey) {
    debugPrint('Confirming deletion of row: $rowKey');

    // Remove from local state
    setState(() {
      rowKeys.remove(rowKey);
    });

    // Remove controllers for all fields in this row
    List<String> fieldsToDelete = ['_schedule_type', '_loco'];
    for (String field in fieldsToDelete) {
      String fullKey = '$rowKey$field';
      if (widget.controllers.containsKey(fullKey)) {
        widget.controllers[fullKey]?.dispose();
        widget.controllers.remove(fullKey);
        debugPrint('Removed controller for $fullKey');
      }
    }

    // Delete from Firebase
    widget.onDeleteRow(rowKey);

    // Log the row deletion for audit tracking
    LocoFirebaseService.logRowAction('Delete Row', rowKey, 'Scheduled Locos');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Row "$rowKey" deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
