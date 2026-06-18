import 'package:chronoflow/core/router/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart'; // Your dark mode setup
import 'features/history/edit_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // Wrap the app in ProviderScope for Riverpod
    const ProviderScope(
      child: ChronoflowApp(),
    ),
  );
}

// Basic Router Setup
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainLayout(),
      ),
      // Add /history, /entities here later

      GoRoute(
        path: '/edit/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return EditScreen(thoughtId: id);
        },
      ),
    ],
  );
});

class ChronoflowApp extends ConsumerWidget {
  const ChronoflowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Chronoflow',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
