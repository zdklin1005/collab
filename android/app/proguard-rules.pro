# ML Kit Text Recognition optional language recognizers
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }

# UCrop and Image Cropper
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**
-keep class vn.hunghd.flutter.plugins.imagecropper.** { *; }
-dontwarn vn.hunghd.flutter.plugins.imagecropper.**