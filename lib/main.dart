import 'dart:async';

import 'package:flutter/material.dart';

import 'data/pulse_store.dart';
import 'data/persistence/local_backend.dart';
import 'data/platform/ad_backend_impl.dart';
import 'data/platform/admob_provider.dart';
import 'data/platform/billing_backend_impl.dart';
import 'data/platform/billing_gateway.dart';
import 'data/platform/local_notification_scheduler.dart';
import 'data/platform/notification_backend_impl.dart';
import 'theme/pulse_theme.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart';
import 'widgets/pulse_components.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/today/today_screen.dart';
import 'screens/nutrition/logging_screens.dart';
import 'screens/diary/diary_screens.dart';
import 'screens/train/train_screens.dart';
import 'screens/progress/progress_screens.dart';
import 'screens/coach/coach_screens.dart';
import 'screens/profile/settings_screens.dart';
import 'screens/profile/premium_screens.dart';
import 'screens/widgets_watch/widgets_watch_screen.dart';

/// Whether to wire the real billing, ads and notification plugins.
/// Off by default so tests and `flutter run` on a bare checkout use the
/// stubs; a store build passes `--dart-define=PULSE_PLATFORM_SERVICES=true`.
const bool kUsePlatformServices =
    bool.fromEnvironment('PULSE_PLATFORM_SERVICES');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PulseApp());
}

class PulseApp extends StatefulWidget {
  const PulseApp({super.key, this.store});

  /// Injectable store — tests pass a pre-hydrated instance.
  final PulseStore? store;

  @override
  State<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends State<PulseApp> with WidgetsBindingObserver {
  late final PulseStore _store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.store != null) {
      _store = widget.store!;
    } else {
      // Async bootstrap: create store, restore from local disk, then swap
      // the visible scope. Splash covers the (few-ms) hydrate window.
      _store = PulseStore();
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final repo = SharedPreferencesLocalRepository();
    try {
      if (kUsePlatformServices) {
        _store.purchaseGateway =
            InAppPurchaseGateway(backend: InAppPurchaseBackend());
      }
      await _store.attachPersistence(repo,
          reminderScheduler: kUsePlatformServices ? _scheduler() : null);
      // §3: a snapshot can be days old. File whatever day it describes
      // before any screen reads today's figures as current.
      _store.rolloverIfNeeded();
    } catch (e) {
      // Persistence failure must never block the app (§74 error posture).
      debugPrint('PULSE persistence unavailable: $e');
    }
    if (kUsePlatformServices) unawaited(_initAds());
    if (mounted) setState(() {}); // re-scope with hydrated store if swapped
  }

  /// Real OS scheduling, behind the same seam the stub uses.
  LocalNotificationScheduler _scheduler() => LocalNotificationScheduler(
      backend: FlutterLocalNotificationsBackend());

  Future<void> _initAds() async {
    try {
      final provider = AdMobProvider(
          backend: GoogleMobileAdsBackend(),
          units: AdUnitIds.fromEnvironment());
      await provider.initialize();
      _store.adProvider = provider;
    } catch (e) {
      // No ads is a degraded state, never a blocked app (§61).
      debugPrint('PULSE ads unavailable: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never lose a log: force pending autosaves when backgrounding.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _store.flushPendingSave();
    }
    // Monetization hygiene: settle any expired trial when the app resumes so
    // entitlements (and ad visibility) are correct without waiting for a tap.
    if (state == AppLifecycleState.resumed) {
      _store.settleSubscription();
      // §3: the app is routinely left open across midnight — roll the
      // day over on resume so today's figures are actually today's.
      _store.rolloverIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.flushPendingSave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PulseScope(
      store: _store,
      child: Builder(builder: (ctx) {
        final store = PulseStore.of(ctx);
        return MaterialApp(
          title: 'PULSE',
          debugShowCheckedModeBanner: false,
          theme: PulseTheme.light(highContrast: store.highContrast),
          darkTheme: PulseTheme.dark(highContrast: store.highContrast),
          themeMode: store.themeMode,
          initialRoute: '/',
          onGenerateRoute: _onGenerateRoute,
          builder: (ctx, child) {
            final media = MediaQuery.of(ctx);
            return MediaQuery(
              data: media.copyWith(
                // Compose with the platform scale rather than replacing it, so
                // a user who already enlarged text system-wide is not shrunk.
                textScaler: store.largeText
                    ? media.textScaler.clamp(minScaleFactor: kPulseLargeTextScale)
                    : media.textScaler,
                // Either source may ask for stillness; both are honoured.
                disableAnimations: store.reduceMotion || media.disableAnimations,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      }),
    );
  }
}

Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  // Screens that live inside the 5-tab shell switch tabs instead of pushing.
  const tabRoutes = {'/home': 0, '/diary': 1, '/train': 2, '/progress': 3, '/profile': 4};

  Widget page;
  switch (name) {
    case '/':
      page = const SplashScreen();
    case '/welcome':
      page = const WelcomeScreen();
    case '/signup':
      page = const SignUpScreen();
    case '/login':
      page = const LoginScreen();
    case '/forgot-password':
      page = const ForgotPasswordScreen();
    case '/onboarding':
    case '/onboarding-goals':
      page = const OnboardingScreen(step: 0);
    case '/home':
    case '/diary':
    case '/train':
    case '/progress':
    case '/profile':
      page = PulseShell(initialTab: tabRoutes[name]!);
    case '/notifications':
      page = const NotificationsScreen();
    case '/search':
      page = const GlobalSearchScreen();
    case '/coach':
      page = const CoachScreen();
    case '/food-search':
      page = FoodSearchScreen(meal: settings.arguments is MealType ? settings.arguments as MealType : MealType.lunch);
    case '/food-detail':
      final a = settings.arguments;
      page = a is (FoodItem, MealType)
          ? FoodDetailScreen(food: a.$1, meal: a.$2)
          : FoodDetailScreen(food: PulseData.foods[0], meal: MealType.lunch);
    case '/barcode':
      page = const BarcodeScannerScreen();
    case '/meal-scan':
      page = const MealScanScreen();
    case '/voice-log':
      page = const VoiceLogScreen();
    case '/nutrition-details':
      page = const NutritionDetailsScreen();
    case '/water':
      page = const WaterScreen();
    case '/recipes':
      page = const RecipesScreen();
    case '/recipe-detail':
      page = RecipeDetailScreen(recipeName: settings.arguments is String ? settings.arguments as String : PulseData.recipes.first.name);
    case '/create-recipe':
      page = const CreateRecipeScreen();
    case '/saved-meals':
      page = const SavedMealsScreen();
    case '/meal-plan':
      page = const MealPlanScreen();
    case '/grocery-list':
      page = const GroceryListScreen();
    case '/workout-library':
      page = const WorkoutLibraryScreen();
    case '/workout-detail':
      page = WorkoutDetailScreen(workoutName: settings.arguments is String ? settings.arguments as String : 'Upper Body Strength');
    case '/active-workout':
      page = ActiveWorkoutScreen(workoutName: settings.arguments is String ? settings.arguments as String : 'Upper Body Strength');
    case '/exercise-instructions':
      page = ExerciseInstructionsScreen(exerciseName: settings.arguments is String ? settings.arguments as String : 'Dumbbell Bench Press');
    case '/workout-complete':
      page = const WorkoutCompleteScreen();
    case '/activity-detail':
      page = const ActivityDetailScreen();
    case '/log-exercise':
      page = const LogExerciseScreen();
    case '/steps':
      page = const StepsScreen();
    case '/habits':
      page = const HabitsScreen();
    case '/weight-progress':
      page = const WeightProgressScreen();
    case '/log-weight':
      page = const LogWeightScreen();
    case '/nutrition-progress':
      page = const NutritionProgressScreen();
    case '/activity-progress':
      page = const ActivityProgressScreen();
    case '/measurements':
      page = const MeasurementsScreen();
    case '/progress-photos':
      page = const ProgressPhotosScreen();
    case '/weekly-report':
      page = const WeeklyReportScreen();
    case '/insights':
      page = const InsightsScreen();
    case '/streaks':
      page = const StreaksScreen();
    case '/goals':
      page = const GoalsScreen();
    case '/goal-editor':
      page = const GoalEditorScreen();
    case '/personal-details':
      page = const PersonalDetailsScreen();
    case '/nutrition-prefs':
      page = const NutritionPrefsScreen();
    case '/workout-prefs':
      page = const WorkoutPrefsScreen();
    case '/connected-apps':
      page = const ConnectedAppsScreen();
    case '/notification-settings':
      page = const NotificationSettingsScreen();
    case '/privacy':
      page = const PrivacyScreen();
    case '/accessibility':
      page = const AccessibilityScreen();
    case '/subscription':
      page = const SubscriptionScreen();
    case '/paywall':
      page = PaywallSheet(featureName: settings.arguments is String ? settings.arguments as String : null);
    case '/widgets-watch':
      page = const WidgetsWatchScreen();
    default:
      page = _UnknownRouteScreen(route: name);
  }

  if (settings.arguments is bool && settings.arguments == true) {
    return PageRouteBuilder(pageBuilder: (_, __, ___) => page, transitionsBuilder: fadeTransition);
  }
  return MaterialPageRoute(builder: (_) => page, settings: settings);
}

Widget fadeTransition(BuildContext _, Animation<double> anim, Animation __, Widget child) =>
    FadeTransition(opacity: anim, child: child);

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen({required this.route});
  final String route;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: EmptyState(
        icon: Icons.explore_off_rounded,
        title: 'We couldn\'t find that page',
        body: 'Route "$route" isn\'t part of PULSE yet. Head back to Today and continue from there.',
        actionLabel: 'Back to Today',
        onAction: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// APP SHELL — five-section bottom navigation (§10) with contextual
/// + Log FAB. Tab routes (/home /diary /train /progress /profile)
/// resolve here so deep links never stack multiple shells.
/// ═══════════════════════════════════════════════════════════════════
class PulseShell extends StatefulWidget {
  const PulseShell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<PulseShell> createState() => _PulseShellState();
}

class _PulseShellState extends State<PulseShell> {
  late int _tab = widget.initialTab;

  static const _tabs = <({String label, IconData icon, IconData active})>[
    (label: 'Today', icon: Icons.today_outlined, active: Icons.today_rounded),
    (label: 'Diary', icon: Icons.menu_book_outlined, active: Icons.menu_book_rounded),
    (label: 'Train', icon: Icons.fitness_center_outlined, active: Icons.fitness_center_rounded),
    (label: 'Progress', icon: Icons.insights_outlined, active: Icons.insights_rounded),
    (label: 'Profile', icon: Icons.person_outline_rounded, active: Icons.person_rounded),
  ];

  void _setTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const TodayScreen(),
      const DiaryScreen(),
      const TrainScreen(),
      const ProgressScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      // D2: centerDocked over a five-destination NavigationBar put the FAB on
      // top of the middle tab — Train — hiding its icon and label. endFloat
      // keeps all five tabs reachable; the bar's own padding clears the FAB.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FloatingActionButton(
          onPressed: () => openQuickLog(context),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          tooltip: '+ Log',
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.6))),
        ),
        child: NavigationBar(
          height: 66,
          selectedIndex: _tab,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
          onDestinationSelected: (i) {
            if (i == 2) context.pulse.track('train_tab_opened');
            _setTab(i);
          },
          destinations: [
            for (final t in _tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.active),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}
