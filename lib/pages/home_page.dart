// hello
import 'package:flutter/material.dart';
import 'loco_shed_page.dart';
import 'todays_outage.dart';
import 'scheduled_locos_page.dart';
import 'loco_forecast.dart';
import 'reports_page.dart';

import 'login_page.dart';
import 'presentation_mode_page.dart';
import '../services/authentication_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final List<Map<String, dynamic>> tiles = [
    {'title': 'Loco Shed', 'icon': Icons.train},
    {'title': "Today's Outage", 'icon': Icons.warning_amber_rounded},
    {'title': "Today's Scheduled Locos", 'icon': Icons.schedule},
    {'title': "Loco's Forecast", 'icon': Icons.timeline},
    {'title': 'Reports', 'icon': Icons.insert_chart_outlined},
    {'title': 'Presentation mode', 'icon': Icons.slideshow},
  ];

  @override
  Widget build(BuildContext context) {
    print(
      'DEBUG HomePage: Building, canEdit = ${AuthenticationManager.canEdit}',
    );
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;
    int crossAxisCount;
    double aspectRatio = 2.0; // width:height = 2:1 for all platforms
    if (isWide) {
      crossAxisCount = 3;
    } else if (isTablet) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        leading: AuthenticationManager.canEdit
            ? IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () async {
                  await AuthenticationManager.signOut();
                  setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signed out - now in view-only mode'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              )
            : IconButton(
                icon: const Icon(Icons.login),
                tooltip: 'Login',
                onPressed: () async {
                  print('DEBUG HomePage: Login button pressed');
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                  print(
                    'DEBUG HomePage: Navigation returned with result: $result',
                  );
                  if (result == true) {
                    print('DEBUG HomePage: Login successful, calling setState');
                    setState(() {});
                    print(
                      'DEBUG HomePage: setState completed, canEdit = ${AuthenticationManager.canEdit}',
                    );
                    if (context.mounted) {
                      print('DEBUG HomePage: Showing success snackbar');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Successfully authenticated - can now edit',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    print('DEBUG HomePage: Login result was not true: $result');
                  }
                },
              ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AuthenticationManager.canEdit
                  ? Colors.green[100]
                  : Colors.orange[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AuthenticationManager.canEdit
                    ? Colors.green
                    : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AuthenticationManager.canEdit ? Icons.edit : Icons.visibility,
                  size: 16,
                  color: AuthenticationManager.canEdit
                      ? Colors.green[700]
                      : Colors.orange[700],
                ),
                const SizedBox(width: 4),
                Text(
                  AuthenticationManager.canEdit ? 'Edit Mode' : 'View Only',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AuthenticationManager.canEdit
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: aspectRatio,
              ),
              itemCount: tiles.length,
              itemBuilder: (context, index) {
                final tile = tiles[index];
                return Material(
                  color: const Color(0xFFE2DDB4),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (tile['title'] == 'Loco Shed') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LocoShedPage(),
                          ),
                        );
                      } else if (tile['title'] == "Today's Outage") {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TodaysOutagePage(),
                          ),
                        );
                      } else if (tile['title'] == "Today's Scheduled Locos") {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ScheduledLocosPage(),
                          ),
                        );
                      } else if (tile['title'] == "Loco's Forecast") {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LocoForecastPage(),
                          ),
                        );
                      } else if (tile['title'] == 'Reports') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ReportsPage(),
                          ),
                        );
                      } else if (tile['title'] == 'Presentation mode') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PresentationPage(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            tile['icon'],
                            size: 40,
                            color: const Color(0xFFE43636),
                          ),
                          const SizedBox(width: 18),
                          Flexible(
                            child: Text(
                              tile['title'],
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000000),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
