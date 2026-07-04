# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# gRPC / OkHttp (used by grpc-dart's native transport on Android)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class io.grpc.** { *; }

# Protocol Buffers
-keep class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
    <methods>;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Dart/Flutter native bindings — do not strip JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# SQLite (drift_flutter / sqlite3_flutter_libs)
-keep class org.sqlite.** { *; }
-keep class sqlite3.** { *; }

# Google Play Core (referenced by Flutter's deferred component support)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitinstall.**

# Huawei HMS / HiAnalytics
-dontwarn com.huawei.hms.**
-dontwarn com.huawei.hianalytics.**
-dontwarn com.huawei.libcore.**
-dontwarn com.huawei.secure.**

# Cronet / Chromium
-dontwarn org.chromium.net.**
-dontwarn org.chromium.net.impl.**

# Conscrypt
-dontwarn org.conscrypt.**

# BouncyCastle
-dontwarn org.bouncycastle.crypto.**
-dontwarn org.bouncycastle.jsse.**
