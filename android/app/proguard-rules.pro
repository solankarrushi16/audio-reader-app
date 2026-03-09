# Keep ML Kit vision/text classes (needed when minification is enabled)
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_bundled.** { *; }

# Keep Flutter TTS plugin classes
-keep class com.eyedeadevelopment.fluttertts.** { *; }

# Keep Kotlin metadata (helps with reflection)
-keepclassmembers class kotlin.Metadata { *; }
