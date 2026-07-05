# Project-specific R8/ProGuard keep rules for the release build.
#
# Flutter enables R8 code shrinking + obfuscation for release builds. Some
# libraries instantiate generated classes reflectively, so R8 must be told not
# to strip the members it can't see being called.

# --- WorkManager + Room --------------------------------------------------
# androidx.work:work-runtime (pulled in transitively — play-services-ads →
# androidx.work) auto-initialises WorkManager through androidx.startup at
# PROCESS START, before any Dart code runs. WorkManager builds its Room
# database by reflectively loading the Room-generated `WorkDatabase_Impl`
# (Room computes the impl name from the DB class's own name + "_Impl", so BOTH
# the abstract DB and its generated impl must keep their original names). R8
# was renaming/stripping those, so Room threw
#   "Failed to create an instance of androidx.work.impl.WorkDatabase"
# and the app crashed on launch — a NATIVE crash no Dart try/catch can catch,
# which is why release/Play-Store builds "open then immediately close".
#
# These keeps previously lived here for the now-removed home_widget plugin and
# were deleted with it; WorkManager is still present transitively, so they are
# required. See android/app/build.gradle.kts (R8 is on for release).
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.work.**
