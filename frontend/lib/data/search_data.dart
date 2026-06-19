import 'package:flutter/material.dart';

class SearchResult {
  const SearchResult({
    required this.title,
    required this.snippet,
    required this.date,
    required this.duration,
    required this.category,
    required this.accentColor,
    required this.icon,
    required this.matchType,
  });

  final String title;
  final String snippet;
  final String date;
  final String duration;
  final String category;
  final Color accentColor;
  final IconData icon;
  final String matchType;
}

class SearchData {
  static const recentSearches = [
    'Q3 planning',
    'client discovery',
    'action items',
    'product roadmap',
  ];

  static const suggestedSearches = [
    'Meeting summaries',
    'Key decisions',
    'Follow-up tasks',
    'Brainstorm ideas',
    'Weekly sync notes',
  ];

  static const filters = [
    'All',
    'Meetings',
    'Calls',
    'Ideas',
    'This Week',
  ];

  static const allResults = [
    SearchResult(
      title: 'Q3 Product Planning',
      snippet:
          '...aligned on Q3 priorities, reviewed the product roadmap, and identified three critical milestones...',
      date: 'Today',
      duration: '42 min',
      category: 'Meetings',
      accentColor: Color(0xFF5856D6),
      icon: Icons.groups_rounded,
      matchType: 'Summary',
    ),
    SearchResult(
      title: 'Client Discovery Call',
      snippet:
          '...discussed enterprise requirements and transcription accuracy targets for the AI memory platform...',
      date: 'Yesterday',
      duration: '28 min',
      category: 'Calls',
      accentColor: Color(0xFF0071E3),
      icon: Icons.call_rounded,
      matchType: 'Transcript',
    ),
    SearchResult(
      title: 'Weekly Team Sync',
      snippet:
          '...cross-team sync needed between design and engineering for the memory detail experience...',
      date: 'Mon',
      duration: '35 min',
      category: 'Meetings',
      accentColor: Color(0xFF34C759),
      icon: Icons.event_note_rounded,
      matchType: 'Insight',
    ),
    SearchResult(
      title: 'Brainstorm Session',
      snippet:
          '...three new ideas captured around real-time transcription and smart search filters...',
      date: 'Sun',
      duration: '18 min',
      category: 'Ideas',
      accentColor: Color(0xFFFF9500),
      icon: Icons.lightbulb_rounded,
      matchType: 'Action Item',
    ),
    SearchResult(
      title: 'Investor Update Prep',
      snippet:
          '...prepared talking points on AI summarization beta launch and customer feedback loops...',
      date: 'Last week',
      duration: '22 min',
      category: 'Meetings',
      accentColor: Color(0xFF5856D6),
      icon: Icons.trending_up_rounded,
      matchType: 'Summary',
    ),
  ];

  static List<SearchResult> query(String text, {String filter = 'All'}) {
    final query = text.trim().toLowerCase();
    var results = allResults;

    if (filter != 'All') {
      if (filter == 'This Week') {
        results = results
            .where((r) => r.date == 'Today' || r.date == 'Yesterday' || r.date == 'Mon')
            .toList();
      } else {
        results = results.where((r) => r.category == filter).toList();
      }
    }

    if (query.isEmpty) return results;

    return results.where((result) {
      return result.title.toLowerCase().contains(query) ||
          result.snippet.toLowerCase().contains(query) ||
          result.category.toLowerCase().contains(query) ||
          result.matchType.toLowerCase().contains(query);
    }).toList();
  }
}
