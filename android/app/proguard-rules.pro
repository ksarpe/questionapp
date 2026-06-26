# Project-specific R8/ProGuard keep rules for the release build.
#
# Flutter enables R8 code shrinking + obfuscation for release builds. Some
# libraries instantiate generated classes reflectively, so R8 must be told not
# to strip the members it can't see being called.
#
# (No app-specific rules currently needed — the Room/WorkManager keeps lived
# here only for the home_widget plugin, which has since been removed.)
