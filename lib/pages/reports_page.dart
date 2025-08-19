import 'dart:async';
import 'package:flutter/material.dart';
import '../services/loco_firebase_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _auditLogs = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final logs = await LocoFirebaseService.getAuditLogs();

      setState(() {
        _auditLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load audit logs: $e';
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';

    try {
      DateTime dateTime;
      if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        // Handle Firestore Timestamp
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp.millisecondsSinceEpoch ?? 0,
        );
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid timestamp';
    }
  }

  String _getChangeTypeIcon(String key, String action) {
    if (action == 'delete') return '🗑️';
    if (action == 'batch_update') return '📊';
    if (action == 'add_row') return '➕';
    if (key.contains('_label')) return '🏷️';
    if (key.contains('shed_')) return '🏗️';
    if (key.contains('schedule')) return '📅';
    if (key.contains('loco')) return '🚂';
    if (key.contains('forecast')) return '📈';
    if (key.startsWith('new_')) return '✨';
    return '📝';
  }

  String _getChangeDescription(
    String key,
    String value,
    String action,
    String section,
  ) {
    if (action == 'delete') {
      return 'Deleted $key from $section';
    } else if (action == 'batch_update') {
      return 'Batch updated $key to "$value" in $section';
    } else if (action == 'add_row') {
      return 'Added new row: $value in $section';
    } else if (key.contains('_label')) {
      return 'Updated row label to "$value" in $section';
    } else if (key.contains('shed_')) {
      String shedNumber = key.replaceAll('shed_', '');
      return 'Updated Shed $shedNumber to "$value" in $section';
    } else if (key.contains('_schedule_type')) {
      return 'Updated schedule type to "$value" in $section';
    } else if (key.contains('_loco')) {
      return 'Updated locomotive to "$value" in $section';
    } else if (key.contains('_forecast')) {
      return 'Updated forecast to "$value" in $section';
    } else {
      return 'Updated $key to "$value" in $section';
    }
  }

  Widget _buildLogItem(Map<String, dynamic> log, int index) {
    final key = log['key'] ?? 'unknown';
    final value = log['value'] ?? '';
    final action = log['action'] ?? 'update';
    final section = log['section'] ?? 'General';
    final updatedBy = log['updatedBy'] ?? 'Unknown user';
    final timestamp = log['timestamp'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        key: Key(log['id'] ?? index.toString()),
        leading: Text(
          _getChangeTypeIcon(key, action),
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          _getChangeDescription(key, value, action, section),
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By: $updatedBy',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Field Changed:', key),
                _buildDetailRow(
                  'New Value:',
                  value.isEmpty ? '(empty)' : value,
                ),
                _buildDetailRow('Changed By:', updatedBy),
                _buildDetailRow('Timestamp:', _formatTimestamp(timestamp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF22223B),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE43636),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Change Reports & Audit Log',
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
            icon: const Icon(Icons.refresh, color: Colors.white, size: 32),
            tooltip: 'Refresh',
            onPressed: _loadAuditLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading audit logs...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAuditLogs,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _auditLogs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: Colors.grey, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No audit logs found',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Changes will appear here when users edit data',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.black26,
                  child: Column(
                    children: [
                      Text(
                        'Total Changes: ${_auditLogs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Showing all user changes and modifications',
                        style: TextStyle(color: Colors.grey[300], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _auditLogs.length,
                    itemBuilder: (context, index) {
                      return _buildLogItem(_auditLogs[index], index);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
