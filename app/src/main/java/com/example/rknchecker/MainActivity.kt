package com.example.rknchecker

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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

enum class Verdict(val label: String, val badgeBg: Color, val badgeFg: Color) {
    OK("✓ OK", Color(0xFF133827), Color(0xFF00FF66)),
    HTTP_STUB("✗ HTTP STUB", Color(0xFF38131A), Color(0xFFFF3366)),
    TLS_BLOCK("~ TLS DPI", Color(0xFF3D3216), Color(0xFFFFCC00)),
    TCP_RESET("~ TCP RESET", Color(0xFF3D3216), Color(0xFFFFCC00)),
    DNS_BLOCK("⛔ DNS BLOCK", Color(0xFF38131A), Color(0xFFFF3366)),
    TIMEOUT("? TIMEOUT", Color(0xFF38131A), Color(0xFFFF3366)),
    DOWN("· DOWN", Color(0xFF2C2C2C), Color(0xFF8E8E93)),
    TESTING("... TESTING", Color(0xFF1A2B3C), Color(0xFF00E5FF)),
    UNKNOWN("? UNKNOWN", Color(0xFF2C2C2C), Color(0xFF8E8E93))
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
                    if (obj.optInt("type") == 1) {
                        return@withContext obj.optString("data")
                    }
                }
            }
        }
        conn.disconnect()
    } catch (e: Exception) {
        // Ignore
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
        res.notes.add("System DNS failed, DoH resolved — DNS poisoning signature")
        return res
    }

    if (res.sysIp == null && res.dohIp == null) {
        res.verdict = Verdict.DOWN
        res.notes.add("Domain does not resolve via System DNS or DoH")
        return res
    }

    if (res.sysIp != null && res.dohIp != null && res.sysIp != res.dohIp) {
        res.dnsMismatch = true
        res.notes.add("DNS Mismatch: System=${res.sysIp} vs DoH=${res.dohIp} (Transparent DNS rewriting)")
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
            res.notes.add("TCP Timeout on port 443 — IP block or route drop")
        } else if ("reset" in errLower || "rst" in errLower) {
            res.verdict = Verdict.TCP_RESET
            res.notes.add("TCP RST received — Middlebox injection signature")
        } else {
            res.verdict = Verdict.DOWN
            res.notes.add("TCP connection failed: ${res.tcpError}")
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
            res.notes.add("TLS reset right after ClientHello — SNI-based DPI filtering signature")
        } else if ("timeout" in errLower) {
            res.verdict = Verdict.TLS_BLOCK
            res.notes.add("TLS handshake silently dropped — DPI ClientHello filtering signature")
        } else {
            res.verdict = Verdict.TLS_BLOCK
            res.notes.add("TLS Handshake error: ${res.tlsError}")
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
        res.notes.add("HTTP 451 — Unavailable For Legal Reasons (Explicit RKN notice)")
        return res
    }

    if (httpRes.isStub) {
        res.verdict = Verdict.HTTP_STUB
        res.notes.add("Response body matches ISP block stub-page marker")
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
                    MainAppScreen()
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
            surface = Color(0xFF181818),
            primary = Color(0xFF00E5FF),
            onPrimary = Color.Black
        ),
        content = content
    )
}

@Composable
fun MainAppScreen() {
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

    val resultsMap = remember { mutableStateMapOf<String, CheckResult>() }
    var ipInfo by remember { mutableStateOf<IpInfo?>(null) }
    var isRunning by remember { mutableStateOf(false) }
    var selectedTab by remember { mutableStateOf(0) } // 0: All, 1: Whitelist, 2: Blacklist, 3: Blocked

    val coroutineScope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    fun runTests() {
        if (isRunning) return
        isRunning = true
        resultsMap.clear()

        // Pre-fill placeholder results
        (whitelistTargets + blacklistTargets).forEach { target ->
            resultsMap[target.name] = CheckResult(target = target, verdict = Verdict.TESTING)
        }

        coroutineScope.launch {
            val ipResult = fetchIpAndProvider()
            ipInfo = ipResult.getOrNull()

            val allTargets = whitelistTargets + blacklistTargets
            allTargets.forEach { target ->
                val result = checkTarget(target)
                resultsMap[target.name] = result
                delay(30)
            }

            isRunning = false
        }
    }

    LaunchedEffect(Unit) {
        runTests()
    }

    val allResultsList = (whitelistTargets + blacklistTargets).mapNotNull { resultsMap[it.name] }
    val filteredResults = when (selectedTab) {
        1 -> allResultsList.filter { it.target.isWhitelist }
        2 -> allResultsList.filter { !it.target.isWhitelist }
        3 -> allResultsList.filter { it.verdict != Verdict.OK && it.verdict != Verdict.TESTING && it.verdict != Verdict.UNKNOWN && it.verdict != Verdict.DOWN }
        else -> allResultsList
    }

    val whiteOk = whitelistTargets.count { resultsMap[it.name]?.verdict == Verdict.OK }
    val blackOpen = blacklistTargets.count { resultsMap[it.name]?.verdict == Verdict.OK }
    val blackBlocked = blacklistTargets.count {
        val v = resultsMap[it.name]?.verdict
        v != null && v != Verdict.OK && v != Verdict.TESTING && v != Verdict.UNKNOWN && v != Verdict.DOWN
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .systemBarsPadding()
            .background(Color(0xFF0C0C0C))
    ) {
        // App Header Bar
        Surface(
            color = Color(0xFF141414),
            shadowElevation = 4.dp
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = "RKN BLOCK CHECKER",
                        color = Color(0xFF00E5FF),
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        letterSpacing = 1.sp,
                        fontFamily = FontFamily.Monospace
                    )
                    Text(
                        text = if (isRunning) "Scanning connection..." else "Diagnostics Ready",
                        color = Color(0xFF8E8E93),
                        fontSize = 12.sp
                    )
                }

                IconButton(
                    onClick = { runTests() },
                    enabled = !isRunning
                ) {
                    if (isRunning) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(22.dp),
                            color = Color(0xFF00E5FF),
                            strokeWidth = 2.dp
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Restart",
                            tint = Color(0xFF00E5FF)
                        )
                    }
                }
            }
        }

        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 14.dp),
            contentPadding = PaddingValues(top = 12.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // 1. Connection Header Card
            item {
                NetworkHeaderCard(ipInfo = ipInfo)
            }

            // 2. Summary Overview Card
            item {
                SummaryOverviewCard(
                    whiteOk = whiteOk,
                    whiteTotal = whitelistTargets.size,
                    blackOpen = blackOpen,
                    blackBlocked = blackBlocked,
                    blackTotal = blacklistTargets.size,
                    results = allResultsList
                )
            }

            // 3. Filter Chips Row
            item {
                ScrollableTabRow(
                    selectedTabIndex = selectedTab,
                    edgePadding = 0.dp,
                    containerColor = Color.Transparent,
                    contentColor = Color(0xFF00E5FF),
                    divider = {}
                ) {
                    val tabs = listOf(
                        "All (${allResultsList.size})",
                        "Whitelist (${whitelistTargets.size})",
                        "Blacklist (${blacklistTargets.size})",
                        "Blocked ($blackBlocked)"
                    )
                    tabs.forEachIndexed { index, title ->
                        Tab(
                            selected = selectedTab == index,
                            onClick = { selectedTab = index },
                            text = {
                                Text(
                                    text = title,
                                    fontSize = 13.sp,
                                    fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Normal,
                                    color = if (selectedTab == index) Color(0xFF00E5FF) else Color(0xFF8E8E93)
                                )
                            }
                        )
                    }
                }
            }

            // 4. Target Result Cards
            items(filteredResults, key = { it.target.name }) { result ->
                SiteResultCard(res = result)
            }
        }
    }
}

@Composable
fun NetworkHeaderCard(ipInfo: IpInfo?) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF161618)),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color(0xFF26262A), RoundedCornerShape(12.dp))
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = "CONNECTION INFO",
                color = Color(0xFF8E8E93),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(text = "IP Address", color = Color(0xFF6E6E73), fontSize = 11.sp)
                    Text(
                        text = ipInfo?.ip ?: "Detecting...",
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
                Column(modifier = Modifier.weight(1.2f)) {
                    Text(text = "ISP / Provider", color = Color(0xFF6E6E73), fontSize = 11.sp)
                    Text(
                        text = ipInfo?.isp ?: "Detecting...",
                        color = Color.White,
                        fontWeight = FontWeight.Medium,
                        fontSize = 13.sp,
                        maxLines = 1
                    )
                }
            }
            if (ipInfo?.location != null) {
                Spacer(modifier = Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(text = "Location: ", color = Color(0xFF6E6E73), fontSize = 11.sp)
                    Text(text = ipInfo.location, color = Color(0xFFD1D1D6), fontSize = 12.sp)
                }
            }
        }
    }
}

@Composable
fun SummaryOverviewCard(
    whiteOk: Int,
    whiteTotal: Int,
    blackOpen: Int,
    blackBlocked: Int,
    blackTotal: Int,
    results: List<CheckResult>
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF161618)),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color(0xFF26262A), RoundedCornerShape(12.dp))
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = "DIAGNOSTIC SUMMARY",
                color = Color(0xFF8E8E93),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Whitelist Pill
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color(0xFF1A2620))
                        .padding(10.dp)
                ) {
                    Column {
                        Text(text = "Whitelist", color = Color(0xFF8E8E93), fontSize = 11.sp)
                        Text(
                            text = "$whiteOk / $whiteTotal OK",
                            color = Color(0xFF00FF66),
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }
                }

                // Blacklist Pill
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (blackBlocked > 0) Color(0xFF331E22) else Color(0xFF1A2620))
                        .padding(10.dp)
                ) {
                    Column {
                        Text(text = "Blacklist", color = Color(0xFF8E8E93), fontSize = 11.sp)
                        Text(
                            text = "$blackOpen Open · $blackBlocked Blocked",
                            color = if (blackBlocked > 0) Color(0xFFFF3366) else Color(0xFF00FF66),
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            val bannerText = when {
                blackBlocked == 0 -> "→ No blocks detected on blacklisted sites."
                blackBlocked == blackTotal -> "→ Full DPI blocking active — all blacklisted sites blocked."
                else -> "→ Selective DPI filtering active (partial blocks detected)."
            }
            val bannerColor = when {
                blackBlocked == 0 -> Color(0xFF00FF66)
                blackBlocked == blackTotal -> Color(0xFFFF3366)
                else -> Color(0xFFFFCC00)
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = if (blackBlocked == 0) Icons.Default.CheckCircle else Icons.Default.Warning,
                    contentDescription = null,
                    tint = bannerColor,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = bannerText,
                    color = bannerColor,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            val tlsDpi = results.count { !it.target.isWhitelist && (it.verdict == Verdict.TLS_BLOCK || it.verdict == Verdict.TCP_RESET) }
            val stubCount = results.count { !it.target.isWhitelist && it.verdict == Verdict.HTTP_STUB }
            val dnsCount = results.count { !it.target.isWhitelist && it.verdict == Verdict.DNS_BLOCK }
            val timeoutCount = results.count { !it.target.isWhitelist && it.verdict == Verdict.TIMEOUT }

            if (blackBlocked > 0) {
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    if (tlsDpi > 0) BlockChip(label = "TLS DPI: $tlsDpi", color = Color(0xFFFFCC00))
                    if (stubCount > 0) BlockChip(label = "HTTP Stub: $stubCount", color = Color(0xFFFF3366))
                    if (dnsCount > 0) BlockChip(label = "DNS Block: $dnsCount", color = Color(0xFFFF3366))
                    if (timeoutCount > 0) BlockChip(label = "Timeout: $timeoutCount", color = Color(0xFFFF3366))
                }
            }
        }
    }
}

@Composable
fun BlockChip(label: String, color: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.15f))
            .border(1.dp, color.copy(alpha = 0.3f), RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            text = label,
            color = color,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
fun SiteResultCard(res: CheckResult) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF161618)),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color(0xFF26262A), RoundedCornerShape(10.dp))
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            // Header Row: Name + Whitelist/Blacklist Tag + Verdict Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = res.target.name,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    TagChip(
                        label = if (res.target.isWhitelist) "WHITELIST" else "BLACKLIST",
                        color = if (res.target.isWhitelist) Color(0xFF00E5FF) else Color(0xFFBF5AF2)
                    )
                }

                // Verdict Badge
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(res.verdict.badgeBg)
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = res.verdict.label,
                        color = res.verdict.badgeFg,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Metrics Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                MetricItem(label = "TCP", value = res.tcpTimeMs?.let { "${it}ms" } ?: "-")
                MetricItem(label = "TLS", value = res.tlsTimeMs?.let { "${it}ms" } ?: "-")
                MetricItem(label = "PLT", value = res.pltMs?.let { "${it}ms" } ?: "-")
                MetricItem(label = "Status", value = res.statusCode?.toString() ?: "-")
            }

            // Notes Section
            if (res.notes.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color(0xFF202024))
                        .padding(8.dp)
                ) {
                    res.notes.forEach { note ->
                        Row(modifier = Modifier.padding(vertical = 2.dp)) {
                            Text(
                                text = "• ",
                                color = Color(0xFFFFCC00),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = note,
                                color = Color(0xFFD1D1D6),
                                fontSize = 11.sp,
                                lineHeight = 14.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TagChip(label: String, color: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(color.copy(alpha = 0.12f))
            .border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(4.dp))
            .padding(horizontal = 5.dp, vertical = 2.dp)
    ) {
        Text(
            text = label,
            color = color,
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
fun MetricItem(label: String, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF222226))
            .padding(horizontal = 6.dp, vertical = 3.dp)
    ) {
        Text(text = "$label: ", color = Color(0xFF8E8E93), fontSize = 11.sp)
        Text(
            text = value,
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            fontSize = 11.sp,
            fontFamily = FontFamily.Monospace
        )
    }
}
