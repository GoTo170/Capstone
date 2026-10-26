package com.mamoru.mamoru_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
 
class MainActivity : FlutterActivity() {
 
    private val canal = "mamoru/sms"
    private val codigoPermisoSms = 4021
    private var respuestaPermiso: MethodChannel.Result? = null
 
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
 
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    "tienePermiso" -> resultado.success(tienePermisoSms())
                    "pedirPermiso" -> pedirPermisoSms(resultado)
                    "enviar" -> {
                        val numeros = llamada.argument<List<String>>("numeros") ?: emptyList()
                        val texto = llamada.argument<String>("texto") ?: ""
                        resultado.success(enviarSms(numeros, texto))
                    }
                    else -> resultado.notImplemented()
                }
            }
    }
 
    private fun tienePermisoSms(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED
 
    private fun pedirPermisoSms(resultado: MethodChannel.Result) {
        if (tienePermisoSms()) {
            resultado.success(true)
            return
        }
        // Si ya hay una petición en curso, se contesta "no" para no dejarla colgada.
        respuestaPermiso?.success(false)
        respuestaPermiso = resultado
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.SEND_SMS),
            codigoPermisoSms
        )
    }
 
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == codigoPermisoSms) {
            val concedido = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            respuestaPermiso?.success(concedido)
            respuestaPermiso = null
        }
    }
 
    /** Envía el SMS a cada número desde el chip del propio teléfono. */
    private fun enviarSms(numeros: List<String>, texto: String): Map<String, Int> {
        var enviados = 0
        var fallidos = 0
 
        val gestor: SmsManager? = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
        } catch (e: Exception) {
            null
        }
 
        if (gestor == null) return mapOf("enviados" to 0, "fallidos" to numeros.size)
 
        for (numero in numeros) {
            try {
                val partes = gestor.divideMessage(texto)
                if (partes.size > 1) {
                    gestor.sendMultipartTextMessage(numero, null, partes, null, null)
                } else {
                    gestor.sendTextMessage(numero, null, texto, null, null)
                }
                enviados++
            } catch (e: Exception) {
                fallidos++
            }
        }
        return mapOf("enviados" to enviados, "fallidos" to fallidos)
    }
}
