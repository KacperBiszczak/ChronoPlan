import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/events/screens/home_screen.dart';
import '../../features/events/screens/create_event_screen.dart';
import '../../features/events/screens/event_details_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/events/create',
      builder: (context, state) => const CreateEventScreen(),
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
  ],
);