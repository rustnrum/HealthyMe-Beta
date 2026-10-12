package com.rustnrum.healthyme.beta03

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.CipherOutputStream
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/** Encrypted, user-selected backup file. SAF destinations survive uninstall.
 * No INTERNET permission used; passwords are never stored.
 */
class SalusBackupBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        private const val SAVE_CODE = 9171
        private const val RESTORE_CODE = 9172
        private val MAGIC = "SALUS71!".toByteArray(Charsets.US_ASCII)
        private const val PBKDF2_ITERATIONS = 210000
        private const val MAX_BACKUP_BYTES = 32L * 1024L * 1024L
    }

    private var pending: MethodChannel.Result? = null
    private var pendingPath: String? = null
    private var pendingPassword: String? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveEncrypted" && call.method != "restoreEncrypted") {
            result.notImplemented(); return
        }
        if (pending != null) {
            result.error("BUSY", "Finish the existing backup operation first", null); return
        }
        val password = call.argument<String>("password") ?: ""
        if (password.length < 12) {
            result.error("PASSWORD", "A backup password of at least 12 characters is required", null); return
        }
        try {
            pending = result
            pendingPassword = password
            if (call.method == "saveEncrypted") {
                val path = call.argument<String>("path") ?: ""
                val source = File(path)
                if (!source.isFile || !source.canonicalPath.startsWith(activity.cacheDir.canonicalPath + File.separator) ||
                    source.length() <= 0 || source.length() > MAX_BACKUP_BYTES) {
                    fail("SOURCE", "Missing or invalid private backup file"); return
                }
                pendingPath = path
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/octet-stream"
                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("filename") ?: "Salus-Backup.salus")
                }
                @Suppress("DEPRECATION")
                activity.startActivityForResult(intent, SAVE_CODE)
            } else {
                pendingPath = null
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                @Suppress("DEPRECATION")
                activity.startActivityForResult(intent, RESTORE_CODE)
            }
        } catch (e: Exception) { fail("DOCUMENT", e.message ?: "Unable to open document picker") }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_CODE && requestCode != RESTORE_CODE) return false
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            fail("CANCELLED", "Backup file selection cancelled"); return true
        }
        val result = pending ?: return true
        val password = pendingPassword ?: return true
        val path = pendingPath
        // Don't block the Android UI thread on encryption or file I/O.
        Thread {
            try {
                val output = if (requestCode == SAVE_CODE) {
                    if (path == null) throw IllegalStateException("Missing source file")
                    encrypt(File(path), uri, password)
                    "saved"
                } else {
                    decrypt(uri, password)
                }
                main.post { result.success(output); clear() }
            } catch (e: Exception) {
                main.post { result.error("BACKUP_FAILED", e.message ?: "Backup operation failed", null); clear() }
            }
        }.start()
        return true
    }

    private fun key(password: String, salt: ByteArray): SecretKeySpec {
        val chars = password.toCharArray()
        val spec = PBEKeySpec(chars, salt, PBKDF2_ITERATIONS, 256)
        return try {
            val raw = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
            SecretKeySpec(raw, "AES")
        } finally {
            spec.clearPassword()
            chars.fill('\u0000')
        }
    }

    private fun encrypt(source: File, uri: Uri, password: String) {
        val random = SecureRandom()
        val salt = ByteArray(16).also(random::nextBytes)
        val iv = ByteArray(12).also(random::nextBytes)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.ENCRYPT_MODE, key(password, salt), GCMParameterSpec(128, iv))
            updateAAD(MAGIC)
        }
        val out = activity.contentResolver.openOutputStream(uri, "w")
            ?: throw IllegalStateException("Cannot write selected file")
        out.use { stream ->
            stream.write(MAGIC); stream.write(salt); stream.write(iv)
            CipherOutputStream(stream, cipher).use { encrypted ->
                source.inputStream().use { input -> input.copyTo(encrypted) }
            }
        }
    }

    private fun decrypt(uri: Uri, password: String): String {
        val dest = File.createTempFile("salus-restore-", ".json", activity.cacheDir)
        try {
            val input = activity.contentResolver.openInputStream(uri)
                ?: throw IllegalStateException("Cannot read selected file")
            DataInputStream(input).use { stream ->
                val magic = ByteArray(MAGIC.size)
                stream.readFully(magic)
                if (!magic.contentEquals(MAGIC)) {
                    throw IllegalArgumentException("Not a supported Salus backup file")
                }
                val salt = ByteArray(16); val iv = ByteArray(12)
                stream.readFully(salt)
                stream.readFully(iv)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
                    init(Cipher.DECRYPT_MODE, key(password, salt), GCMParameterSpec(128, iv))
                    updateAAD(MAGIC)
                }
                // Authenticate entire GCM payload before writing any plaintext.
                // CipherInputStream can swallow integrity failures on some JREs.
                val ciphertext = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    if (ciphertext.size().toLong() + count > MAX_BACKUP_BYTES + 16) {
                        throw IllegalArgumentException("Backup file is too large")
                    }
                    ciphertext.write(buffer, 0, count)
                }
                val plaintext = cipher.doFinal(ciphertext.toByteArray())
                dest.writeBytes(plaintext)
            }
            return dest.absolutePath
        } catch (e: Exception) {
            dest.delete()
            throw IllegalArgumentException("Cannot decrypt backup: wrong password, corrupt file, or invalid format", e)
        }
    }

    private fun fail(code: String, message: String) {
        pending?.error(code, message, null)
        clear()
    }
    private fun clear() { pending = null; pendingPath = null; pendingPassword = null }
}
