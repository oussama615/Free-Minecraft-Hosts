package com.strawio.voicechat

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.strawio.voicechat.ui.home.HomeRoute
import com.strawio.voicechat.ui.theme.StrawIoTheme
import dagger.hilt.android.AndroidEntryPoint
import androidx.hilt.navigation.compose.hiltViewModel

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { StrawIoApp() }
    }
}

@Composable
fun StrawIoApp(viewModel: com.strawio.voicechat.ui.home.HomeViewModel = hiltViewModel()) {
    val uiState = viewModel.uiState.collectAsStateWithLifecycle().value
    StrawIoTheme {
        Surface(modifier = Modifier.fillMaxSize(), color = Color(0xFF050607)) {
            HomeRoute(
                uiState = uiState,
                onInfoClick = viewModel::showPrivacy,
                onDismissAbout = viewModel::hidePrivacy,
                onDebugState = viewModel::simulateDebugState
            )
        }
    }
}
