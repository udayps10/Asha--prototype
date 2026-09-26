import '../../../core/common_widgets/aasha_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/common_widgets/app_button.dart';
import '../../../features/matching/data/models/match_request.dart';
import '../../../features/matching/data/models/match_result.dart';
import '../../../features/matching/data/models/match_response.dart';
import '../../../features/matching/data/repositories/match_repository.dart';
import '../../../features/matching/data/services/match_api_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _matchRepository = MatchRepository(HttpMatchApiService());
  List<NormalMatchResult> _matches = [];
  MatchRequest? _request;
  String? _requestId;
  String? _nextPageToken;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _fetchMatches();
    }
  }

  Future<void> _fetchMatches() async {
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is! MatchRequest) {
      setState(() => _isLoading = false);
      return;
    }
    _request = args;

    try {
      final response = await _matchRepository.findMatches(args);
      if (mounted) {
        setState(() {
          _applyResponse(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e);
      }
    }
  }

  void _applyResponse(MatchResponse response) {
    _matches = response.results.whereType<NormalMatchResult>().toList();
    _requestId = response.requestId;
    _nextPageToken = response.nextPageToken;
    _hasMore = response.hasMore;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore ||
        !_hasMore ||
        _requestId == null ||
        _nextPageToken == null) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final response = await _matchRepository.getMoreMatches(
        MatchPageRequest(requestId: _requestId!, pageToken: _nextPageToken!),
      );
      if (mounted) {
        setState(() {
          _matches.addAll(response.results.whereType<NormalMatchResult>());
          _nextPageToken = response.nextPageToken;
          _hasMore = response.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _showError(e);
      }
    }
  }

  void _showError(Object error) {
    final message = error is MatchApiException
        ? error.message
        : 'Unable to load matches. Please try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final topN = _matches;

    return Scaffold(
      appBar: AppBar(title: const Text('Possible Matches')),
      body: AashaSurface(
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_search,
                        size: 76,
                        color: Color(0xFF073450),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Searching for matches…',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Comparing the details you provided with response records.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 28),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _matches.isEmpty
                          ? 'No strong matches found.'
                          : '${_matches.length} possible matches found',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ...topN.map((record) => _buildRecordCard(context, record)),

                    if (_matches.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      if (_hasMore) ...[
                        const Text(
                          "Didn't find your person?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          text: 'View More Matches',
                          isLoading: _isLoadingMore,
                          onPressed: _loadMore,
                        ),
                      ] else if (_matches.length <= 3) ...[
                        const Text(
                          "Still haven't found your person?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 32),
                    _buildCriticalEntryBox(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCriticalEntryBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check Critical Records?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Some people may be listed in critical records. Their photographs are never shown here. We only display identifying information that may help you recognize them.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Search Critical Records',
            color: Colors.red,
            onPressed: () {
              final args = _request;
              Navigator.pushNamed(
                context,
                '/critical_results',
                arguments: args,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, NormalMatchResult record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: record.photoUrl == null || record.photoUrl!.isEmpty
                    ? Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.person, color: Colors.grey),
                      )
                    : Image.network(
                        record.photoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.person, color: Colors.grey),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    Text(
                      'Age: ${record.age}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${_formatConfidence(record.matchConfidence)}% Match Score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (record.matchLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getLabelColor(record.matchLabel!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              record.matchLabel!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (record.explanation != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        record.explanation!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${record.campName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Status: ${(record.status ?? 'unknown').replaceAll('_', ' ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(NormalMatchResult record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Person Details')),
          body: AashaSurface(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 36,
                            child: Icon(Icons.person_outline, size: 42),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            record.name,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_formatConfidence(record.matchConfidence)}% match • Confirm with officials',
                          ),
                          const SizedBox(height: 20),
                          ListTile(
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: const Text('Age'),
                            subtitle: Text('${record.age} years'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.home_work_outlined),
                            title: const Text('Camp'),
                            subtitle: Text(record.campName),
                          ),
                          ListTile(
                            leading: const Icon(Icons.shield_outlined),
                            title: const Text('Status'),
                            subtitle: Text(
                              (record.status ?? 'Unknown').replaceAll('_', ' '),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: const Text('Reporting official'),
                            subtitle: Text(record.officerName),
                          ),
                          ListTile(
                            leading: const Icon(Icons.phone_outlined),
                            title: const Text('Official contact'),
                            subtitle: SelectableText(record.officerContact),
                          ),
                          if (record.explanation != null)
                            Text(
                              record.explanation!,
                              style: const TextStyle(height: 1.5),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: record.officerContact),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Official contact copied'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy official contact'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A possible match is not a confirmed identity. Contact the reporting official before making arrangements.',
                    style: TextStyle(color: Color(0xFF536D86), height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatConfidence(num confidence) => confidence % 1 == 0
      ? confidence.toInt().toString()
      : confidence.toString();

  Color _getLabelColor(String label) {
    return switch (label) {
      'Strong Match' => Colors.green,
      'Possible Match' => Colors.orange,
      'Weak Match' => Colors.blueGrey,
      _ => Colors.grey,
    };
  }
}
