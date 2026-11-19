import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/app_config.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/reset_password_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/game/presentation/screens/game_mode_selection_screen.dart';
import '../../features/game/presentation/screens/game_board_screen.dart';
import '../../features/game/presentation/screens/match_result_screen.dart';
import '../../features/game/presentation/screens/offline_match_setup_screen.dart';
import '../../features/game/presentation/screens/quick_match_screen.dart';
import '../../features/multiplayer/presentation/screens/create_room_screen.dart';
import '../../features/multiplayer/presentation/screens/join_room_screen.dart';
import '../../features/multiplayer/presentation/screens/room_lobby_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/rewards/presentation/screens/daily_rewards_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// Centralised routing for the whole app using go_router.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash',      builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding',   builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/login',       builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register',    builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/forgot',      builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset',        builder: (c, s) {
        final token = (s.uri.queryParameters['token'] ?? '');
        return ResetPasswordScreen(token: token);
      }),

      // Home shell with bottom navigation
      ShellRoute(
        builder: (c, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home',          builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/leaderboard',   builder: (c, s) => const LeaderboardScreen()),
          GoRoute(path: '/history',       builder: (c, s) => const HistoryScreen()),
          GoRoute(path: '/profile',       builder: (c, s) => const ProfileScreen()),
        ],
      ),

      // Game setup & play
      GoRoute(path: '/game/modes',      builder: (c, s) => const GameModeSelectionScreen()),
      GoRoute(path: '/game/offline-setup', builder: (c, s) => const OfflineMatchSetupScreen()),
      GoRoute(path: '/game/quick-match', builder: (c, s) {
        final args = s.extra as Map<String, dynamic>? ?? const {};
        final maxPlayers = args['maxPlayers'] as int? ?? 4;
        return QuickMatchScreen(maxPlayers: maxPlayers);
      }),
      GoRoute(path: '/game/play',        builder: (c, s) {
        final configArg = s.extra as Map<String, dynamic>?;
        return GameBoardScreen(configArg: configArg ?? const {});
      }),
      GoRoute(path: '/game/result',      builder: (c, s) {
        final args = s.extra as Map<String, dynamic>? ?? const {};
        return MatchResultScreen(args: args);
      }),

      // Multiplayer
      GoRoute(path: '/rooms/create',    builder: (c, s) => const CreateRoomScreen()),
      GoRoute(path: '/rooms/join',       builder: (c, s) => const JoinRoomScreen()),
      GoRoute(path: '/rooms/lobby',      builder: (c, s) {
        final code = (s.uri.queryParameters['code'] ?? '');
        return RoomLobbyScreen(roomCode: code);
      }),

      // Misc
      GoRoute(path: '/profile/edit',    builder: (c, s) => const EditProfileScreen()),
      GoRoute(path: '/rewards',         builder: (c, s) => const DailyRewardsScreen()),
      GoRoute(path: '/wallet',          builder: (c, s) => const WalletScreen()),
      GoRoute(path: '/settings',         builder: (c, s) => const SettingsScreen()),
    ],
    redirect: (context, state) {
      final path = state.uri.path;
      // Public routes that don't require auth
      const publicRoutes = [
        '/splash', '/onboarding', '/login', '/register', '/forgot', '/reset'
      ];
      final isPublic = publicRoutes.any((p) => path.startsWith(p));
      if (isPublic) return null;
      if (!AppConfig.isLoggedIn) return '/login';
      return null;
    },
  );
}
