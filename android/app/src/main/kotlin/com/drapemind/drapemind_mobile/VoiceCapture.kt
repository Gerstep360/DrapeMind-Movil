package com.drapemind.drapemind_mobile

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Short microphone recordings stay in memory and are sent only on explicit stop. */
class VoiceCapture(private val activity: Activity) {
    private var permissionResult: MethodChannel.Result? = null
    private var recorder: AudioRecord? = null
    private var thread: Thread? = null
    private var audio = ByteArrayOutputStream()
    @Volatile private var recording = false

    fun handle(method: String, result: MethodChannel.Result) {
        when (method) {
            "startVoice" -> {
                if (recording || permissionResult != null) { result.error("BUSY", "Ya hay una grabación en curso.", null); return }
                if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    permissionResult = result
                    activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 6203)
                } else start(result)
            }
            "stopVoice" -> {
                stop()
                val pcm = audio.toByteArray(); audio.reset()
                if (pcm.size < 6400) { result.error("TOO_SHORT", "Habla unos segundos y vuelve a intentarlo.", null); return }
                val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                header.put("RIFF".toByteArray()).putInt(36+pcm.size).put("WAVEfmt ".toByteArray())
                header.putInt(16).putShort(1).putShort(1).putInt(16000).putInt(32000).putShort(2).putShort(16)
                header.put("data".toByteArray()).putInt(pcm.size)
                result.success(header.array()+pcm)
            }
            "cancelVoice" -> { close(); result.success(null) }
        }
    }
    fun permission(requestCode: Int, results: IntArray): Boolean {
        if (requestCode != 6203) return false
        val result = permissionResult ?: return true
        permissionResult = null
        if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) start(result)
        else result.error("MIC_PERMISSION", "Permite el micrófono en los ajustes de DrapeMind para grabar tu consulta.", null)
        return true
    }
    @Suppress("MissingPermission")
    private fun start(result: MethodChannel.Result) {
        try {
            val size = maxOf(4096, AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT))
            val record = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, 16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size)
            if (record.state != AudioRecord.STATE_INITIALIZED) { record.release(); throw IllegalStateException() }
            audio = ByteArrayOutputStream(); recorder = record; record.startRecording(); recording = true
            thread = Thread {
                val buffer = ByteArray(4096)
                while (recording && audio.size() < 1920000) {
                    val count = record.read(buffer, 0, minOf(buffer.size,1920000-audio.size()))
                    if (count <= 0) break
                    audio.write(buffer,0,count)
                }
                recording = false
            }.apply { start() }
            result.success(null)
        } catch (e: Exception) { stop(); result.error("MIC_UNAVAILABLE", "No pudimos abrir el micrófono. Cierra otras grabaciones y reintenta.", null) }
    }
    private fun stop() {
        recording = false
        try { recorder?.stop() } catch (_: Exception) { }
        thread?.join(1500); thread = null
        recorder?.release(); recorder = null
    }
    fun close() {
        stop(); audio.reset()
        permissionResult?.error("CANCELLED", "Grabación cancelada.", null); permissionResult = null
    }
}
