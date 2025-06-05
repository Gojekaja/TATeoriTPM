import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/game_screen.dart';
import '../screens/store_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../services/auth_service.dart';
import 'route_names.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      debugPrint('GoRouter redirect: ${state.matchedLocation}');
      try {
        final isLoggedIn = AuthService().currentUser != null;
        final isAuthRoute =
            state.matchedLocation == Routes.login ||
            state.matchedLocation == Routes.register;

        debugPrint(
          'isLoggedIn: $isLoggedIn, isAuthRoute: $isAuthRoute, location: ${state.matchedLocation}',
        );

        if (!isLoggedIn && !isAuthRoute) {
          debugPrint('Redirecting to login');
          return Routes.login;
        }

        if (isLoggedIn && isAuthRoute) {
          debugPrint('Redirecting to game');
          return Routes.game;
        }

        debugPrint('No redirect needed');
        return null;
      } catch (e, stackTrace) {
        debugPrint('Error in redirect: $e');
        debugPrint('Stack trace: $stackTrace');
        return Routes.login;
      }
    },
    routes: [
      // Auth routes
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Main app routes
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.store,
                builder: (context, state) => const StoreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.game,
                builder: (context, state) => const GameScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Error: ${state.error}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    ),
  );
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        backgroundColor: Colors.black87,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.store, color: Colors.grey),
            selectedIcon: Icon(Icons.store, color: Colors.white),
            label: 'Store',
          ),
          NavigationDestination(
            icon: Icon(Icons.gamepad, color: Colors.grey),
            selectedIcon: Icon(Icons.gamepad, color: Colors.white),
            label: 'Game',
          ),
          NavigationDestination(
            icon: Icon(Icons.person, color: Colors.grey),
            selectedIcon: Icon(Icons.person, color: Colors.white),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
