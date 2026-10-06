# Optional SLF4J binding referenced by pusher-websocket-java; not needed at runtime.
-dontwarn org.slf4j.impl.StaticLoggerBinder

# Pusher's Java client deserializes its protocol messages with Gson via reflection.
-keep class com.pusher.** { *; }
-keepattributes Signature, *Annotation*
