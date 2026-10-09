# google_mlkit_text_recognition references optional recognizers for scripts that
# are not bundled unless their native dependencies are added. Andi Carpetă OCR
# uses only TextRecognitionScript.latin, so these optional classes are never
# invoked at runtime. Ignore R8 warnings for the unbundled recognizers.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
