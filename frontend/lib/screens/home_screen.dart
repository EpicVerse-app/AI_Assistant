import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/offline_queue.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_utils.dart';
import 'mom_result_screen.dart';
import 'processing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onSearchTap,
    this.onNewMeetingTap,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onNewMeetingTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _pendingCount = 0;
  bool _syncing = false;
  List<Map<String, dynamic>> _meetings = [];
  bool _loadingMeetings = true;
  String? _loadError;
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([_refreshPendingCount(), _loadMeetings()]);
  }

  Future<void> _refreshPendingCount() async {
    final count = await OfflineQueue.pendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _loadMeetings() async {
    setState(() {
      _loadingMeetings = true;
      _loadError = null;
    });
    try {
      final meetings = await ApiService.getMeetings();
      if (mounted) setState(() => _meetings = meetings);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMeetings = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final uploaded = await OfflineQueue.syncPending();
    await _refresh();
    setState(() => _syncing = false);

    if (uploaded.isNotEmpty && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingScreen(meetingId: uploaded.first),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending recordings to sync.')),
      );
    }
  }

  Future<void> _confirmDeleteMeeting(Map<String, dynamic> m) async {
    final meetingId = m['meeting_id'] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: const Text(
          'This removes the transcript and meeting minutes from the server. '
          'Your audio recording saved on this device will be kept.',
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
              style: TextStyle(color: AppTheme.priorityHigh),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ApiService.deleteMeeting(meetingId);
      if (mounted) {
        setState(() {
          _meetings.removeWhere((item) => item['meeting_id'] == meetingId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Meeting deleted. Audio is still saved on this device.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete meeting: $e')),
        );
      }
    }
  }

  Future<void> _openMeeting(Map<String, dynamic> m) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final meeting = await ApiService.getMeetingDetail(m['meeting_id'] as String);
      if (mounted) {
        Navigator.of(context).pop(); // close loader
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.secondaryGray,
              ),
            ),
            Text(
              AuthService.instance.user?.displayName ?? 'User',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom + 80,
          ),
          children: [
            // Offline sync banner
            if (_pendingCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 20, color: Color(0xFF856404)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_pendingCount recording${_pendingCount > 1 ? 's' : ''} waiting to upload',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF856404),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _syncNow,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                            ),
                            child: const Text('Sync Now'),
                          ),
                  ],
                ),
              ),

            // New meeting button
            GestureDetector(
              onTap: widget.onNewMeetingTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8D6736), Color(0xFFB18850)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8D6736).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'New Meeting',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            const Text(
              'RECENT MEETINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.secondaryGray,
              ),
            ),
            const SizedBox(height: 12),

            // Meeting list
            if (_loadingMeetings)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading meetings…',
                        style: TextStyle(
                          color: AppTheme.secondaryGray,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'First load may take a minute while the server wakes up.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.secondaryGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loadError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off_outlined,
                          size: 36, color: AppTheme.secondaryGray),
                      const SizedBox(height: 8),
                      const Text(
                        'Could not load meetings',
                        style: TextStyle(
                            color: AppTheme.secondaryGray, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _loadMeetings,
                          child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_meetings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Your meeting minutes will appear here.',
                    style: TextStyle(
                      color: AppTheme.secondaryGray,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ...(_meetings.map((m) => _MeetingCard(
                    meeting: m,
                    onTap: () => _openMeeting(m),
                    onDelete: () => _confirmDeleteMeeting(m),
                  ))),
          ],
        ),
      ),
    );
  }
}

// ── Meeting card ──────────────────────────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.meeting,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> meeting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _formatDate(Map<String, dynamic> meeting) =>
      DateTimeUtils.formatCardDateTime(
        meeting['created_at'] as String?,
        epochMs: DateTimeUtils.epochMsFromJson(meeting),
      );

  @override
  Widget build(BuildContext context) {
    final status = meeting['status'] as String? ?? '';
    final language = meeting['language'] as String?;
    final preview = meeting['summary_preview'] as String? ??
        meeting['transcript_preview'] as String?;
    final hasSummary = meeting['has_summary'] as bool? ?? false;
    final topic = meeting['meeting_topic'] as String?;
    final isDone = status == 'done';
    final isFailed = status == 'failed';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDone ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.fillGray,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: date + status badge
            Row(
              children: [
                const Icon(Icons.mic_none,
                    size: 16, color: AppTheme.secondaryGray),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDate(meeting),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlack,
                    ),
                  ),
                ),
                _StatusBadge(status: status),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppTheme.secondaryGray),
                  tooltip: 'Delete meeting',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),

            // Language tag + topic
            if (language != null || (topic != null && topic != 'Not mentioned')) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (language != null)
                    _TagChip(label: language),
                  if (topic != null && topic != 'Not mentioned')
                    _TagChip(label: topic),
                ],
              ),
            ],

            // MoM / transcript preview
            if (preview != null && preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.primaryBlack,
                ),
              ),
            ],

            // Footer
            if (isDone) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    hasSummary
                        ? Icons.description_outlined
                        : Icons.text_snippet_outlined,
                    size: 14,
                    color: AppTheme.accentBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasSummary ? 'View meeting minutes' : 'View transcript',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.secondaryGray),
                ],
              ),
            ],

            if (isFailed) ...[
              const SizedBox(height: 8),
              const Text(
                'Processing failed — no speech detected',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFFFF3B30)),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.borderGray,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.secondaryGray,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'done'       => ('Done', const Color(0xFF34C759), const Color(0xFFEAF9ED)),
      'failed'     => ('Failed', const Color(0xFFFF3B30), const Color(0xFFFFEEED)),
      'processing' => ('Processing', const Color(0xFFFF9500), const Color(0xFFFFF4E5)),
      _            => ('Uploaded', AppTheme.secondaryGray, AppTheme.borderGray),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
