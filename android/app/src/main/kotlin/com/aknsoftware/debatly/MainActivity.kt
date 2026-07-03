package com.aknsoftware.debatly

import io.flutter.embedding.android.FlutterFragmentActivity

// RevenueCat's paywall UI (purchases_ui_flutter) requires a FragmentActivity on
// Android — extending FlutterActivity would crash when presenting the paywall.
class MainActivity : FlutterFragmentActivity()
