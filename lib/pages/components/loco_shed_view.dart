import 'dart:math'; // Import the math library for the 'max' function
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LocoShedView extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, String> dataFromFirebase;
  final Map<String, String> pendingUpdates;
  final bool hasUnsavedChanges;
  final bool useFirebase;
  final bool isViewer;
  final Function(String) onFieldChanged;
  final VoidCallback onSave;

  const LocoShedView({
    super.key,
    required this.controllers,
    required this.dataFromFirebase,
    required this.pendingUpdates,
    required this.hasUnsavedChanges,
    required this.useFirebase,
    required this.onFieldChanged,
    required this.onSave,
    required this.isViewer,
  });

  @override
  State<LocoShedView> createState() => _LocoShedViewState();
}

class _LocoShedViewState extends State<LocoShedView> {
  @override
  Widget build(BuildContext context) {
    // Define the colors for consistent styling.
    const Color backgroundColor = Color(0xFF22223B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Header with status indicator
          if (widget.hasUnsavedChanges && !widget.isViewer)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'You have unsaved changes',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          // ==================== MAIN SHED LAYOUT ====================
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double sw = constraints.maxWidth; // screen width
                final double sh = constraints.maxHeight; // screen height

                // --- Define Responsive Sizes with Minimums ---
                final double hPadding = sw * 0.02;
                final double vPadding = sh * 0.02;

                final double titleFontSize = max(14.0, sw * 0.015);
                final double bayLabelFontSize = max(12.0, sw * 0.012);
                final double avatarRadius = max(18.0, sw * 0.015);

                final double textFieldWidth = max(90.0, sw * 0.06);
                final double textFieldHeight = max(45.0, sh * 0.06);
                final double gap = max(8.0, sw * 0.01);

                // Using nested SingleScrollViews to allow both vertical and horizontal scrolling.
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPadding,
                        vertical: vPadding,
                      ),
                      width: max(sw, 1200),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- Top Header ---
                          _buildTopHeader(fontSize: titleFontSize),
                          SizedBox(height: vPadding),

                          // --- Bay 1: Testing Bay ---
                          _buildBayRow(
                            bayNumber: '1',
                            bayName: 'Testing bay',
                            leftInputColumn: [
                              _buildLocoInputRow(
                                'pos_1',
                                '1',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                              ),
                              SizedBox(height: gap),
                              _buildLocoInputRow(
                                'pos_2',
                                '2',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                              ),
                            ],
                            fontSize: titleFontSize,
                            bayLabelFontSize: bayLabelFontSize,
                            textFieldWidth: textFieldWidth,
                            gap: gap,
                          ),
                          const Divider(
                            color: Color(0xFFF6EFD2),
                            thickness: 4,
                            height: 50,
                          ),

                          // --- Bay 2: Light Lifting Bay ---
                          _buildBayRow(
                            bayNumber: '2',
                            bayName: 'Light Lifting Bay',
                            rtPlantWidget: _buildLocoInput(
                              'rt_plant_1',
                              'RT Plant',
                              textFieldWidth,
                              textFieldHeight,
                              titleFontSize * 0.8,
                            ),
                            leftInputColumn: [
                              _buildLocoInputRow(
                                'pos_3a',
                                '3',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                                count: 3,
                              ),
                              SizedBox(height: gap),
                              _buildLocoInputRow(
                                'pos_4a',
                                '4',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                                count: 3,
                              ),
                            ],
                            fontSize: titleFontSize,
                            bayLabelFontSize: bayLabelFontSize,
                            textFieldWidth: textFieldWidth,
                            gap: gap,
                          ),
                          const Divider(
                            color: Color(0xFFF6EFD2),
                            thickness: 4,
                            height: 50,
                          ),

                          // --- Bay 3: Heavy Lifting Bay ---
                          _buildBayRow(
                            bayNumber: '3',
                            bayName: 'Heavy Lifting Bay',
                            leftInputColumn: [
                              _buildLocoInputRow(
                                'pos_5a',
                                '5',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                                count: 2,
                              ),
                              SizedBox(height: gap),
                              _buildLocoInputRow(
                                'pos_6a',
                                '6',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                                count: 2,
                              ),
                            ],
                            fontSize: titleFontSize,
                            bayLabelFontSize: bayLabelFontSize,
                            textFieldWidth: textFieldWidth,
                            gap: gap,
                          ),
                          const Divider(
                            color: Color(0xFFF6EFD2),
                            thickness: 4,
                            height: 50,
                          ),

                          // --- Bay 4: Minor Schedule Bay ---
                          _buildBayRow(
                            bayNumber: '4',
                            bayName: 'Minor Schedule Bay',
                            rtPlantWidget: _buildLocoInput(
                              'rt_plant_2',
                              'RT Plant',
                              textFieldWidth,
                              textFieldHeight,
                              titleFontSize * 0.8,
                            ),
                            leftInputColumn: [
                              _buildLocoInputRow(
                                'pos_7a',
                                '7',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                                count: 3,
                              ),
                              SizedBox(height: gap),
                              _buildLocoInputRow(
                                'pos_8a',
                                '8',
                                avatarRadius,
                                textFieldWidth,
                                textFieldHeight,
                                gap,
                                count: 3,
                              ),
                            ],
                            rightInputColumn: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLocoInput(
                                    'pos_9a',
                                    null,
                                    textFieldWidth,
                                    textFieldHeight,
                                    0,
                                  ),
                                  SizedBox(width: gap),
                                  _buildLocoInput(
                                    'pos_9b',
                                    null,
                                    textFieldWidth,
                                    textFieldHeight,
                                    0,
                                  ),
                                ],
                              ),
                              SizedBox(height: gap),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLocoInput(
                                    'pos_10a',
                                    null,
                                    textFieldWidth,
                                    textFieldHeight,
                                    0,
                                  ),
                                  SizedBox(width: gap),
                                  _buildLocoInput(
                                    'pos_10b',
                                    null,
                                    textFieldWidth,
                                    textFieldHeight,
                                    0,
                                  ),
                                ],
                              ),
                            ],
                            fontSize: titleFontSize,
                            bayLabelFontSize: bayLabelFontSize,
                            textFieldWidth: textFieldWidth,
                            gap: gap,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top header with Mumbai/Nagpur ends and Admin building.
  Widget _buildTopHeader({required double fontSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Mumbai End',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE43636), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Admin Building',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ),
        const Text(
          'Nagpur End',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// A generic, reusable widget for building a full bay row.
  Widget _buildBayRow({
    required String bayNumber,
    required String bayName,
    Widget? rtPlantWidget,
    List<Widget> leftInputColumn = const [],
    List<Widget> rightInputColumn = const [],
    required double fontSize,
    required double bayLabelFontSize,
    required double textFieldWidth,
    required double gap,
  }) {
    Widget inputSection = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: textFieldWidth, child: rtPlantWidget),
        SizedBox(width: gap),
        if (leftInputColumn.isNotEmpty)
          Column(mainAxisSize: MainAxisSize.min, children: leftInputColumn),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Section
        inputSection,

        // Center Section (expands to fill the available space)
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bay No. $bayNumber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE43636), width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  bayName,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: bayLabelFontSize,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right Section
        if (rightInputColumn.isNotEmpty)
          Column(mainAxisSize: MainAxisSize.min, children: rightInputColumn)
        else
          const SizedBox(), // Use a SizedBox as a placeholder to maintain structure
      ],
    );
  }

  /// Builds a row containing a circle avatar and one or more text fields.
  Widget _buildLocoInputRow(
    String basePositionId,
    String label,
    double avatarRadius,
    double textFieldWidth,
    double textFieldHeight,
    double gap, {
    int count = 1,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundColor: const Color(0xFFFFD700),
          child: Text(
            label,
            style: TextStyle(
              fontSize: avatarRadius * 0.9,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(width: gap),
        for (int i = 0; i < count; i++) ...[
          _buildLocoInput(
            '$basePositionId${String.fromCharCode(97 + i)}', // Generates unique IDs like 'pos_3a', 'pos_3b'
            null,
            textFieldWidth,
            textFieldHeight,
            0,
          ),
          if (i < count - 1) SizedBox(width: gap),
        ],
      ],
    );
  }

  /// Builds a single, reusable text input field with an optional label above it.
  Widget _buildLocoInput(
    String positionId,
    String? label,
    double width,
    double height,
    double labelFontSize,
  ) {
    // Initialize controller if it doesn't exist
    if (!widget.controllers.containsKey(positionId)) {
      final controller = TextEditingController();
      controller.addListener(() => widget.onFieldChanged(positionId));
      widget.controllers[positionId] = controller;
    }

    // Set initial value from Firebase if controller is empty
    final controller = widget.controllers[positionId]!;
    final firebaseValue = widget.dataFromFirebase[positionId] ?? '';
    if (controller.text.isEmpty && firebaseValue.isNotEmpty) {
      controller.text = firebaseValue;
    }

    // Determine if this field has pending changes
    final hasPendingChanges = widget.pendingUpdates.containsKey(positionId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        SizedBox(
          width: width,
          height: height,
          child: TextFormField(
            controller: controller,
            enabled: !widget.isViewer,
            textAlign: TextAlign.center,
            textAlignVertical:
                TextAlignVertical.center, // This centers the text vertically
            style: const TextStyle(
              fontSize: 22,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasPendingChanges ? Colors.orange : Colors.black,
                  width: hasPendingChanges ? 3 : 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasPendingChanges ? Colors.orange : Colors.black,
                  width: hasPendingChanges ? 3 : 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasPendingChanges ? Colors.orange : Colors.blue,
                  width: 3,
                ),
              ),
              contentPadding: EdgeInsets.zero,
              counterText: '',
              filled: true,
              fillColor: widget.isViewer ? Colors.grey[200] : Colors.white,
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      ],
    );
  }
}
