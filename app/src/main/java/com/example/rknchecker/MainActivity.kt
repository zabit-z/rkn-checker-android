package com.example.rknchecker

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLSocket

enum class LogType {
    HEADER,
    INFO,
    SUCCESS,
    WARNING,
    ERROR,
    NORMAL
}

data class LogLine(val text: String, val type: LogType)

data class IpInfo(
    val ip: String,
    val isp: String,
    val location: String
)

data class TargetItem(
    val name: String,
    val url: String,
    val isWhitelist: Boolean
)

enum class Verdict(val label: String, val logType: LogType) {
    OK("✓ OK", LogType.SUCCESS),
    HTTP_STUB("✗ HTTP STUB", LogType.ERROR),
    TLS_BLOCK("~ LIKELY TLS DPI", LogType.WARNING),
    TCP_RESET("~ TCP RESET", LogType.WARNING),
    DNS_BLOCK("⛔ DNS BLOCK", LogType.ERROR),
    TIMEOUT("? TIMEOUT?", LogType.ERROR),
    DOWN("· DOWN", LogType.INFO),
    UNKNOWN("? UNKNOWN", LogType.INFO)
}

data class CheckResult(
    val target: TargetItem,
    var verdict: Verdict = Verdict.UNKNOWN,
    val notes: MutableList<String> = mutableListOf(),
    var sysIp: String? = null,
    var dohIp: String? = null,
    var dnsMismatch: Boolean = false,
    var tcpOk: Boolean = false,
    var tcpTimeMs: Long? = null,
    var tcpError: String? = null,
    var tlsOk: Boolean = false,
    var tlsTimeMs: Long? = null,
    var tlsError: String? = null,
    var statusCode: Int? = null,
    var pltMs: Long? = null,
    var httpError: String? = null
)

private val STUB_MARKERS = listOf(
    "доступ ограничен",
    "доступ к запрашиваемому ресурсу",
    "решению роскомнадзора",
    "решением суда",
    "по решению",
    "заблокирован",
    "blocked by",
    "rkn.gov.ru",
    "единый реестр",
    "запрещен"
)

private suspend fun fetchIpAndProvider(): Result<IpInfo> = withContext(Dispatchers.IO) {
    val errors = mutableListOf<String>()

    // Try ipinfo.io first
    try {
        val url = URL("https://ipinfo.io/json")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        if (conn.responseCode in 200..399) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            val ip = json.optString("ip", "Unknown")
            val isp = json.optString("org", "Unknown")
            val city = json.optString("city", "")
            val region = json.optString("region", "")
            val country = json.optString("country", "")
            val location = listOf(city, region, country).filter { it.isNotEmpty() }.joinToString(", ")
            return@withContext Result.success(IpInfo(ip, isp, if (location.isEmpty()) "Unknown" else location))
        } else {
            errors.add("ipinfo.io: HTTP ${conn.responseCode}")
        }
    } catch (e: Exception) {
        errors.add("ipinfo.io: ${e.javaClass.simpleName}${e.message?.let { ": $it" } ?: ""}")
    }

    // Try ipwho.is second
    try {
        val url = URL("https://ipwho.is/")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        if (conn.responseCode in 200..399) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            if (json.optBoolean("success", false)) {
                val ip = json.optString("ip", "Unknown")
                val connection = json.optJSONObject("connection")
                val isp = connection?.optString("isp") ?: connection?.optString("org") ?: "Unknown"
                val city = json.optString("city", "")
                val region = json.optString("region", "")
                val country = json.optString("country_code", "")
                val location = listOf(city, region, country).filter { it.isNotEmpty() }.joinToString(", ")
                return@withContext Result.success(IpInfo(ip, isp, if (location.isEmpty()) "Unknown" else location))
            } else {
                errors.add("ipwho.is: success=false")
            }
        } else {
            errors.add("ipwho.is: HTTP ${conn.responseCode}")
        }
    } catch (e: Exception) {
        errors.add("ipwho.is: ${e.javaClass.simpleName}${e.message?.let { ": $it" } ?: ""}")
    }

    // Try ipapi.co third
    try {
        val url = URL("https://ipapi.co/json/")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        if (conn.responseCode in 200..399) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            val ip = json.optString("ip", "Unknown")
            val isp = json.optString("org", "Unknown")
            val city = json.optString("city", "")
            val region = json.optString("region", "")
            val country = json.optString("country_name", "")
            val location = listOf(city, region, country).filter { it.isNotEmpty() }.joinToString(", ")
            return@withContext Result.success(IpInfo(ip, isp, if (location.isEmpty()) "Unknown" else location))
        } else {
            errors.add("ipapi.co: HTTP ${conn.responseCode}")
        }
    } catch (e: Exception) {
        errors.add("ipapi.co: ${e.javaClass.simpleName}${e.message?.let { ": $it" } ?: ""}")
    }

    return@withContext Result.failure(Exception(errors.joinToString(" | ")))
}

private suspend fun resolveSystemDns(host: String): String? = withContext(Dispatchers.IO) {
    try {
        val addresses = InetAddress.getAllByName(host)
        addresses.firstOrNull()?.hostAddress
    } catch (e: Exception) {
        null
    }
}

private suspend fun resolveDoh(host: String): String? = withContext(Dispatchers.IO) {
    try {
        val url = URL("https://cloudflare-dns.com/dns-query?name=$host&type=A")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.setRequestProperty("Accept", "application/dns-json")
        conn.setRequestProperty("User-Agent", "Mozilla/5.0")
        if (conn.responseCode == 200) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            val answers = json.optJSONArray("Answer")
            if (answers != null) {
                for (i in 0 until answers.length()) {
                    val obj = answers.getJSONObject(i)
                    if (obj.optInt("type") == 1) { // A record
                        return@withContext obj.optString("data")
                    }
                }
            }
        }
        conn.disconnect()
    } catch (e: Exception) {
        // DoH failed
    }
    null
}

private data class TcpCheckResult(val ok: Boolean, val timeMs: Long?, val error: String?)

private suspend fun checkTcp(host: String, port: Int = 443, timeoutMs: Int = 4000): TcpCheckResult = withContext(Dispatchers.IO) {
    val start = System.currentTimeMillis()
    try {
        val socket = Socket()
        socket.connect(InetSocketAddress(host, port), timeoutMs)
        val elapsed = System.currentTimeMillis() - start
        socket.close()
        TcpCheckResult(true, elapsed, null)
    } catch (e: SocketTimeoutException) {
        TcpCheckResult(false, null, "timeout")
    } catch (e: Exception) {
        val err = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: "")
        TcpCheckResult(false, null, err)
    }
}

private data class TlsCheckResult(val ok: Boolean, val timeMs: Long?, val error: String?)

private suspend fun checkTls(host: String, port: Int = 443, timeoutMs: Int = 4000): TlsCheckResult = withContext(Dispatchers.IO) {
    val start = System.currentTimeMillis()
    try {
        val rawSocket = Socket()
        rawSocket.connect(InetSocketAddress(host, port), timeoutMs)
        rawSocket.soTimeout = timeoutMs

        val sslFactory = HttpsURLConnection.getDefaultSSLSocketFactory()
        val sslSocket = sslFactory.createSocket(rawSocket, host, port, true) as SSLSocket

        val sslParameters = sslSocket.sslParameters
        sslParameters.serverNames = listOf(SNIHostName(host))
        sslSocket.sslParameters = sslParameters

        sslSocket.startHandshake()
        val elapsed = System.currentTimeMillis() - start
        sslSocket.close()
        TlsCheckResult(true, elapsed, null)
    } catch (e: SocketTimeoutException) {
        TlsCheckResult(false, null, "timeout")
    } catch (e: Exception) {
        val err = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: "")
        TlsCheckResult(false, null, err)
    }
}

private data class HttpCheckResult(
    val statusCode: Int?,
    val pltMs: Long?,
    val isStub: Boolean,
    val error: String?,
    val timedOut: Boolean
)

private suspend fun checkHttp(urlStr: String, timeoutMs: Int = 5000): HttpCheckResult = withContext(Dispatchers.IO) {
    val start = System.currentTimeMillis()
    try {
        val url = URL(urlStr)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.connectTimeout = timeoutMs
        conn.readTimeout = timeoutMs
        conn.instanceFollowRedirects = false
        conn.setRequestProperty(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        val statusCode = conn.responseCode
        val elapsed = System.currentTimeMillis() - start

        var isStub = false
        if (statusCode in 200..399 || statusCode == 451) {
            val stream = if (statusCode >= 400) conn.errorStream else conn.inputStream
            val body = stream?.bufferedReader()?.use { it.readText() }?.take(4000)?.lowercase() ?: ""
            isStub = statusCode == 451 || STUB_MARKERS.any { marker -> body.contains(marker) }
        }
        conn.disconnect()
        HttpCheckResult(statusCode, elapsed, isStub, null, false)
    } catch (e: SocketTimeoutException) {
        HttpCheckResult(null, null, false, "timeout", true)
    } catch (e: Exception) {
        val err = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: "")
        HttpCheckResult(null, null, false, err, false)
    }
}

private suspend fun checkTarget(target: TargetItem): CheckResult {
    val res = CheckResult(target = target)
    val host = try { URL(target.url).host } catch (e: Exception) { target.name }

    // 1. DNS
    res.sysIp = resolveSystemDns(host)
    res.dohIp = resolveDoh(host)

    if (res.sysIp == null && res.dohIp != null) {
        res.verdict = Verdict.DNS_BLOCK
        res.notes.add("system DNS doesn't resolve, DoH does — consistent with DNS poisoning")
        return res
    }

    if (res.sysIp == null && res.dohIp == null) {
        res.verdict = Verdict.DOWN
        res.notes.add("domain doesn't resolve via system DNS or DoH")
        return res
    }

    if (res.sysIp != null && res.dohIp != null && res.sysIp != res.dohIp) {
        res.dnsMismatch = true
        res.notes.add("DNS mismatch: sys=${res.sysIp} vs doh=${res.dohIp} (may indicate transparent DNS rewriting)")
    }

    // 2. TCP
    val tcpRes = checkTcp(host, 443, 4000)
    res.tcpOk = tcpRes.ok
    res.tcpTimeMs = tcpRes.timeMs
    res.tcpError = tcpRes.error

    if (!res.tcpOk) {
        val errLower = (res.tcpError ?: "").lowercase()
        if ("timeout" in errLower) {
            res.verdict = Verdict.TIMEOUT
            res.notes.add("TCP timeout on port 443 — could be IP block, route loss, or upstream congestion")
        } else if ("reset" in errLower || "rst" in errLower) {
            res.verdict = Verdict.TCP_RESET
            res.notes.add("TCP RST received — pattern matches RST injection by a middlebox, but a busy server can also send RST")
        } else {
            res.verdict = Verdict.DOWN
            res.notes.add("TCP failed: ${res.tcpError}")
        }
        return res
    }

    // 3. TLS
    val tlsRes = checkTls(host, 443, 4000)
    res.tlsOk = tlsRes.ok
    res.tlsTimeMs = tlsRes.timeMs
    res.tlsError = tlsRes.error

    if (!res.tlsOk) {
        val errLower = (res.tlsError ?: "").lowercase()
        if ("reset" in errLower || "rst" in errLower || "connection reset" in errLower) {
            res.verdict = Verdict.TLS_BLOCK
            res.notes.add("TLS reset right after ClientHello — consistent with SNI-based DPI filtering (typical TSPU/RKN signature), not proof")
        } else if ("timeout" in errLower) {
            res.verdict = Verdict.TLS_BLOCK
            res.notes.add("TLS handshake silently dropped — consistent with DPI filtering by ClientHello, but could be a flaky path")
        } else {
            res.verdict = Verdict.TLS_BLOCK
            res.notes.add("TLS error: ${res.tlsError}")
        }
        return res
    }

    // 4. HTTP
    val httpRes = checkHttp(target.url, 5000)
    res.statusCode = httpRes.statusCode
    res.pltMs = httpRes.pltMs
    res.httpError = httpRes.error

    if (httpRes.timedOut) {
        res.verdict = Verdict.TIMEOUT
        return res
    }
    if (httpRes.error != null) {
        res.verdict = Verdict.DOWN
        return res
    }

    if (res.statusCode == 451) {
        res.verdict = Verdict.HTTP_STUB
        res.notes.add("HTTP 451 — Unavailable For Legal Reasons (explicit)")
        return res
    }

    if (httpRes.isStub) {
        res.verdict = Verdict.HTTP_STUB
        res.notes.add("response body matches a known ISP stub-page marker")
        return res
    }

    res.verdict = Verdict.OK
    return res
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            RknCheckerTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = Color(0xFF0C0C0C)
                ) {
                    ConsoleCheckerScreen()
                }
            }
        }
    }
}

@Composable
fun RknCheckerTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            background = Color(0xFF0C0C0C),
            surface = Color(0xFF1E1E1E),
            primary = Color(0xFF00FF66),
            onPrimary = Color.Black
        ),
        content = content
    )
}

@Composable
fun ConsoleCheckerScreen() {
    val whitelistTargets = remember {
        listOf(
            TargetItem("gosuslugi", "https://www.gosuslugi.ru/", true),
            TargetItem("gov.ru", "https://www.gov.ru/", true),
            TargetItem("mos.ru", "https://www.mos.ru/", true),
            TargetItem("rkn", "https://rkn.gov.ru/", true),
            TargetItem("nalog", "https://www.nalog.gov.ru/", true),
            TargetItem("yandex", "https://ya.ru/", true),
            TargetItem("yandex-maps", "https://yandex.ru/maps/", true),
            TargetItem("kinopoisk", "https://www.kinopoisk.ru/", true),
            TargetItem("sberbank", "https://www.sberbank.ru/", true),
            TargetItem("vtb", "https://www.vtb.ru/", true),
            TargetItem("alfabank", "https://alfabank.ru/", true),
            TargetItem("vk", "https://vk.com/", true),
            TargetItem("ok", "https://ok.ru/", true),
            TargetItem("ozon", "https://www.ozon.ru/", true),
            TargetItem("wildberries", "https://www.wildberries.ru/", true),
            TargetItem("avito", "https://www.avito.ru/", true),
            TargetItem("lenta", "https://lenta.ru/", true),
            TargetItem("rbc", "https://www.rbc.ru/", true),
            TargetItem("tass", "https://tass.ru/", true),
            TargetItem("rutube", "https://rutube.ru/", true),
            TargetItem("dzen", "https://dzen.ru/", true)
        )
    }

    val blacklistTargets = remember {
        listOf(
            TargetItem("instagram", "https://www.instagram.com/", false),
            TargetItem("facebook", "https://www.facebook.com/", false),
            TargetItem("twitter/x", "https://x.com/", false),
            TargetItem("linkedin", "https://www.linkedin.com/", false),
            TargetItem("discord", "https://discord.com/", false),
            TargetItem("dailymotion", "https://www.dailymotion.com/", false),
            TargetItem("soap2day", "https://soap2day.day/", false),
            TargetItem("rutracker", "https://rutracker.org/", false),
            TargetItem("tor-project", "https://www.torproject.org/", false),
            TargetItem("protonvpn", "https://protonvpn.com/", false),
            TargetItem("deepl", "https://www.deepl.com/", false),
            TargetItem("patreon", "https://www.patreon.com/", false),
            TargetItem("bbc-russian", "https://www.bbc.com/russian", false),
            TargetItem("meduza", "https://meduza.io/", false),
            TargetItem("dw-russian", "https://www.dw.com/ru/", false)
        )
    }

    val logLines = remember { mutableStateListOf<LogLine>() }
    var isRunning by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()

    fun runTests() {
        if (isRunning) return
        isRunning = true
        logLines.clear()

        coroutineScope.launch {
            logLines.add(LogLine("======================================================================", LogType.HEADER))
            logLines.add(LogLine("  RKN Block Checker", LogType.HEADER))
            logLines.add(LogLine("======================================================================", LogType.HEADER))
            logLines.add(LogLine("Detecting connection info...", LogType.INFO))

            val ipInfoResult = fetchIpAndProvider()
            val ipInfo = ipInfoResult.getOrNull()
            if (ipInfo != null) {
                logLines.add(LogLine("  IP:       ${ipInfo.ip}", LogType.NORMAL))
                logLines.add(LogLine("  ISP:      ${ipInfo.isp}", LogType.NORMAL))
                logLines.add(LogLine("  Location: ${ipInfo.location}", LogType.NORMAL))
            } else {
                val errorMsg = ipInfoResult.exceptionOrNull()?.message ?: "Unknown error"
                logLines.add(LogLine("  IP / ISP: Detection failed ($errorMsg)", LogType.ERROR))
            }
            logLines.add(LogLine("----------------------------------------------------------------------", LogType.HEADER))
            logLines.add(LogLine("", LogType.NORMAL))

            // Whitelist Section
            logLines.add(LogLine("Whitelist (should always work)", LogType.HEADER))
            logLines.add(LogLine("  name          verdict                    TCP     TLS     PLT  status", LogType.INFO))
            logLines.add(LogLine("  --------------------------------------------------------------------", LogType.INFO))

            val whiteResults = mutableListOf<CheckResult>()
            for (target in whitelistTargets) {
                val res = checkTarget(target)
                whiteResults.add(res)

                val nameStr = res.target.name.padEnd(13)
                val verdictStr = res.verdict.label.padEnd(15)
                val tcpStr = res.tcpTimeMs?.let { "${it}ms" } ?: "-"
                val tlsStr = res.tlsTimeMs?.let { "${it}ms" } ?: "-"
                val pltStr = res.pltMs?.let { "${it}ms" } ?: "-"
                val statusStr = res.statusCode?.toString() ?: "-"

                val lineText = String.format("  %-13s %-15s %7s %7s %7s  %-5s", nameStr.trim(), verdictStr.trim(), tcpStr, tlsStr, pltStr, statusStr)
                logLines.add(LogLine(lineText, res.verdict.logType))

                res.notes.forEach { note ->
                    logLines.add(LogLine("    └ $note", LogType.INFO))
                }
                delay(40)
            }

            logLines.add(LogLine("", LogType.NORMAL))

            // Blacklist Section
            logLines.add(LogLine("Blacklist (RKN-restricted)", LogType.HEADER))
            logLines.add(LogLine("  name          verdict                    TCP     TLS     PLT  status", LogType.INFO))
            logLines.add(LogLine("  --------------------------------------------------------------------", LogType.INFO))

            val blackResults = mutableListOf<CheckResult>()
            for (target in blacklistTargets) {
                val res = checkTarget(target)
                blackResults.add(res)

                val nameStr = res.target.name.padEnd(13)
                val verdictStr = res.verdict.label.padEnd(15)
                val tcpStr = res.tcpTimeMs?.let { "${it}ms" } ?: "-"
                val tlsStr = res.tlsTimeMs?.let { "${it}ms" } ?: "-"
                val pltStr = res.pltMs?.let { "${it}ms" } ?: "-"
                val statusStr = res.statusCode?.toString() ?: "-"

                val lineText = String.format("  %-13s %-15s %7s %7s %7s  %-5s", nameStr.trim(), verdictStr.trim(), tcpStr, tlsStr, pltStr, statusStr)
                logLines.add(LogLine(lineText, res.verdict.logType))

                res.notes.forEach { note ->
                    logLines.add(LogLine("    └ $note", LogType.INFO))
                }
                delay(40)
            }

            logLines.add(LogLine("", LogType.NORMAL))
            logLines.add(LogLine("======================================================================", LogType.HEADER))
            logLines.add(LogLine("  Summary", LogType.HEADER))
            logLines.add(LogLine("----------------------------------------------------------------------", LogType.HEADER))

            val whiteOk = whiteResults.count { it.verdict == Verdict.OK }
            logLines.add(LogLine("  Whitelist: $whiteOk/${whitelistTargets.size} working", if (whiteOk == whitelistTargets.size) LogType.SUCCESS else LogType.WARNING))

            val blackOpen = blackResults.count { it.verdict == Verdict.OK }
            val blackBlocked = blackResults.count { it.verdict != Verdict.OK && it.verdict != Verdict.DOWN }
            logLines.add(LogLine("  Blacklist: $blackOpen/${blacklistTargets.size} open, $blackBlocked/${blacklistTargets.size} blocked", LogType.NORMAL))

            logLines.add(LogLine("", LogType.NORMAL))
            if (blackBlocked == 0) {
                logLines.add(LogLine("  → No blocks detected on blacklisted sites.", LogType.SUCCESS))
            } else if (blackBlocked == blacklistTargets.size) {
                logLines.add(LogLine("  → Full blocking active — all tested blacklisted sites are blocked.", LogType.ERROR))
            } else {
                logLines.add(LogLine("  → Partial blocks - some blacklisted sites still load.", LogType.WARNING))
                logLines.add(LogLine("    Mixed signals. May indicate selective filtering, a mix of real blocks and unrelated server issues, or a CDN flake.", LogType.INFO))
            }

            val tlsDpiCount = blackResults.count { it.verdict == Verdict.TLS_BLOCK || it.verdict == Verdict.TCP_RESET }
            val stubCount = blackResults.count { it.verdict == Verdict.HTTP_STUB }
            val dnsBlockCount = blackResults.count { it.verdict == Verdict.DNS_BLOCK }
            val timeoutCount = blackResults.count { it.verdict == Verdict.TIMEOUT }

            if (blackBlocked > 0) {
                logLines.add(LogLine("", LogType.NORMAL))
                logLines.add(LogLine("  Block types in the blacklist:", LogType.INFO))
                if (tlsDpiCount > 0) logLines.add(LogLine("    ✗ TLS DPI: $tlsDpiCount", LogType.WARNING))
                if (stubCount > 0) logLines.add(LogLine("    ✗ HTTP Stub: $stubCount", LogType.ERROR))
                if (dnsBlockCount > 0) logLines.add(LogLine("    ⛔ DNS Block: $dnsBlockCount", LogType.ERROR))
                if (timeoutCount > 0) logLines.add(LogLine("    ? TCP Timeout: $timeoutCount", LogType.ERROR))
            }

            logLines.add(LogLine("======================================================================", LogType.HEADER))

            isRunning = false
        }
    }

    // Auto scroll to bottom
    LaunchedEffect(logLines.size) {
        if (logLines.isNotEmpty()) {
            listState.animateScrollToItem(logLines.size - 1)
        }
    }

    // Run tests automatically on launch
    LaunchedEffect(Unit) {
        runTests()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .systemBarsPadding()
            .padding(16.dp)
    ) {
        // Console Screen Output
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .background(Color(0xFF0F0F0F), shape = RoundedCornerShape(8.dp))
                .padding(12.dp)
        ) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize()
            ) {
                items(logLines) { line ->
                    val color = when (line.type) {
                        LogType.HEADER -> Color(0xFF00E5FF) // Cyan
                        LogType.INFO -> Color(0xFF8E8E93) // Gray
                        LogType.SUCCESS -> Color(0xFF00FF66) // Green
                        LogType.WARNING -> Color(0xFFFFCC00) // Yellow/Orange
                        LogType.ERROR -> Color(0xFFFF3366) // Red/Pink
                        LogType.NORMAL -> Color(0xFFE5E5EA) // White
                    }
                    val weight = if (line.type == LogType.HEADER) FontWeight.Bold else FontWeight.Normal

                    Text(
                        text = line.text,
                        color = color,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        fontWeight = weight,
                        modifier = Modifier.padding(vertical = 1.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Restart Test Button
        Button(
            onClick = { runTests() },
            enabled = !isRunning,
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF00E5FF),
                disabledContainerColor = Color(0xFF2C2C2C),
                contentColor = Color.Black,
                disabledContentColor = Color.Gray
            ),
            shape = RoundedCornerShape(6.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Restart Icon",
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = if (isRunning) "TESTING..." else "RESTART TEST",
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp
                )
            }
        }
    }
}
