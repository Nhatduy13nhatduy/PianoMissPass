package com.example.flutter_midi_16kb

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class FlutterMidi16kbPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        init {
            System.loadLibrary("flutter_midi_16kb")
        }
    }

    private external fun nativeInitialize(): Boolean
    private external fun nativeLoadSoundfont(path: String): Boolean
    private external fun nativeUnloadSoundfont(): Boolean
    private external fun nativePlayNote(channel: Int, key: Int, velocity: Int)
    private external fun nativeStopNote(channel: Int, key: Int)
    private external fun nativeStopAllNotes()
    private external fun nativeChangeProgram(channel: Int, program: Int)
    private external fun nativeDispose()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_midi_16kb")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        nativeInitialize()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> result.success(nativeInitialize())
            "loadSoundfont" -> {
                val path = call.argument<String>("path")
                result.success(if (path != null) nativeLoadSoundfont(path) else false)
            }
            "unloadSoundfont" -> result.success(nativeUnloadSoundfont())
            "playNote" -> {
                val ch = call.argument<Int>("channel") ?: 0
                val key = call.argument<Int>("key") ?: 60
                val vel = call.argument<Int>("velocity") ?: 100
                nativePlayNote(ch, key, vel)
                result.success(null)
            }
            "stopNote" -> {
                val ch = call.argument<Int>("channel") ?: 0
                val key = call.argument<Int>("key") ?: 60
                nativeStopNote(ch, key)
                result.success(null)
            }
            "stopAllNotes" -> {
                nativeStopAllNotes()
                result.success(null)
            }
            "changeProgram" -> {
                val ch = call.argument<Int>("channel") ?: 0
                val prog = call.argument<Int>("program") ?: 0
                nativeChangeProgram(ch, prog)
                result.success(null)
            }
            "dispose" -> {
                nativeDispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        nativeDispose()
    }
}
