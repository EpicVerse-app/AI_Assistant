import 'package:flutter/material.dart';

import '../models/memory_detail.dart';
import '../theme/app_theme.dart';

class MemoryDetailScreen extends StatelessWidget {
  const MemoryDetailScreen({
    super.key,
    required this.memory,
  });

  final MemoryDetail memory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('MoM'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Share',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Minutes of Meeting',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryGray,
            ),
          ),
          const SizedBox(height: 16),
          _MomField(label: 'Meeting Date', value: memory.formattedMeetingDate),
          _MomField(label: 'Meeting Topic', value: memory.meetingTopic),
          _MomField(
            label: 'Attendees',
            value: memory.attendees.join(', '),
          ),
          _MomField(label: 'Summary', value: memory.summary),
          _MomListField(label: 'Decisions', items: memory.decisions),
          _MomListField(label: 'Action Items', items: memory.actionItems),
          _MomListField(label: 'Deadlines', items: memory.deadlines),
          _MomListField(
            label: 'Important Notes',
            items: memory.importantNotes,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete MoM?'),
                  content: const Text(
                    'This meeting record will be permanently deleted.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFFF3B30)),
                      ),
                    ),
                  ],
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
              side: const BorderSide(color: Color(0xFFFF3B30)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MomField extends StatelessWidget {
  const _MomField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryGray,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _MomListField extends StatelessWidget {
  const _MomListField({
    required this.label,
    required this.items,
  });

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryGray,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: AppTheme.primaryBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
