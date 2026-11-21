---
name: dart-flutter-patterns
description: Production-ready Dart and Flutter patterns covering null safety, immutable state with Freezed, async composition, widget architecture, state management (BLoC, Riverpod, Provider), GoRouter navigation with auth guards, Dio networking, error handling, and testing. Use when writing or reviewing Dart and Flutter code — state, widgets, navigation, networking, or architecture.
metadata:
  origin: ECC
---

# Dart/Flutter Patterns

> **Logic Sprint note:** this app uses **Provider** + `ChangeNotifier` engines
> (`RoundEngine`), plain `MaterialPageRoute` navigation and `supabase_flutter`.
> Apply the general patterns below (null safety, sealed types, extracted widget
> classes, `const`, `mounted` checks, fakes over mocks); do **not** introduce
> Riverpod, BLoC, GoRouter, Dio or Freezed without a decision recorded first.

## When to Use

Use this skill when:
- Starting a new Flutter feature and need idiomatic patterns for state management, navigation, or data access
- Reviewing or writing Dart code and need guidance on null safety, sealed types, or async composition
- Implementing secure HTTP clients, WebView integration, or local storage
- Writing tests for Flutter widgets and engines

## How It Works

Copy-paste-ready Dart/Flutter code patterns organized by concern:
1. **Null safety** — avoid `!`, prefer `?.`/`??`/pattern matching
2. **Immutable state** — sealed classes, `copyWith`
3. **Async composition** — concurrent `Future.wait`, safe `BuildContext` after `await`
4. **Widget architecture** — extract to classes (not methods), `const` propagation, scoped rebuilds
5. **State management** — Provider/ChangeNotifier here; BLoC and Riverpod for reference
6. **Error handling** — global capture, `ErrorWidget.builder`
7. **Testing** — unit, widget, `fake_async`, fakes over mocks

---

## 1. Null Safety Fundamentals

### Prefer Patterns Over Bang Operator

```dart
// BAD — crashes at runtime if null
final name = user!.name;

// GOOD — provide fallback
final name = user?.name ?? 'Unknown';

// GOOD — Dart 3 pattern matching (preferred for complex cases)
final display = switch (user) {
  User(:final name, :final email) => '$name <$email>',
  null => 'Guest',
};

// GOOD — guard early return
String getUserName(User? user) {
  if (user == null) return 'Unknown';
  return user.name; // promoted to non-null after check
}
```

### Avoid `late` Overuse

```dart
// BAD — defers null error to runtime
late String userId;

// GOOD — nullable with explicit initialization
String? userId;

// OK — use late only when initialization is guaranteed before first access
late final AnimationController _controller;

@override
void initState() {
  super.initState();
  _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
}
```

---

## 2. Immutable State

### Sealed Classes for State Hierarchies

```dart
sealed class UserState {}

final class UserInitial extends UserState {}

final class UserLoading extends UserState {}

final class UserLoaded extends UserState {
  const UserLoaded(this.user);
  final User user;
}

final class UserError extends UserState {
  const UserError(this.message);
  final String message;
}

// Exhaustive switch — compiler enforces all branches
Widget buildFrom(UserState state) => switch (state) {
  UserInitial() => const SizedBox.shrink(),
  UserLoading() => const CircularProgressIndicator(),
  UserLoaded(:final user) => UserCard(user: user),
  UserError(:final message) => ErrorText(message),
};
```

---

## 3. Async Composition

### Structured Concurrency with Future.wait

```dart
Future<DashboardData> loadDashboard(UserRepository users, OrderRepository orders) async {
  // Run concurrently — don't await sequentially
  final (userList, orderList) = await (
    users.getAll(),
    orders.getRecent(),
  ).wait; // Dart 3 record destructuring + Future.wait extension

  return DashboardData(users: userList, orders: orderList);
}
```

### BuildContext After Await

```dart
// CRITICAL — always check mounted after any await in StatefulWidget
Future<void> _handleSubmit() async {
  setState(() => _isLoading = true);
  try {
    await authService.login(_email, _password);
    if (!mounted) return; // ← guard before using context
    Navigator.of(context).pop();
  } on AuthException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

---

## 4. Widget Architecture

### Extract to Classes, Not Methods

```dart
// BAD — private method returning widget, prevents optimization
Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.all(16),
    child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
  );
}

// GOOD — separate widget class, enables const, element reuse
class _PageHeader extends StatelessWidget {
  const _PageHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
```

### const Propagation

```dart
// BAD — new instances every rebuild
child: Padding(
  padding: EdgeInsets.all(16.0),       // not const
  child: Icon(Icons.home, size: 24.0), // not const
)

// GOOD — const stops rebuild propagation
child: const Padding(
  padding: EdgeInsets.all(16.0),
  child: Icon(Icons.home, size: 24.0),
)
```

### Scoped Rebuilds

Isolate the part that changes. With Provider, prefer `context.select` or a small
`Consumer`/`AnimatedBuilder` around the changing widget instead of
`context.watch` at the top of a big tree.

```dart
// GOOD — only the score text rebuilds
final hearts = context.select<AppState, int>((app) => app.hearts);
```

---

## 5. State Management

### Provider + ChangeNotifier (this project)

```dart
class CounterEngine extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  void increment() { _count++; notifyListeners(); }
}

ChangeNotifierProvider(create: (_) => CounterEngine(), child: const App());

// read for callbacks, select/watch for rebuilds
context.read<CounterEngine>().increment();
final count = context.select<CounterEngine, int>((e) => e.count);
```

### BLoC / Riverpod (reference only)

Use sealed state + exhaustive `switch` in the UI, one-way data flow, and keep
side effects out of `build`. Same principles apply to `ChangeNotifier` engines.

---

## 6. Error Handling Architecture

```dart
// Global error capture — set up in main()
void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // report to your crash tool here
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    // report error
    return true;
  };

  runApp(const App());
}
```

---

## 7. Testing Quick Reference

```dart
// Unit test with fake time
test('countdown fires once', () {
  fakeAsync((async) {
    final e = GameEngine()..start();
    async.elapse(const Duration(seconds: 3));
    expect(e.isFinished, isTrue);
  });
});

// Widget test with real providers and fakes
testWidgets('shows the score', (tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: FakeAppState(score: 3), child: const MaterialApp(home: ScoreBadge())),
  );
  expect(find.text('3'), findsOneWidget);
});
```

An `AnimationController` completes on the first frame *after* its duration, so
pump `duration + one frame` in widget tests.

---

## References

- [Effective Dart: Design](https://dart.dev/effective-dart/design)
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Provider](https://pub.dev/packages/provider)
