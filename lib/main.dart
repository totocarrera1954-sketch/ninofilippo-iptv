import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

// ⚙️ PARAMETRI REALI ESTRATTI DAL TUO DECODER SAMSUNG
class AppConfig {
  static const String serverBaseUrl = "http://taigra.xn--6frz82g";
  static const String vpnAddress = "10.2.0.2/32, 2a07:b944::2:2/128";
  static const String vpnPeerPublicKey = "g6DkXWKI/68RsLjROIwCEcyB/ZhyK5Q7OWcz1TtqER0=";
  static const String vpnEndpoint = "109.236.81.166:51820";
  static const String dnsGoogle = "8.8.8.8";
  static const String dnsCloudflare = "1.1.1.1, 1.0.0.1";
}

void main() => runApp(const NinoFilippoApp());

class NinoFilippoApp extends StatelessWidget {
  const NinoFilippoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nino#filippo IPTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primaryColor: Colors.redAccent),
      home: const Splash3DPage(),
    );
  }
}

// 🎬 1. PAGINA SPLASH SCREEN 3D CON AUDIO (DURATA 20 SECONDI)
class Splash3DPage extends StatefulWidget {
  const Splash3DPage({super.key});
  @override
  State<Splash3DPage> createState() => _Splash3DPageState();
}

class _Splash3DPageState extends State<Splash3DPage> {
  late final WebViewController _webController;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadFlutterAsset('assets/scene3d/index.html');

    Timer(const Duration(seconds: 18), () {
      if (mounted) setState(() { _opacity = 0.0; });
    });

    Timer(const Duration(seconds: 20), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeLoginPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(seconds: 2),
        child: WebViewWidget(controller: _webController),
      ),
    );
  }
}

// 📺 2. SCHERMATA DI LOGIN CON DISPOSITIVI DI RETE (VPN / DNS) E SFONDO IMMAGINE
class HomeLoginPage extends StatefulWidget {
  const HomeLoginPage({super.key});
  @override
  State<HomeLoginPage> createState() => _HomeLoginPageState();
}

class _HomeLoginPageState extends State<HomeLoginPage> {
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _obscure = true; 
  bool _vpnConnesso = false;
  bool _dnsAttivo = false;
  bool _isSaved = false;

  void _eseguiLogin() async {
    if (_user.text.isEmpty || _pass.text.isEmpty) return;
    final url = "${AppConfig.serverBaseUrl}?username=${_user.text}&password=${_pass.text}&type=m3u_plus&output=mpegts";
    setState(() { _isSaved = true; }); 
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => DecoderIptvPage(apiUrl: url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/foto_home.png', fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: const Color(0xFF1A1A1A)))),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.55))),
          Positioned(
            top: 50, right: 16,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() { _dnsAttivo = !_dnsAttivo; }),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: Text(_dnsAttivo ? 'DNS ON' : 'DNS', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: _vpnConnesso ? Colors.green : Colors.red, shape: BoxShape.circle)),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      onPressed: () => setState(() { _vpnConnesso = !_vpnConnesso; }),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: const Text('VPN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0).copyWith(bottom: 50),
              child: Card(
                color: Colors.black.withOpacity(0.8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSaved) const Text('Credenziali Memorizzate nel Server', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      TextField(controller: _user, decoration: const InputDecoration(labelText: 'Username')),
                      TextField(
                        controller: _pass, obscureText: _obscure,
                        decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() { _obscure = !_obscure; }))),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _eseguiLogin, child: const Text('LOGIN')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🎞️ 3. DECODER E DECRITTATORE STREAMING IPTV
class DecoderIptvPage extends StatefulWidget {
  final String apiUrl;
  const DecoderIptvPage({super.key, required this.apiUrl});
  @override
  State<DecoderIptvPage> createState() => _DecoderIptvPageState();
}

class _DecoderIptvPageState extends State<DecoderIptvPage> {
  VideoPlayerController? _videoController;
  List<Map<String, String>> canaliM3u = [];
  List<Map<String, String>> canaliFiltrati = [];
  bool _isLoading = true;
  String canaleCorrente = "Seleziona un canale TV";

  @override
  void initState() {
    super.initState();
    _scaricaListaM3u();
  }

  Future<void> _scaricaListaM3u() async {
    try {
      final response = await http.get(Uri.parse(widget.apiUrl));
      if (response.statusCode == 200) {
        final lines = const LineSplitter().convert(response.body);
        List<Map<String, String>> parsedChannels = [];
        String currentName = "";
        for (var line in lines) {
          if (line.startsWith("#EXTINF:")) {
            final nameIndex = line.lastIndexOf(",");
            currentName = nameIndex != -1 ? line.substring(nameIndex + 1).trim() : "Canale IPTV";
          } else if (line.startsWith("http")) {
            parsedChannels.add({"name": currentName, "url": line.trim()});
          }
        }
        setState(() { canaliM3u = parsedChannels; canaliFiltrati = parsedChannels; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _isLoading = false; canaleCorrente = "Errore caricamento lista"; });
    }
  }

  void _riproduciCanale(String url, String name) async {
    setState(() { canaleCorrente = "Caricamento: $name"; });
    if (_videoController != null) await _videoController!.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) { setState(() {}); _videoController!.play(); });
  }

  @override
  void dispose() { _videoController?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NINO#FILIPPO STREAM PLAYER')),
      body: Column(
        children: [
          Container(
            height: 220, color: Colors.black,
            child: Center(child: (_videoController != null && _videoController!.value.isInitialized) ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!)) : Text(canaleCorrente, style: const TextStyle(fontWeight: FontWeight.bold)))),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(onChanged: (text) => setState(() { canaliFiltrati = canaliM3u.where((c) => c["name"]!.toLowerCase().contains(text.toLowerCase())).toList(); }), decoration: const InputDecoration(labelText: 'Cerca Canale...', prefixIcon: Icon(Icons.search))),
          ),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: canaliFiltrati.length, itemBuilder: (context, index) { final c = canaliFiltrati[index]; return ListTile(leading: const Icon(Icons.tv, color: Colors.yellow), title: Text(c["name"]!, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () => _riproduciCanale(c["url"]!, c["name"]!)); }))
        ],
      ),
    );
  }
}

