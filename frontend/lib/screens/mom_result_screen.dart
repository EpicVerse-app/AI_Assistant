import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meeting.dart';
import '../services/meeting_audio_controller.dart';
import '../services/local_audio_storage.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/mom_parser.dart';
import '../widgets/meeting_audio_panel.dart';

class MomResultScreen extends StatefulWidget {
  const MomResultScreen({super.key, required this.meeting});

  final Meeting meeting;

  @override
  State<MomResultScreen> createState() => _MomResultScreenState();
}

class _MomResultScreenState extends State<MomResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _summaryExpanded = true;
  int? _audioDurationSeconds;
  late final MeetingAudioController _audioController;

  Map<String, String> get _mom => widget.meeting.momSections ?? {};

  String get _title =>
      _mom['meeting_topic']?.trim().isNotEmpty == true &&
              _mom['meeting_topic']!.toLowerCase() != 'not mentioned'
          ? _mom['meeting_topic']!
          : 'Meeting Review';

  List<String> get _summaryBullets => MomParser.bulletLines(_mom['summary']);
  List<String> get _decisionBullets => MomParser.bulletLines(_mom['decisions']);
  List<String> get _deadlineBullets => MomParser.bulletLines(_mom['deadlines']);
  List<String> get _riskBullets =>
      MomParser.bulletLines(_mom['important_notes']);
  List<String> get _attendees => MomParser.attendees(_mom['attendees']);
  List<ParsedActionItem> get _actionItems =>
      MomParser.actionItems(_mom['action_items']);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
    _audioDurationSeconds = widget.meeting.durationSeconds;
    _audioController = MeetingAudioController()..listen();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    final localDuration = await LocalAudioStorage.getLocalDurationSeconds(
      widget.meeting.meetingId,
    );
    if (localDuration != null && mounted) {
      setState(() => _audioDurationSeconds = localDuration);
    }

    final info = await ApiService.getAudioInfo(widget.meeting.meetingId);
    if (info != null && mounted) {
      final secs = info['duration_seconds'];
      if (secs is num) {
        setState(() => _audioDurationSeconds = secs.round());
      }
    }

    if (mounted) {
      await _audioController.load(widget.meeting.meetingId);
      if (_audioController.duration.inSeconds > 0 && mounted) {
        setState(
          () => _audioDurationSeconds = _audioController.duration.inSeconds,
        );
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    final text = widget.meeting.summary ?? '';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting minutes copied to clipboard.')),
    );
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy minutes'),
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MeetingHeader(
              title: _title,
              onBack: () => Navigator.pop(context),
              onShare: _copyToClipboard,
              onMenu: _showMenu,
            ),
            _MetaPills(
              date: MomParser.formatDisplayDate(
                meeting.meetingDate ?? _mom['meeting_date'],
                meeting.createdAt,
              ),
              time: MomParser.formatDisplayTime(
                meeting.meetingTime,
                meeting.createdAt,
              ),
              duration: meeting.displayDuration.isNotEmpty
                  ? meeting.displayDuration
                  : MomParser.formatDuration(_audioDurationSeconds),
              language: meeting.language,
            ),
            _StatsRow(
              attendees: _attendees.length,
              topics: _summaryBullets.length,
              decisions: _decisionBullets.length,
              actionItems: _actionItems.length,
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'TRANSCRIPT'),
                Tab(text: 'AUDIO'),
                Tab(text: 'FILES'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(
                    summaryExpanded: _summaryExpanded,
                    onToggleSummary: () =>
                        setState(() => _summaryExpanded = !_summaryExpanded),
                    summaryBullets: _summaryBullets,
                    decisionBullets: _decisionBullets,
                    actionItems: _actionItems,
                    riskBullets: _riskBullets,
                    deadlineBullets: _deadlineBullets,
                    attendees: _attendees,
                  ),
                  _TranscriptTab(
                    transcript: meeting.transcript,
                    translation: meeting.translation,
                  ),
                  MeetingAudioPanel(controller: _audioController),
                  _FilesTab(
                    meeting: meeting,
                    hasAudio: _audioController.available,
                  ),
                ],
              ),
            ),
            if (_audioController.available && _tabController.index != 2)
              MeetingAudioMiniBar(controller: _audioController),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _MeetingHeader extends StatelessWidget {
  const _MeetingHeader({
    required this.title,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlack,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined, size: 22),
          ),
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.more_vert, size: 22),
          ),
        ],
      ),
    );
  }
}

// ─── Meta pills ───────────────────────────────────────────────────────────────

class _MetaPills extends StatelessWidget {
  const _MetaPills({
    required this.date,
    required this.time,
    required this.duration,
    this.language,
  });

  final String date;
  final String time;
  final String duration;
  final String? language;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _MetaChip(icon: Icons.calendar_today_outlined, label: date),
          const SizedBox(width: 8),
          _MetaChip(icon: Icons.access_time, label: time),
          if (duration.isNotEmpty) ...[
            const SizedBox(width: 8),
            _MetaChip(icon: Icons.timer_outlined, label: duration),
          ],
          if (language != null && language!.isNotEmpty) ...[
            const SizedBox(width: 8),
            _MetaChip(icon: Icons.mic_outlined, label: language!),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.secondaryGray),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryBlack,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.attendees,
    required this.topics,
    required this.decisions,
    required this.actionItems,
  });

  final int attendees;
  final int topics;
  final int decisions;
  final int actionItems;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.people_outline,
              iconColor: AppTheme.statBlue,
              count: attendees,
              label: 'Attendees',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.topic_outlined,
              iconColor: AppTheme.statGreen,
              count: topics,
              label: 'Topics',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle_outline,
              iconColor: AppTheme.statPurple,
              count: decisions,
              label: 'Decisions',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.assignment_outlined,
              iconColor: AppTheme.statOrange,
              count: actionItems,
              label: 'Action Items',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.secondaryGray,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.summaryExpanded,
    required this.onToggleSummary,
    required this.summaryBullets,
    required this.decisionBullets,
    required this.actionItems,
    required this.riskBullets,
    required this.deadlineBullets,
    required this.attendees,
  });

  final bool summaryExpanded;
  final VoidCallback onToggleSummary;
  final List<String> summaryBullets;
  final List<String> decisionBullets;
  final List<ParsedActionItem> actionItems;
  final List<String> riskBullets;
  final List<String> deadlineBullets;
  final List<String> attendees;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionCard(
          icon: Icons.summarize_outlined,
          iconColor: AppTheme.primaryPurple,
          title: 'Executive Summary',
          trailing: IconButton(
            onPressed: onToggleSummary,
            icon: Icon(
              summaryExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: AppTheme.secondaryGray,
            ),
          ),
          child: summaryExpanded
              ? Text(
                  MomParser.executiveSummary(summaryBullets),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppTheme.primaryBlack,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.format_list_numbered,
          iconColor: AppTheme.statBlue,
          title: 'Agenda',
          child: summaryBullets.isEmpty
              ? const Text(
                  'Not mentioned',
                  style: TextStyle(color: AppTheme.secondaryGray),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < summaryBullets.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                summaryBullets[i],
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.check_circle_outline,
          iconColor: AppTheme.statGreen,
          title: 'Key Decisions',
          child: _CheckList(items: decisionBullets),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.assignment_outlined,
          iconColor: AppTheme.statOrange,
          title: 'Action Items',
          child: actionItems.isEmpty
              ? const Text(
                  'Not mentioned',
                  style: TextStyle(color: AppTheme.secondaryGray),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionItemsTable(items: actionItems),
                    if (actionItems.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'View All Tasks',
                          style: TextStyle(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SectionCard(
                icon: Icons.warning_amber_outlined,
                iconColor: AppTheme.statOrange,
                title: 'Risks / Concerns',
                child: _BulletList(
                  items: riskBullets,
                  emptyLabel: 'None noted',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SectionCard(
                icon: Icons.event_outlined,
                iconColor: AppTheme.primaryPurple,
                title: 'Next Meeting',
                child: deadlineBullets.isEmpty
                    ? const Text(
                        'Not scheduled',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryGray,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in deadlineBullets.take(2))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                item,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.people_outline,
          iconColor: AppTheme.primaryPurple,
          title: 'Attendees',
          trailing: TextButton(
            onPressed: () {},
            child: const Text('View All'),
          ),
          child: attendees.isEmpty
              ? const Text(
                  'Not mentioned',
                  style: TextStyle(color: AppTheme.secondaryGray),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final name in attendees)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _AttendeeChip(name: name),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Transcript tab ───────────────────────────────────────────────────────────

class _TranscriptTab extends StatelessWidget {
  const _TranscriptTab({this.transcript, this.translation});

  final String? transcript;
  final String? translation;

  @override
  Widget build(BuildContext context) {
    if ((transcript == null || transcript!.isEmpty) &&
        (translation == null || translation!.isEmpty)) {
      return const Center(
        child: Text(
          'No transcript available.',
          style: TextStyle(color: AppTheme.secondaryGray),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (transcript != null && transcript!.isNotEmpty) ...[
          const Text(
            'CONVERSATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.secondaryGray,
            ),
          ),
          const SizedBox(height: 8),
          _ConversationBlock(transcript!),
        ],
        if (translation != null && translation!.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'ENGLISH TRANSLATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.secondaryGray,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration,
            child: Text(
              translation!,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Files tab ────────────────────────────────────────────────────────────────

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.meeting, required this.hasAudio});

  final Meeting meeting;
  final bool hasAudio;

  @override
  Widget build(BuildContext context) {
    final files = <({String name, IconData icon, bool available})>[
      (
        name: 'Meeting Minutes (MoM)',
        icon: Icons.description_outlined,
        available: meeting.momSections != null || meeting.summary != null,
      ),
      (
        name: 'Transcript',
        icon: Icons.chat_bubble_outline,
        available: meeting.transcript?.isNotEmpty == true,
      ),
      (
        name: 'Translation',
        icon: Icons.translate,
        available: meeting.translation?.isNotEmpty == true,
      ),
      (
        name: 'Audio Recording',
        icon: Icons.audiotrack_outlined,
        available: hasAudio,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final file = files[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(file.icon, color: AppTheme.primaryPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  file.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                file.available ? Icons.check_circle : Icons.remove_circle_outline,
                color: file.available
                    ? AppTheme.statGreen
                    : AppTheme.secondaryGray,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

class _CheckList extends StatelessWidget {
  const _CheckList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Not mentioned',
        style: TextStyle(color: AppTheme.secondaryGray),
      );
    }
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle,
                    color: AppTheme.statGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.emptyLabel});

  final List<String> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: const TextStyle(fontSize: 13, color: AppTheme.secondaryGray),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 13)),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionItemsTable extends StatelessWidget {
  const _ActionItemsTable({required this.items});

  final List<ParsedActionItem> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(4).toList();
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                'Task',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryGray,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Owner',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryGray,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Due',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryGray,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Priority',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryGray,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 16),
        for (final item in visible) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  item.task,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: _OwnerAvatar(name: item.owner),
              ),
              Expanded(
                child: Text(
                  item.dueDate == 'Not mentioned' ? '—' : item.dueDate,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Expanded(child: _PriorityBadge(priority: item.priority)),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    if (name == '—' || name.toLowerCase() == 'not mentioned') {
      return const Text('—', style: TextStyle(fontSize: 12));
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppTheme.primaryPurpleLight,
      child: Text(
        MomParser.initials(name),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryPurple,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final isHigh = priority == 'High';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (isHigh ? AppTheme.priorityHigh : AppTheme.priorityMedium)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isHigh ? AppTheme.priorityHigh : AppTheme.priorityMedium,
        ),
      ),
    );
  }
}

class _AttendeeChip extends StatelessWidget {
  const _AttendeeChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryPurpleLight,
            child: Text(
              MomParser.initials(name),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Participant',
            style: TextStyle(fontSize: 11, color: AppTheme.secondaryGray),
          ),
          const SizedBox(height: 4),
          const Icon(Icons.mic_none, size: 14, color: AppTheme.secondaryGray),
        ],
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
      decoration: AppTheme.cardDecoration,
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
                    color: AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  turn.value,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
