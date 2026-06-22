import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meeting.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MomResultScreen extends StatefulWidget {
  const MomResultScreen({super.key, required this.meeting});

  final Meeting meeting;

  @override
  State<MomResultScreen> createState() => _MomResultScreenState();
}

class _MomResultScreenState extends State<MomResultScreen> {
  bool _deletingAudio = false;
  bool _audioDeleted = false;

  Future<void> _confirmDeleteAudio() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete audio file?'),
        content: const Text(
          'The recording will be permanently deleted from the server. '
          'Your transcript and meeting minutes will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingAudio = true);
    try {
      await ApiService.deleteAudio(widget.meeting.meetingId);
      setState(() {
        _audioDeleted = true;
        _deletingAudio = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file deleted.')),
        );
      }
    } catch (e) {
      setState(() => _deletingAudio = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete audio: $e')),
        );
      }
    }
  }

  void _copyToClipboard() {
    final text = widget.meeting.summary ?? '';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting minutes copied to clipboard.')),
    );
  }

  List<Widget> _buildMomSections(Map<String, String> sections) {
    const labels = {
      'meeting_date': 'Meeting Date',
      'meeting_topic': 'Meeting Topic',
      'attendees': 'Attendees',
      'summary': 'Summary',
      'decisions': 'Decisions',
      'action_items': 'Action Items',
      'deadlines': 'Deadlines',
      'important_notes': 'Important Notes',
    };

    const bulletSections = {
      'summary',
      'decisions',
      'action_items',
      'deadlines',
      'important_notes',
    };

    return sections.entries.map((entry) {
      final label = labels[entry.key] ??
          entry.key.replaceAll('_', ' ').split(' ').map((w) =>
              w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
      final value = entry.value.isNotEmpty ? entry.value : 'Not mentioned';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.secondaryGray,
              ),
            ),
            const SizedBox(height: 6),
            bulletSections.contains(entry.key)
                ? _BulletBlock(value)
                : _TextBlock(value),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final summary = meeting.summary ?? 'No summary available.';

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Meeting Minutes'),
        actions: [
          IconButton(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy',
          ),
        ],
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          // Metadata row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.fillGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic_none, size: 20, color: AppTheme.secondaryGray),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.displayDate,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meeting.language != null)
                        Text(
                          'Language: ${meeting.language}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryGray,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transcript section — conversational format (Speaker: dialogue)
          if (meeting.transcript != null && meeting.transcript!.isNotEmpty) ...[
            const _SectionLabel('Conversation Transcript'),
            const SizedBox(height: 8),
            _ConversationBlock(meeting.transcript!),
            const SizedBox(height: 20),
          ],

          // Translation section
          if (meeting.translation != null && meeting.translation!.isNotEmpty) ...[
            const _SectionLabel('English Translation'),
            const SizedBox(height: 8),
            _TextBlock(meeting.translation!),
            const SizedBox(height: 20),
          ],

          // MoM section — structured if available
          const _SectionLabel('Minutes of Meeting'),
          const SizedBox(height: 8),
          if (meeting.momSections != null && meeting.momSections!.isNotEmpty)
            ..._buildMomSections(meeting.momSections!)
          else
            _TextBlock(summary),
          const SizedBox(height: 32),

          // Delete audio button
          if (!_audioDeleted)
            _deletingAudio
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                    onPressed: _confirmDeleteAudio,
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFFF3B30)),
                    label: const Text('Delete Audio Recording'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF3B30),
                      side: const BorderSide(color: Color(0xFFFF3B30)),
                    ),
                  )
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    color: Color(0xFF34C759), size: 18),
                SizedBox(width: 6),
                Text(
                  'Audio deleted',
                  style: TextStyle(
                    color: Color(0xFF34C759),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppTheme.secondaryGray,
      ),
    );
  }
}

class _ConversationBlock extends StatelessWidget {
  const _ConversationBlock(this.text);
  final String text;

  List<MapEntry<String, String>> _turns() {
    final turns = <MapEntry<String, String>>[];
    final blocks = text.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      final colonIndex = trimmed.indexOf(': ');
      if (colonIndex > 0) {
        turns.add(MapEntry(
          trimmed.substring(0, colonIndex).trim(),
          trimmed.substring(colonIndex + 2).trim(),
        ));
      } else {
        turns.add(MapEntry('Speaker', trimmed));
      }
    }

    if (turns.isEmpty && text.trim().isNotEmpty) {
      turns.add(MapEntry('Speaker', text.trim()));
    }
    return turns;
  }

  @override
  Widget build(BuildContext context) {
    final turns = _turns();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fillGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: turns.map((turn) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turn.key,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  turn.value,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppTheme.primaryBlack,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BulletBlock extends StatelessWidget {
  const _BulletBlock(this.text);
  final String text;

  List<String> _lines() {
    if (text.trim().isEmpty || text.trim().toLowerCase() == 'not mentioned') {
      return const ['Not mentioned'];
    }
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('- ') ? line.substring(2).trim() : line)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _lines();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fillGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '•  ',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppTheme.primaryBlack,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppTheme.primaryBlack,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fillGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.primaryBlack,
        ),
      ),
    );
  }
}
