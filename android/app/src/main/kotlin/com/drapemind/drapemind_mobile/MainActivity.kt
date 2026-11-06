package com.drapemind.drapemind_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.app.Activity
import android.speech.RecognizerIntent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private var pending: MethodChannel.Result? = null
    private var pdfBytes: ByteArray? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"drapemind/documents").setMethodCallHandler { call, result ->
            if (pending != null) { result.error("BUSY","Termina la acción anterior.",null); return@setMethodCallHandler }
            try {
                when(call.method) {
                    "dictate" -> {
                        pending=result
                        val intent=Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE,"es-BO")
                            putExtra(RecognizerIntent.EXTRA_PROMPT,"¿Qué necesitas conocer de tu tienda?")
                        }
                        startActivityForResult(intent,6201)
                    }
                    "savePdf" -> {
                        val bytes=call.argument<ByteArray>("bytes") ?: throw IllegalArgumentException("Documento vacío")
                        if(bytes.size>10*1024*1024)throw IllegalArgumentException("Documento demasiado grande")
                        pdfBytes=bytes;pending=result
                        val intent=Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE);type="application/pdf"
                            putExtra(Intent.EXTRA_TITLE,call.argument<String>("name") ?: "drapemind.pdf")
                        }
                        startActivityForResult(intent,6202)
                    }
                    else -> result.notImplemented()
                }
            } catch (e:Exception) {
                pending=null;pdfBytes=null
                result.error("UNAVAILABLE","No se pudo abrir la acción. Puedes escribir la consulta o reintentar la descarga.",null)
            }
        }
    }
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode!=6201 && requestCode!=6202)return
        val result=pending ?: return
        pending=null
        try {
            if(requestCode==6201) {
                result.success(if(resultCode==Activity.RESULT_OK)data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null)
            } else {
                val uri=data?.data;val bytes=pdfBytes
                if(resultCode!=Activity.RESULT_OK || uri==null || bytes==null)result.success(false)
                else {
                    val stream=contentResolver.openOutputStream(uri) ?: throw IllegalStateException("Destino no disponible")
                    stream.use { it.write(bytes) };result.success(true)
                }
            }
        } catch(e:Exception) { result.error("SAVE_FAILED","No se pudo guardar el documento.",null) }
        finally {pdfBytes=null}
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "drapemind_alerts"
            val channelName = "Alertas DrapeMind"
            val channelDescription = "Notificaciones de pedidos, reservas y novedades del atelier"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
