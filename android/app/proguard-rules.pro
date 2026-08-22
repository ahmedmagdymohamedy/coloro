# Room generates a `<Database>_Impl` subclass and instantiates it reflectively
# via its no-arg constructor. R8 full mode (the AGP 8 default) cannot see that
# call and strips the constructor, so Room throws InstantiationException at
# startup: "Failed to create an instance of androidx.work.impl.WorkDatabase".
#
# This reaches us through play-services-ads, which pins androidx.work 2.7.0 —
# a Room version predating the consumer rules that newer releases ship.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
