# The JNI (libsword_android.so) finds these by name: classes, methods and fields. Keep them as they are.
-keep class org.logoshub.sword.SwordNative { *; }
-keep class org.logoshub.sword.SwordNative$* { *; }
-keepclassmembers class * implements org.logoshub.sword.SwordNative$HttpFetcher { public *; }
-keepclassmembers class * implements org.logoshub.sword.SwordNative$ProgressListener { public *; }
-keepclassmembers class * implements org.logoshub.sword.SwordNative$StatusListener { public *; }
