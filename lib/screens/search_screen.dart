import 'package:flutter/material.dart';

import '../data/search_data.dart';
import '../models/memory_detail.dart';
import '../theme/app_theme.dart';
import 'memory_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _query = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SearchResult> get _results => SearchData.query(_query);

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().isEmpty
        ? SearchData.allResults
        : _results;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search memories',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _controller.clear,
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = results[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(result.icon, color: result.accentColor),
                  title: Text(result.title),
                  subtitle: Text(
                    result.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    final detail = MemoryDetail.sample(
                      title: result.title,
                      accentColor: result.accentColor,
                      icon: result.icon,
                      duration: result.duration,
                      date: DateTime.now(),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MemoryDetailScreen(memory: detail),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
