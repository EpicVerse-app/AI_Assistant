import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_utils.dart';
import 'mom_result_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _allMeetings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _query = _controller.text));
    _loadMeetings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings() async {
    try {
      final meetings = await ApiService.getMeetings();
      if (mounted) setState(() => _allMeetings = meetings);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _allMeetings.where((m) {
      final topic = (m['meeting_topic'] as String? ?? '').toLowerCase();
      final transcript =
          (m['transcript_preview'] as String? ?? '').toLowerCase();
      final summary =
          (m['summary_preview'] as String? ?? '').toLowerCase();
      return topic.contains(q) ||
          transcript.contains(q) ||
          summary.contains(q);
    }).toList();
  }

  Future<void> _openMeeting(Map<String, dynamic> m) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final meeting =
          await ApiService.getMeetingDetail(m['meeting_id'] as String);
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MomResultScreen(meeting: meeting),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load meeting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final queryEmpty = _query.trim().isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Actions')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : queryEmpty
                    ? const Center(
                        child: Text(
                          'No actions yet',
                          style: TextStyle(
                              color: AppTheme.secondaryGray, fontSize: 14),
                        ),
                      )
                    : results.isEmpty
                        ? const Center(
                            child: Text(
                              'No meetings found',
                              style: TextStyle(
                                  color: AppTheme.secondaryGray, fontSize: 14),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final m = results[i];
                              final topic =
                                  m['meeting_topic'] as String? ?? '';
                              final preview =
                                  m['summary_preview'] as String? ??
                                      m['transcript_preview'] as String? ??
                                      '';
                              final dateStr =
                                  DateTimeUtils.formatCardDateTime(
                                m['created_at'] as String?,
                                epochMs:
                                    DateTimeUtils.epochMsFromJson(m),
                              );
                              final isDone =
                                  (m['status'] as String?) == 'done';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.mic_none,
                                    color: AppTheme.secondaryGray),
                                title: Text(
                                  topic.isNotEmpty &&
                                          topic != 'Not mentioned'
                                      ? topic
                                      : dateStr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: preview.isNotEmpty
                                    ? Text(
                                        preview,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      )
                                    : Text(dateStr,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.secondaryGray)),
                                onTap:
                                    isDone ? () => _openMeeting(m) : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
