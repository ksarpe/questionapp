# Project-specific R8/ProGuard keep rules for the release build.
#
# Flutter enables R8 code shrinking + obfuscation for release builds. Some
# libraries instantiate generated classes reflectively, so R8 must be told not
# to strip the members it can't see being called.

# --- Room / WorkManager -----------------------------------------------------
# WorkManager (pulled in transitively by the home_widget plugin) stores its
# state in a Room database. Room loads the generated `*_Impl` class by name and
# calls its no-arg constructor via reflection. Under R8 full mode the consumer
# rules don't preserve that constructor, so it gets stripped and launch crashes
# with "Failed to create an instance of androidx.work.impl.WorkDatabase"
# (InstantiationException). Keep every RoomDatabase subclass and its no-arg ctor.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep @androidx.room.Entity class * { *; }
-dontwarn androidx.room.paging.**

# WorkManager touches some classes only through the manifest / reflection.
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.**
