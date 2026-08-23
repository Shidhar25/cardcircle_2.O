import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/state/auth_state.dart';
import '../../features/feed/state/feed_state.dart';
import '../../features/circle/state/circle_state.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/discover_screen.dart';
import '../../features/feed/presentation/how_to_apply_screen.dart';
import '../../features/feed/presentation/notifications_screen.dart';
import '../widgets/neo_pop_button.dart';

/// Helper wrapper that injects AppTheme & Providers for isolated Widget Previews
Widget _buildPreviewWrapper(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthState()),
      ChangeNotifierProvider(create: (_) => FeedState()),
      ChangeNotifierProvider(create: (_) => CircleState()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: child,
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// SCREEN PREVIEWS
// -----------------------------------------------------------------------------

@Preview(name: 'Feed Screen Dashboard')
Widget previewFeedScreen() {
  return _buildPreviewWrapper(
    FeedScreen(onNavigateToProfile: () {}),
  );
}

@Preview(name: 'Discover Screen')
Widget previewDiscoverScreen() {
  return _buildPreviewWrapper(const DiscoverScreen());
}

@Preview(name: 'How to Apply Screen')
Widget previewHowToApplyScreen() {
  return _buildPreviewWrapper(const HowToApplyScreen());
}

@Preview(name: 'Notifications Screen')
Widget previewNotificationsScreen() {
  return _buildPreviewWrapper(const NotificationsScreen());
}

// -----------------------------------------------------------------------------
// UI COMPONENT PREVIEWS
// -----------------------------------------------------------------------------

@Preview(name: 'Primary NeoPop Button')
Widget previewPrimaryNeoPopButton() {
  return _buildPreviewWrapper(
    Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: NeoPopButton.primary(
          onPressed: () {},
          child: const NeoPopButtonText(
            'Approve Access',
            color: Colors.black,
          ),
        ),
      ),
    ),
  );
}

@Preview(name: 'Secondary NeoPop Button')
Widget previewSecondaryNeoPopButton() {
  return _buildPreviewWrapper(
    Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: NeoPopButton.secondary(
          onPressed: () {},
          child: const NeoPopButtonText(
            'Cancel',
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
