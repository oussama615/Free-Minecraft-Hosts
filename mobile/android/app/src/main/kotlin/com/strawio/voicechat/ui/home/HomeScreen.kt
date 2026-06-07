package com.strawio.voicechat.ui.home

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.PowerSettingsNew
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.window.layout.DisplayFeature
import com.strawio.voicechat.domain.*
import com.strawio.voicechat.ui.theme.*

@Composable
fun HomeRoute(
    uiState: HomeUiState,
    onInfoClick: () -> Unit,
    onDismissAbout: () -> Unit,
    onDebugState: (DebugSimulation) -> Unit,
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.radialGradient(listOf(Color(0xFF1A1D1F), BlackPearl), radius = 900f))
            .semantics { contentDescription = "StrawIO VoiceChat ${uiState.connection.title}" }
    ) {
        IconButton(
            onClick = onInfoClick,
            modifier = Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(12.dp)
        ) {
            Icon(Icons.Default.Info, contentDescription = "Privacy information", tint = MutedText)
        }
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val landscape = maxWidth > maxHeight
            val maxContentWidth = if (landscape) 840.dp else 460.dp
            val horizontal = when {
                maxWidth < 360.dp -> 16.dp
                maxWidth > 700.dp -> 40.dp
                else -> 24.dp
            }
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .navigationBarsPadding()
                    .statusBarsPadding()
                    .padding(horizontal = horizontal)
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = if (landscape) Arrangement.Top else Arrangement.SpaceBetween,
            ) {
                Column(
                    modifier = Modifier.widthIn(max = maxContentWidth).padding(top = if (landscape) 18.dp else 72.dp, bottom = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    LogoArea(compact = landscape || maxHeight < 650.dp)
                    Spacer(Modifier.height(if (landscape) 18.dp else 38.dp))
                    StatusCard(uiState.connection)
                    Spacer(Modifier.height(if (landscape) 18.dp else 36.dp))
                    StudioCredit()
                    if (uiState.debugToolsEnabled) {
                        DebugControls(onDebugState)
                    }
                }
                Footer(Modifier.widthIn(max = maxContentWidth).padding(bottom = 18.dp, top = 10.dp))
            }
        }
        if (uiState.showPrivacy) PrivacyDialog(onDismissAbout)
    }
}

@Composable
private fun LogoArea(compact: Boolean) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.testTag("logo_area")) {
        MicrophoneLogo(size = if (compact) 112.dp else 142.dp)
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = StrawSilver)) { append("Straw") }
                withStyle(SpanStyle(color = StrawGold)) { append("IO") }
            },
            style = MaterialTheme.typography.displayMedium,
            fontSize = if (compact) 44.sp else 56.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 2.dp)
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            DividerLine()
            Text("VoiceChat", color = StrawGold, letterSpacing = 7.sp, fontSize = if (compact) 17.sp else 21.sp, modifier = Modifier.padding(horizontal = 14.dp))
            DividerLine()
        }
    }
}

@Composable
private fun MicrophoneLogo(size: Dp) {
    Canvas(Modifier.size(size).semantics { contentDescription = "Gold microphone logo with waveform bars" }) {
        val gold = StrawGold
        val center = Offset(size.toPx() / 2f, size.toPx() / 2f)
        drawCircle(Brush.radialGradient(listOf(Color(0x88E3B64F), Color.Transparent), center, size.toPx() * .55f), radius = size.toPx() * .55f, center = center)
        val micW = size.toPx() * .22f
        val micH = size.toPx() * .46f
        drawRoundRect(Brush.linearGradient(listOf(Color(0xFFFFE38C), gold, Color(0xFF8B6423))), topLeft = Offset(center.x - micW / 2, center.y - micH / 2), size = androidx.compose.ui.geometry.Size(micW, micH), cornerRadius = androidx.compose.ui.geometry.CornerRadius(micW / 2, micW / 2))
        drawArc(gold, startAngle = 25f, sweepAngle = 130f, useCenter = false, topLeft = Offset(center.x - size.toPx() * .25f, center.y - size.toPx() * .09f), size = androidx.compose.ui.geometry.Size(size.toPx() * .5f, size.toPx() * .42f), style = Stroke(5.dp.toPx(), cap = StrokeCap.Round))
        drawLine(gold, Offset(center.x, center.y + size.toPx() * .24f), Offset(center.x, center.y + size.toPx() * .38f), strokeWidth = 4.dp.toPx(), cap = StrokeCap.Round)
        drawLine(gold, Offset(center.x - size.toPx() * .13f, center.y + size.toPx() * .38f), Offset(center.x + size.toPx() * .13f, center.y + size.toPx() * .38f), strokeWidth = 4.dp.toPx(), cap = StrokeCap.Round)
        listOf(-.42f, -.34f, -.28f, .28f, .34f, .42f).forEachIndexed { i, x ->
            val h = size.toPx() * (if (i % 3 == 1) .24f else .14f)
            drawLine(Color(0xAAE3B64F), Offset(center.x + size.toPx() * x, center.y - h / 2), Offset(center.x + size.toPx() * x, center.y + h / 2), strokeWidth = 3.dp.toPx(), cap = StrokeCap.Round)
        }
        drawArc(Color(0xCCE3B64F), 132f, 96f, false, Offset(center.x - size.toPx() * .39f, center.y - size.toPx() * .24f), androidx.compose.ui.geometry.Size(size.toPx() * .78f, size.toPx() * .58f), style = Stroke(2.dp.toPx(), cap = StrokeCap.Round))
        drawArc(Color(0xCCE3B64F), -48f, 96f, false, Offset(center.x - size.toPx() * .39f, center.y - size.toPx() * .24f), androidx.compose.ui.geometry.Size(size.toPx() * .78f, size.toPx() * .58f), style = Stroke(2.dp.toPx(), cap = StrokeCap.Round))
    }
}

@Composable
private fun StatusCard(model: ConnectionUiModel) {
    val tone = when (model.tone) { StatusTone.Active -> StrawCyan; StatusTone.Error -> Color(0xFFFF8B87); StatusTone.Warning -> Color(0xFFFFCF72); else -> StrawGold }
    Column(
        Modifier
            .fillMaxWidth()
            .testTag("status_card")
            .drawBehind { drawRoundRect(Brush.radialGradient(listOf(Color(0x449C7530), Color.Transparent), Offset(size.width / 2, size.height), size.width), cornerRadius = androidx.compose.ui.geometry.CornerRadius(18.dp.toPx())) }
            .background(CardFill, RoundedCornerShape(18.dp))
            .border(1.dp, Brush.linearGradient(listOf(Color(0xBCE3B64F), Color(0x449C7530))), RoundedCornerShape(18.dp))
            .padding(22.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ConnectionGlyph(tone)
            Spacer(Modifier.width(18.dp))
            Text(model.title, color = tone, style = MaterialTheme.typography.titleMedium, lineHeight = 25.sp, modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(16.dp))
        StatusRow(Icons.Default.Person, model.playerLine, StrawGold)
        StatusRow(Icons.Default.Storage, model.serverLine, StrawGold)
        StatusRow(if (model.tone == StatusTone.Error) Icons.Outlined.ErrorOutline else Icons.Outlined.CheckCircle, model.statusLine, tone)
    }
}

@Composable
private fun ConnectionGlyph(color: Color) {
    Canvas(Modifier.size(48.dp).semantics { contentDescription = "Connection indicator" }) {
        drawCircle(color.copy(alpha = .14f), radius = size.minDimension / 2)
        drawCircle(color, radius = 4.dp.toPx())
        for (i in 1..3) drawArc(color.copy(alpha = 1f - i * .18f), 130f, 280f, false, Offset(size.width * (.5f - i * .13f), size.height * (.5f - i * .13f)), androidx.compose.ui.geometry.Size(size.width * i * .26f, size.height * i * .26f), style = Stroke(2.4.dp.toPx(), cap = StrokeCap.Round))
    }
}

@Composable
private fun StatusRow(icon: ImageVector, text: String, iconTint: Color) {
    Divider(color = Color.White.copy(alpha = .07f))
    Row(Modifier.fillMaxWidth().padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(23.dp))
        Spacer(Modifier.width(18.dp))
        val parts = text.split(":", limit = 2)
        Text(parts[0] + ":", color = MutedText, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.widthIn(min = 78.dp))
        Text(parts.getOrElse(1) { "" }.trim(), color = if (parts[0] == "Status") iconTint else StrawSilver, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
    }
}

@Composable private fun DividerLine() { Box(Modifier.width(38.dp).height(1.dp).background(Brush.horizontalGradient(listOf(Color.Transparent, StrawGoldDark)))) }

@Composable
private fun StudioCredit() {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.testTag("studio_credit")) {
        WheatIcon(68.dp)
        Spacer(Modifier.height(12.dp))
        Text("This project was developed by", color = MutedText, textAlign = TextAlign.Center, style = MaterialTheme.typography.bodyLarge)
        Text("StrawIO Studio", color = StrawGold, fontSize = 25.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp, bottom = 8.dp)) { DividerLine(); Text("✦", color = StrawGold, modifier = Modifier.padding(horizontal = 9.dp)); DividerLine() }
        Text("Minecraft & Discord Development Studio", color = MutedText, textAlign = TextAlign.Center, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun WheatIcon(size: Dp) {
    Canvas(Modifier.size(size).border(1.5.dp, StrawGold, CircleShape).padding(10.dp).semantics { contentDescription = "Gold wheat icon" }) {
        val canvasWidth = this.size.width
        val canvasHeight = this.size.height
        val c = Offset(canvasWidth / 2, canvasHeight * .16f)
        drawLine(StrawGold, c, Offset(c.x, canvasHeight * .86f), strokeWidth = 3.dp.toPx(), cap = StrokeCap.Round)
        for (i in 0..4) {
            val y = canvasHeight * (.24f + i * .13f)
            val leaf = Path().apply {
                moveTo(c.x, y)
                quadraticBezierTo(c.x - canvasWidth * .25f, y - 9.dp.toPx(), c.x - 5.dp.toPx(), y + 18.dp.toPx())
            }
            drawPath(leaf, StrawGold, style = Stroke(2.2.dp.toPx(), cap = StrokeCap.Round))
            val leaf2 = Path().apply {
                moveTo(c.x, y + 4.dp.toPx())
                quadraticBezierTo(c.x + canvasWidth * .25f, y - 5.dp.toPx(), c.x + 5.dp.toPx(), y + 21.dp.toPx())
            }
            drawPath(leaf2, StrawGold, style = Stroke(2.2.dp.toPx(), cap = StrokeCap.Round))
        }
    }
}

@Composable
private fun Footer(modifier: Modifier) {
    Row(modifier.background(Color.White.copy(alpha = .045f), RoundedCornerShape(28.dp)).border(1.dp, Color.White.copy(alpha = .05f), RoundedCornerShape(28.dp)).padding(horizontal = 20.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
        Text("✦", color = StrawGold, fontSize = 18.sp)
        Spacer(Modifier.width(12.dp))
        Text("The app works automatically while you play.", color = MutedText, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun DebugControls(onDebugState: (DebugSimulation) -> Unit) {
    Row(Modifier.padding(top = 16.dp).testTag("debug_controls"), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(DebugSimulation.Waiting, DebugSimulation.Connected, DebugSimulation.Error).forEach { sim ->
            AssistChip(onClick = { onDebugState(sim) }, label = { Text(sim.name) }, leadingIcon = { Icon(Icons.Outlined.PowerSettingsNew, null) })
        }
    }
}

@Composable
private fun PrivacyDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("Close") } },
        title = { Text("Privacy information") },
        text = { Text("StrawIO VoiceChat is developed by StrawIO Studio. This phase does not record audio, store audio, use analytics, show ads, track users, or upload personal data. Future voice features will require explicit microphone permission. Device identity uses a locally generated cryptographic key; no passwords should be stored in the app.") },
        containerColor = Charcoal,
        titleContentColor = StrawSilver,
        textContentColor = MutedText,
    )
}

@Preview(showBackground = true)
@Composable private fun WaitingPreview() { StrawIoTheme { HomeRoute(HomeUiState.default(), {}, {}, {}) } }

@Preview(widthDp = 393, heightDp = 852)
@Composable private fun ConnectedPreview() { StrawIoTheme { HomeRoute(HomeUiState(StateFormatting.toUiModel(StateFormatting.previewConnectedState()), StateFormatting.previewConnectedState(), false, false), {}, {}, {}) } }
