import 'package:go_router/go_router.dart';

import 'root_navigator_key.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/tasks/screens/my_tasks_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/participants/screens/participants_screen.dart';
import '../../features/participants/screens/my_invitations_screen.dart';
import '../../features/events/screens/home_screen.dart';
import '../../features/events/screens/create_event_screen.dart';
import '../../features/events/screens/event_details_screen.dart';
import '../../features/events/screens/edit_event_screen.dart';
import '../../features/events/screens/location_picker_screen.dart';
import '../../features/date_votes/screens/date_voting_screen.dart';
import '../../features/chat/screens/chat_screen.dart';

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/events/create',
      builder: (context, state) => const CreateEventScreen(),
    ),
    GoRoute(
      path: '/events/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);

        return EditEventScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);

        return EventDetailsScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/events/:id/tasks',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);

        return TasksScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/my-tasks',
      builder: (context, state) => const MyTasksScreen(),
    ),
    GoRoute(
      path: '/events/:id/expenses',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);

        return ExpensesScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/events/:id/participants',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);

        return ParticipantsScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/invitations',
      builder: (context, state) => const MyInvitationsScreen(),
    ),
    GoRoute(
      path: '/location-picker',
      builder: (context, state) {
        final extra = state.extra as Map<String, double?>?;

        return LocationPickerScreen(
          initialLatitude: extra?['latitude'],
          initialLongitude: extra?['longitude'],
        );
      },
    ),
    GoRoute(
      path: '/events/:id/date-votes',
      builder: (context, state) {
        final eventId = int.parse(state.pathParameters['id']!);

        return DateVotingScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:id/chat',
      builder: (context, state) {
        final eventId = int.parse(state.pathParameters['id']!);

        return ChatScreen(eventId: eventId);
      },
    ),
  ],
);
