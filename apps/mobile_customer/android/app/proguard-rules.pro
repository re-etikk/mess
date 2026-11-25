# Cashfree Payment Gateway SDK rules
-keep class com.cashfree.pg.** { *; }
-dontwarn com.cashfree.pg.**
-keepclassmembers class * extends android.app.Activity {
    public void *(android.view.View);
}
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Standard Flutter plugin preservation
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
