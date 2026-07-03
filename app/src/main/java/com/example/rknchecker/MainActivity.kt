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
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import kotlin.system.measureTimeMillis
import org.json.JSONObject

enum class LogType {
    HEADER,
    INFO,
    SUCCESS,
    ERROR,
    NORMAL
}

data class LogLine(val text: String, val type: LogType)

data class IpInfo(val ip: String, val provider: String)

private suspend fun fetchIpAndProvider(): Result<IpInfo> = withContext(Dispatchers.IO) {
    val errors = mutableListOf<String>()

    // Try ipwho.is first
    try {
        val url = URL("https://ipwho.is/")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        if (conn.responseCode == 200) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            if (json.optBoolean("success", false)) {
                val ip = json.optString("ip", "Unknown")
                val connection = json.optJSONObject("connection")
                val provider = connection?.optString("isp") ?: connection?.optString("org") ?: "Unknown"
                return@withContext Result.success(IpInfo(ip, provider))
            } else {
                errors.add("ipwho.is: success=false")
            }
        } else {
            errors.add("ipwho.is: HTTP ${conn.responseCode}")
        }
    } catch (e: Exception) {
        errors.add("ipwho.is: ${e.javaClass.simpleName}${e.message?.let { ": $it" } ?: ""}")
    }

    // Try ipapi.co second
    try {
        val url = URL("https://ipapi.co/json/")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        if (conn.responseCode == 200) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            val ip = json.optString("ip", "Unknown")
            val provider = json.optString("org", "Unknown")
            return@withContext Result.success(IpInfo(ip, provider))
        } else {
            errors.add("ipapi.co: HTTP ${conn.responseCode}")
        }
    } catch (e: Exception) {
        errors.add("ipapi.co: ${e.javaClass.simpleName}${e.message?.let { ": $it" } ?: ""}")
    }

    // Try ipinfo.io third
    try {
        val url = URL("https://ipinfo.io/json")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        if (conn.responseCode == 200) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            val ip = json.optString("ip", "Unknown")
            val provider = json.optString("org", "Unknown")
            return@withContext Result.success(IpInfo(ip, provider))
        } else {
            errors.add("ipinfo.io: HTTP ${conn.responseCode}")
        }
    } catch (e: Exception) {
        errors.add("ipinfo.io: ${e.javaClass.simpleName}${e.message?.let { ": $it" } ?: ""}")
    }

    // Try api.ipify.org fourth (IP only)
    try {
        val url = URL("https://api.ipify.org?format=json")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3000
        conn.readTimeout = 3000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        if (conn.responseCode == 200) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(response)
            val ip = json.optString("ip", "Unknown")
            return@withContext Result.success(IpInfo(ip, "Unknown Provider"))
        } else {
            errors.add("ipify.org: HTTP ${conn.responseCode}")
        }
    } catch (e: Exception) {
        errors.add("ipify.org: ${e.javaClass.simpleName}${e.message?.let { ": $it" } ?: ""}")
    }

    return@withContext Result.failure(Exception(errors.joinToString(" | ")))
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
    val domains = remember {
        listOf(
            "yandex.ru",
            "mail.ru",
            "online.sberbank.ru",
            "web.max.ru",
            "id.tbank.ru",
            "vk.com",
            "ozon.ru",
            "wb.ru",
            "rutube.ru",
            "github.com",
            "google.com",
            "facebook.com",
            "telegram.org",
            "instagram.com",
            "discord.com"
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
            logLines.add(LogLine("=== Starting RKN Availability Checker ===", LogType.HEADER))
            logLines.add(LogLine("Target domains to test: ${domains.size}", LogType.INFO))
            logLines.add(LogLine("Detecting connection info...", LogType.INFO))
            val ipInfoResult = fetchIpAndProvider()
            val ipInfo = ipInfoResult.getOrNull()
            if (ipInfo != null) {
                logLines.add(LogLine("IP:                     ${ipInfo.ip}", LogType.NORMAL))
                logLines.add(LogLine("Provider:               ${ipInfo.provider}", LogType.NORMAL))
            } else {
                val errorMsg = ipInfoResult.exceptionOrNull()?.message ?: "Unknown error"
                logLines.add(LogLine("IP / Provider:          Detection failed ($errorMsg)", LogType.ERROR))
            }
            logLines.add(LogLine("", LogType.NORMAL))
            
            var dnsOk = 0
            var httpsOk = 0
            val total = domains.size

            domains.forEach { domain ->
                logLines.add(LogLine("━━━ $domain ━━━", LogType.HEADER))
                delay(100) // Visual staggered delay

                // 1. DNS RESOLVE
                logLines.add(LogLine("DNS: Resolving $domain...", LogType.INFO))
                var resolvedIps: List<String> = emptyList()
                var dnsSuccess = false
                var dnsErrorMsg = ""
                
                val dnsTime = measureTimeMillis {
                    try {
                        val addresses = withContext(Dispatchers.IO) {
                            InetAddress.getAllByName(domain)
                        }
                        resolvedIps = addresses.map { it.hostAddress ?: "" }.filter { it.isNotEmpty() }
                        dnsSuccess = resolvedIps.isNotEmpty()
                    } catch (e: Exception) {
                        dnsErrorMsg = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: "")
                    }
                }

                if (dnsSuccess) {
                    dnsOk++
                    logLines.add(LogLine("DNS: OK - ${resolvedIps.joinToString(", ")} (${dnsTime}ms)", LogType.SUCCESS))
                } else {
                    logLines.add(LogLine("DNS: FAILED - $dnsErrorMsg (${dnsTime}ms)", LogType.ERROR))
                }
                delay(100)

                // 2. HTTPS CONNECT
                logLines.add(LogLine("HTTPS: Connecting to https://$domain...", LogType.INFO))
                var httpsSuccess = false
                var responseCode = 0
                var httpsErrorMsg = ""

                val httpsTime = measureTimeMillis {
                    try {
                        withContext(Dispatchers.IO) {
                            val url = URL("https://$domain")
                            val conn = url.openConnection() as HttpURLConnection
                            conn.requestMethod = "GET"
                            conn.connectTimeout = 4000
                            conn.readTimeout = 4000
                            conn.instanceFollowRedirects = true
                            conn.setRequestProperty(
                                "User-Agent",
                                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                            )
                            
                            // Initiating connection and fetching response code
                            responseCode = conn.responseCode
                            httpsSuccess = true
                            conn.disconnect()
                        }
                    } catch (e: Exception) {
                        httpsErrorMsg = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: "")
                    }
                }

                if (httpsSuccess) {
                    httpsOk++
                    logLines.add(LogLine("HTTPS: OK - Code $responseCode (${httpsTime}ms)", LogType.SUCCESS))
                } else {
                    logLines.add(LogLine("HTTPS: FAILED - $httpsErrorMsg (${httpsTime}ms)", LogType.ERROR))
                }
                logLines.add(LogLine("", LogType.NORMAL))
                delay(150)
            }

            // Summary
            logLines.add(LogLine("===== SUMMARY =====", LogType.HEADER))
            if (ipInfo != null) {
                logLines.add(LogLine("IP:            ${ipInfo.ip}", LogType.NORMAL))
                logLines.add(LogLine("Provider:      ${ipInfo.provider}", LogType.NORMAL))
            } else {
                val errorMsg = ipInfoResult.exceptionOrNull()?.message ?: "Unknown error"
                logLines.add(LogLine("IP/Provider:   Detection failed ($errorMsg)", LogType.ERROR))
            }
            logLines.add(LogLine("Checked:       $total domains", LogType.NORMAL))
            
            val dnsType = if (dnsOk == total) LogType.SUCCESS else if (dnsOk > 0) LogType.INFO else LogType.ERROR
            logLines.add(LogLine("DNS OK:        $dnsOk / $total", dnsType))
            
            val httpsType = if (httpsOk == total) LogType.SUCCESS else if (httpsOk > 0) LogType.INFO else LogType.ERROR
            logLines.add(LogLine("HTTPS OK:      $httpsOk / $total", httpsType))
            
            val overallSuccess = dnsOk == total && httpsOk == total
            logLines.add(
                LogLine(
                    "STATUS:        ${if (overallSuccess) "ALL PASSED" else "PARTIAL FAILURE"}",
                    if (overallSuccess) LogType.SUCCESS else LogType.ERROR
                )
            )
            logLines.add(LogLine("===================", LogType.HEADER))
            
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
                        LogType.ERROR -> Color(0xFFFF3366) // Red/Pink
                        LogType.NORMAL -> Color(0xFFE5E5EA) // White
                    }
                    val weight = if (line.type == LogType.HEADER) FontWeight.Bold else FontWeight.Normal
                    
                    Text(
                        text = line.text,
                        color = color,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        fontWeight = weight,
                        modifier = Modifier.padding(vertical = 2.dp)
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
