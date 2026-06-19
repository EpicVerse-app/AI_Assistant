import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/onboarding_illustrations.dart';
import '../widgets/page_indicator.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  double _currentPage = 0;

  static const _pageContent = [
    (
      title: 'Record Every\nConversation',
      subtitle:
          'Capture meetings, calls, and ideas effortlessly. Never miss an important moment again.',
    ),
    (
      title: 'AI Understands\nMeetings',
      subtitle:
          'Smart AI extracts action items, decisions, and insights from every conversation automatically.',
    ),
    (
      title: 'Search Memories\nInstantly',
      subtitle:
          'Find anything you discussed in seconds. Your entire memory, searchable and organized.',
    ),
  ];

  bool get _isLastPage => _currentPage.round() >= _pageContent.length - 1;

  Widget _illustrationForIndex(int index, double size) {
    switch (index) {
      case 0:
        return RecordConversationIllustration(size: size);
      case 1:
        return AiMeetingsIllustration(size: size);
      case 2:
        return SearchMemoriesIllustration(size: size);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    setState(() => _currentPage = _pageController.page ?? 0);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _goToNextPage() {
    if (_isLastPage) {
      _finishOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isCompact = screenHeight < 750;
    final illustrationSize = isCompact ? 240.0 : 280.0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isLastPage)
                    TextButton(
                      onPressed: _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.secondaryGray,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pageContent.length,
                itemBuilder: (context, index) {
                  final content = _pageContent[index];
                  return _OnboardingPage(
                    title: content.title,
                    subtitle: content.subtitle,
                    illustration: _illustrationForIndex(index, illustrationSize),
                    isCompact: isCompact,
                    pageIndex: index,
                    currentPage: _currentPage,
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                0,
                28,
                mediaQuery.padding.bottom > 0 ? 12 : 28,
              ),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    count: _pageContent.length,
                    currentPage: _currentPage,
                  ),
                  SizedBox(height: isCompact ? 24 : 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: FilledButton(
                      key: ValueKey(_isLastPage),
                      onPressed: _goToNextPage,
                      child: Text(_isLastPage ? 'Get Started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.isCompact,
    required this.pageIndex,
    required this.currentPage,
  });

  final String title;
  final String subtitle;
  final Widget illustration;
  final bool isCompact;
  final int pageIndex;
  final double currentPage;

  @override
  Widget build(BuildContext context) {
    final distance = (currentPage - pageIndex).abs().clamp(0.0, 1.0);
    final opacity = 1.0 - distance * 0.45;
    final scale = 1.0 - distance * 0.08;
    final translateY = distance * 24;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Expanded(
            flex: isCompact ? 5 : 6,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: illustration,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: isCompact ? 3 : 2,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCompact ? 30 : 34,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlack,
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: isCompact ? 14 : 18),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 17,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.secondaryGray,
                    height: 1.45,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
