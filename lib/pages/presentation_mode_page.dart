import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import the pages you want to display in the loop
// Corrected import paths to match the likely file names
import 'loco_shed_page.dart';
import 'todays_outage.dart';
import 'scheduled_locos_page.dart';
import 'loco_forecast.dart';

class PresentationPage extends StatefulWidget {
  const PresentationPage({super.key});

  @override
  State<PresentationPage> createState() => _PresentationPageState();
}

class _PresentationPageState extends State<PresentationPage> {
  late final PageController _pageController;
  late final Timer _timer;
  int _currentPage = 0;
  bool _isMobile = false;
  bool _didChangeDependenciesRun = false;

  // List of pages to cycle through in presentation mode.
  final List<Widget> _pages = [
    const LocoShedPage(),
    const TodaysOutagePage(),
    const ScheduledLocosPage(),
    const LocoForecastPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Start a timer to automatically change pages every 20 seconds.
    _timer = Timer.periodic(const Duration(seconds: 20), (Timer timer) {
      if (!mounted) return; // Check if the widget is still in the tree

      // Calculate the next page index, looping back to 0 if at the end.
      final int nextPage = (_currentPage + 1) % _pages.length;

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This method is called after initState and has access to the context.
    // We run this logic only once.
    if (!_didChangeDependenciesRun) {
      final platform = Theme.of(context).platform;
      if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
        _isMobile = true;
        _setLandscapeMode();
      }
      _didChangeDependenciesRun = true;
    }
  }

  @override
  void dispose() {
    _timer.cancel(); // Important: cancel the timer to prevent memory leaks
    _pageController.dispose();
    if (_isMobile) {
      _resetOrientation(); // Only reset orientation if it was changed
    }
    super.dispose();
  }

  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  void _resetOrientation() {
    // Reset to default orientations (portrait and landscape allowed)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // The AppBar has been removed.
      // An exit button is now provided via the FloatingActionButton.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        tooltip: 'Exit Presentation',
        child: const Icon(Icons.exit_to_app, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        itemBuilder: (context, index) {
          return _pages[index];
        },
        // Update the current page index when the user swipes manually or the timer fires
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
      ),
    );
  }
}
