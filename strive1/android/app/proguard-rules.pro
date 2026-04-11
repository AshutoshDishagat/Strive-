# Flutter Local Notifications / ML Kit / Firebase duplicate class avoidance rules
-dontwarn com.google.firebase.iid.**
-keep class com.google.firebase.iid.** { *; }

# General Flutter / Google Play Services protection
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
