package com.cakewallet.bitbox_flutter

import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Raw USB transport for the dart:ffi bridge (channel "bitbox_usb_transport").
 *
 * Go issues read/write requests through Dart; this class performs them on background
 * threads so a read that waits for the user to confirm on the device never blocks the
 * platform thread.
 */
class BitboxUsbTransport(private val usbManager: UsbManager) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newCachedThreadPool { runnable ->
        Thread(runnable, "bitbox-usb-io").apply { isDaemon = true }
    }

    @Volatile
    private var session: Session? = null

    private class Session(
        val device: UsbDevice,
        val connection: UsbDeviceConnection,
        val usbInterface: UsbInterface,
        val endpointIn: UsbEndpoint,
        val endpointOut: UsbEndpoint,
    ) {
        @Volatile
        var closed = false

        // Transfers hold the read lock; teardown takes the write lock so the connection is
        // never closed underneath an in-flight bulkTransfer.
        val lock = ReentrantReadWriteLock()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> open(call.argument<String>("identifier"), result)
            "read" -> read(call.argument<Int>("length") ?: 0, result)
            "write" -> write(call.argument<ByteArray>("data") ?: ByteArray(0), result)
            "close" -> close { result.success(null) }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        close {}
        ioExecutor.shutdown()
    }

    private fun open(identifier: String?, result: MethodChannel.Result) {
        val device = usbManager.deviceList[identifier]
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "No USB device with identifier $identifier", null)
            return
        }
        if (!usbManager.hasPermission(device)) {
            result.error("NO_PERMISSION", "USB permission not granted for $identifier", null)
            return
        }

        val usbInterface = device.getInterface(0)
        var endpointIn: UsbEndpoint? = null
        var endpointOut: UsbEndpoint? = null
        for (i in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(i)
            when (endpoint.direction) {
                UsbConstants.USB_DIR_IN -> endpointIn = endpoint
                UsbConstants.USB_DIR_OUT -> endpointOut = endpoint
            }
        }
        if (endpointIn == null || endpointOut == null) {
            result.error("NO_ENDPOINTS", "Interface 0 has no IN/OUT endpoint pair", null)
            return
        }

        val connection = usbManager.openDevice(device)
        if (connection == null) {
            result.error("OPEN_FAILED", "Could not open USB device", null)
            return
        }
        if (!connection.claimInterface(usbInterface, true)) {
            connection.close()
            result.error("CLAIM_FAILED", "Could not claim USB interface", null)
            return
        }

        val previous = session
        session = Session(device, connection, usbInterface, endpointIn, endpointOut)
        previous?.let { teardown(it) {} }
        result.success(null)
    }

    private fun read(length: Int, result: MethodChannel.Result) {
        val s = session ?: return result.error("NOT_OPEN", "Transport is not open", null)
        ioExecutor.execute {
            try {
                val data = readBlocking(s, length)
                reply { result.success(data) }
            } catch (e: IOException) {
                reply { result.error("READ_FAILED", e.message, null) }
            }
        }
    }

    /**
     * Polls with a short timeout instead of blocking indefinitely, so close() and device
     * detachment are noticed within [READ_POLL_TIMEOUT_MS].
     */
    @Throws(IOException::class)
    private fun readBlocking(s: Session, length: Int): ByteArray {
        val buffer = ByteArray(length)
        while (true) {
            val n = s.lock.read {
                if (s.closed) throw IOException("Transport closed")
                s.connection.bulkTransfer(s.endpointIn, buffer, length, READ_POLL_TIMEOUT_MS)
            }
            if (n > 0) return buffer.copyOf(n)
            // -1 is returned for both a timeout and a real failure; tell them apart.
            if (n < 0 && !isAttached(s.device)) throw IOException("Device disconnected")
        }
    }

    private fun write(data: ByteArray, result: MethodChannel.Result) {
        val s = session ?: return result.error("NOT_OPEN", "Transport is not open", null)
        ioExecutor.execute {
            try {
                s.lock.read {
                    if (s.closed) throw IOException("Transport closed")
                    val n = s.connection.bulkTransfer(s.endpointOut, data, data.size, WRITE_TIMEOUT_MS)
                    if (n != data.size) throw IOException("Wrote $n of ${data.size} bytes")
                }
                reply { result.success(null) }
            } catch (e: IOException) {
                reply { result.error("WRITE_FAILED", e.message, null) }
            }
        }
    }

    private fun close(onDone: () -> Unit) {
        val s = session
        session = null
        if (s == null) {
            onDone()
            return
        }
        teardown(s) { reply(onDone) }
    }

    private fun teardown(s: Session, onDone: () -> Unit) {
        s.closed = true
        ioExecutor.execute {
            s.lock.write {
                s.connection.releaseInterface(s.usbInterface)
                s.connection.close()
            }
            onDone()
        }
    }

    private fun isAttached(device: UsbDevice): Boolean =
        usbManager.deviceList.values.any { it.deviceId == device.deviceId }

    // MethodChannel.Result must be completed on the platform thread.
    private fun reply(block: () -> Unit) {
        mainHandler.post(block)
    }

    companion object {
        const val CHANNEL = "bitbox_usb_transport"
        private const val READ_POLL_TIMEOUT_MS = 250
        private const val WRITE_TIMEOUT_MS = 5000
    }
}
