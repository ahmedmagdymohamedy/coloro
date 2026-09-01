# Room generates a `<Database>_Impl` subclass and instantiates it reflectively
# via its no-arg constructor. R8 full mode (the AGP 8 default) cannot see that
# call and strips the constructor, so Room throws InstantiationException at
# startup: "Failed to create an instance of androidx.work.impl.WorkDatabase".
#
# This reaches us through play-services-ads, which pins androidx.work 2.7.0 —
# a Room version predating the consumer rules that newer releases ship.
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# AppLovin's bundled OMID library optionally attests through Amazon's
# Privacy Pass on Amazon devices; the classes are compile-time only and
# absent from our dependency graph. Safe to suppress — the code path is
# guarded at runtime.
-dontwarn com.amazon.privacypass.PrivacyPass
-dontwarn com.amazon.privacypass.VerificationContext
-dontwarn com.amazon.privacypass.callback.AttestAPICallback
