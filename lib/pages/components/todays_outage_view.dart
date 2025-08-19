import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TodaysOutageView extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, String> dataFromFirebase;
  final Map<String, String> pendingUpdates;
  final bool hasUnsavedChanges;
  final bool useFirebase;
  final bool isViewer;
  final double scaleFactor;
  final Function(String) onFieldChanged;
  final VoidCallback onSave;
  final Function(String, List<String>)? onDeleteRow;
  final VoidCallback onAddRow;

  const TodaysOutageView({
    super.key,
    required this.controllers,
    required this.dataFromFirebase,
    required this.pendingUpdates,
    required this.hasUnsavedChanges,
    required this.useFirebase,
    required this.onFieldChanged,
    required this.onSave,
    required this.isViewer,
    this.scaleFactor = 1.0,
    this.onDeleteRow,
    required this.onAddRow,
  });

  @override
  State<TodaysOutageView> createState() => _TodaysOutageViewState();
}

class _TodaysOutageViewState extends State<TodaysOutageView> {
  // Keep track of dynamic rows based on controllers and Firebase data
  List<String> rowKeys = [];
  List<String> rowLabels = [];
  final List<String> colKeys = ['nos1', 'pct1', 'nos2', 'pct2'];

  @override
  void initState() {
    super.initState();
    _detectAndInitializeAllRows();
  }

  @override
  void didUpdateWidget(TodaysOutageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-detect rows when Firebase data or controllers change
    if (widget.dataFromFirebase != oldWidget.dataFromFirebase ||
        widget.controllers.length != oldWidget.controllers.length ||
        !_sameControllerKeys(widget.controllers, oldWidget.controllers)) {
      _detectAndInitializeAllRows();
    }
  }

  bool _sameControllerKeys(
    Map<String, TextEditingController> current,
    Map<String, TextEditingController> old,
  ) {
    if (current.length != old.length) return false;
    for (String key in current.keys) {
      if (!old.containsKey(key)) return false;
    }
    return true;
  }

  void _detectAndInitializeAllRows() {
    // Start with default rows but only if they have data
    List<String> defaultRowKeys = [];
    Set<String> newLocoRowKeys =
        {}; // Check default rows for data (only show if they actually have data)
    List<String> defaultRows = ['COG_71', 'GOODS_160'];
    for (String rowKey in defaultRows) {
      bool hasData = false;

      // Check label field
      String labelValue = widget.dataFromFirebase['${rowKey}_label'] ?? '';
      if (labelValue.isNotEmpty && labelValue != '[DELETED]') {
        hasData = true;
      } else {
        // Check column fields
        for (String colKey in colKeys) {
          String fieldKey = '${rowKey}_$colKey';
          String fieldValue = widget.dataFromFirebase[fieldKey] ?? '';
          if (fieldValue.isNotEmpty && fieldValue != '[DELETED]') {
            hasData = true;
            break;
          }
        }
      }

      // Only add default rows if they have actual data
      if (hasData) {
        defaultRowKeys.add(rowKey);
      }
    }

    // Detect additional rows from controllers
    for (String key in widget.controllers.keys) {
      if (key.endsWith('_label') && key.startsWith('new_loco_')) {
        String rowKey = key.replaceAll('_label', '');
        newLocoRowKeys.add(rowKey);
      }
    }

    // Detect additional rows from Firebase data
    for (String key in widget.dataFromFirebase.keys) {
      if (key.endsWith('_label') && key.startsWith('new_loco_')) {
        String rowKey = key.replaceAll('_label', '');
        String labelValue = widget.dataFromFirebase['${rowKey}_label'] ?? '';

        // Skip rows that are marked as deleted
        if (labelValue == '[DELETED]') {
          print('DEBUG: Skipping deleted row: $rowKey');
          continue;
        }

        if (labelValue.isNotEmpty) {
          newLocoRowKeys.add(rowKey);
        } else {
          // Check if any column fields have data (and not deleted)
          bool hasValidData = false;
          for (String colKey in colKeys) {
            String fieldKey = '${rowKey}_$colKey';
            String fieldValue = widget.dataFromFirebase[fieldKey] ?? '';
            if (fieldValue.isNotEmpty && fieldValue != '[DELETED]') {
              hasValidData = true;
              break;
            }
          }
          if (hasValidData) {
            newLocoRowKeys.add(rowKey);
          }
        }
      }
    }

    // Sort new_loco rows numerically
    List<String> sortedNewLocoRows = newLocoRowKeys.toList();
    sortedNewLocoRows.sort((a, b) {
      final RegExp regex = RegExp(r'new_loco_(\d+)');
      final aMatch = regex.firstMatch(a);
      final bMatch = regex.firstMatch(b);

      if (aMatch != null && bMatch != null) {
        return int.parse(
          aMatch.group(1)!,
        ).compareTo(int.parse(bMatch.group(1)!));
      }
      return a.compareTo(b);
    });

    // Combine rows
    List<String> allRowKeys = [...defaultRowKeys, ...sortedNewLocoRows];

    print('DEBUG: Final detected rows: $allRowKeys');

    // Update the state
    setState(() {
      rowKeys = allRowKeys;
      rowLabels = rowKeys.map((key) {
        if (key == 'COG_71') return 'COG\n(71)';
        if (key == 'GOODS_160') return 'GOODS\n(160)';
        // For new_loco rows, return empty string - they should be user-filled
        if (key.startsWith('new_loco_')) {
          return '';
        }
        return key.toUpperCase();
      }).toList();
    });

    // Initialize controllers for existing rows
    _initializeControllersForRows();
  }

  void _initializeControllersForRows() {
    for (String rowKey in rowKeys) {
      // Initialize label controller
      String labelFieldKey = '${rowKey}_label';
      if (!widget.controllers.containsKey(labelFieldKey)) {
        final labelController = TextEditingController();
        final firebaseValue = widget.dataFromFirebase[labelFieldKey];
        // Only set value if there's actual data in Firebase
        if (firebaseValue != null && firebaseValue.isNotEmpty) {
          labelController.text = firebaseValue;
        }
        // Controller starts empty otherwise
        labelController.addListener(() => widget.onFieldChanged(labelFieldKey));
        widget.controllers[labelFieldKey] = labelController;
      }

      // Initialize column controllers
      for (String colKey in colKeys) {
        String fieldKey = '${rowKey}_$colKey';
        if (!widget.controllers.containsKey(fieldKey)) {
          final controller = TextEditingController();
          final firebaseValue = widget.dataFromFirebase[fieldKey];
          // Only set value if there's actual data in Firebase
          if (firebaseValue != null && firebaseValue.isNotEmpty) {
            controller.text = firebaseValue;
          }
          // Controller starts empty otherwise
          controller.addListener(() => widget.onFieldChanged(fieldKey));
          widget.controllers[fieldKey] = controller;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the total screen width to make the table responsive.
    final double screenWidth = MediaQuery.of(context).size.width;

    // Calculate the total width of the table as a percentage of the screen width.
    final double tableWidth = screenWidth * 0.9;

    // Define column widths, adding a fixed width for the delete button column.
    const double deleteColWidth = 70.0;
    final double remainingWidth = tableWidth - deleteColWidth;
    final double col1Width = remainingWidth * 0.35;
    final double dataColWidth = (remainingWidth * 0.65) / 4;

    // Define row heights
    const double headerRowHeight = 60.0;
    const double dataRowHeight = 90.0;

    return Column(
      children: [
        // Table content
        Expanded(
          child: Transform.scale(
            scale: widget.scaleFactor,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
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
                              "Coaching & Goods Locos",
                              isHeader: true,
                              width: col1Width,
                              height: headerRowHeight * 2,
                            ),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    _buildEditableCell(
                                      "HQ Target",
                                      isHeader: true,
                                      width: dataColWidth * 2,
                                      height: headerRowHeight,
                                    ),
                                    _buildEditableCell(
                                      "Shed's Outage (FOIS / ICMS)",
                                      isHeader: true,
                                      width: dataColWidth * 2,
                                      height: headerRowHeight,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    _buildEditableCell(
                                      "Nos.",
                                      isHeader: true,
                                      width: dataColWidth,
                                      height: headerRowHeight,
                                    ),
                                    _buildEditableCell(
                                      "%",
                                      isHeader: true,
                                      width: dataColWidth,
                                      height: headerRowHeight,
                                    ),
                                    _buildEditableCell(
                                      "Nos.",
                                      isHeader: true,
                                      width: dataColWidth,
                                      height: headerRowHeight,
                                    ),
                                    _buildEditableCell(
                                      "%",
                                      isHeader: true,
                                      width: dataColWidth,
                                      height: headerRowHeight,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Placeholder for the delete column in the header
                            SizedBox(
                              width: deleteColWidth,
                              height: headerRowHeight * 2,
                            ),
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
                                  _buildEditableDataCell(
                                    '${rowKeys[i]}_label',
                                    isRowHeader: true,
                                    width: col1Width,
                                    height: dataRowHeight,
                                  ),
                                  for (String colKey in colKeys)
                                    _buildEditableDataCell(
                                      '${rowKeys[i]}_$colKey',
                                      width: dataColWidth,
                                      height: dataRowHeight,
                                    ),
                                  _buildDeleteCell(
                                    onPressed: widget.isViewer
                                        ? null
                                        : () => _deleteRow(i),
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
          ),
        ),
      ],
    );
  }

  void _deleteRow(int index) {
    if (index < 0 || index >= rowKeys.length) return;

    String rowKeyToDelete = rowKeys[index];

    // Call Firebase deletion if callback is provided
    if (widget.onDeleteRow != null) {
      widget.onDeleteRow!(rowKeyToDelete, colKeys);
    }

    // Remove controllers
    String labelFieldKey = '${rowKeyToDelete}_label';
    if (widget.controllers.containsKey(labelFieldKey)) {
      widget.controllers[labelFieldKey]!.dispose();
      widget.controllers.remove(labelFieldKey);
    }

    for (String colKey in colKeys) {
      String fieldKey = '${rowKeyToDelete}_$colKey';
      if (widget.controllers.containsKey(fieldKey)) {
        widget.controllers[fieldKey]!.dispose();
        widget.controllers.remove(fieldKey);
      }
    }

    // Update UI
    setState(() {
      rowKeys.removeAt(index);
      rowLabels.removeAt(index);
    });
  }

  /// A helper widget to create an editable table cell for data with Firebase integration.
  Widget _buildEditableDataCell(
    String key, {
    bool isRowHeader = false,
    required double width,
    required double height,
  }) {
    // Initialize controller if it doesn't exist (but don't do it during build)
    if (!widget.controllers.containsKey(key)) {
      // This should have been initialized already in _initializeControllersForRows
      // If it's not, we'll create an empty one to avoid errors
      final controller = TextEditingController();
      controller.text = widget.dataFromFirebase[key] ?? '';
      controller.addListener(() => widget.onFieldChanged(key));
      widget.controllers[key] = controller;
    }

    final controller = widget.controllers[key]!;

    // Determine if this field has pending changes
    final hasPendingChanges = widget.pendingUpdates.containsKey(key);

    final Color cellBackgroundColor = widget.isViewer
        ? Colors.grey[200]!
        : Colors.white;
    final Color cellTextColor = Colors.black;
    final FontWeight fontWeight = isRowHeader
        ? FontWeight.bold
        : FontWeight.normal;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: cellBackgroundColor,
          border: Border.all(
            color: hasPendingChanges ? Colors.orange : Colors.black,
            width: hasPendingChanges ? 2.0 : 1.0,
          ),
        ),
        child: TextFormField(
          controller: controller,
          enabled: !widget.isViewer,
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

  /// A helper widget to create a static header cell.
  Widget _buildEditableCell(
    String text, {
    bool isHeader = false,
    bool isRowHeader = false,
    required double width,
    required double height,
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
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cellTextColor,
            fontWeight: fontWeight,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  /// A helper widget for the delete button cell.
  Widget _buildDeleteCell({
    VoidCallback? onPressed,
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
        child: onPressed != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onPressed,
                tooltip: 'Delete Row',
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
