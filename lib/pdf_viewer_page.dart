import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerPage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
//_PdfViewerPageState createState() => _PdfViewerPageState();
}

class _MyHomePageState extends State<PdfViewerPage>
    with WidgetsBindingObserver {
  final _flutterP2pConnectionPlugin = FlutterP2pConnection();

  StreamSubscription<WifiP2PInfo>? _streamWifiInfo;
  StreamSubscription<List<DiscoveredPeers>>? _streamPeers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkPremissions();
  }
  void checkPremissions() async {
    bool storagePermission = await FlutterP2pConnection().checkStoragePermission();
    if (!storagePermission) {
      await FlutterP2pConnection().askStoragePermission();
    }

    bool locationPermission = await FlutterP2pConnection().checkLocationPermission();
    if (!locationPermission) {
      bool askLocationPerm = await FlutterP2pConnection().askLocationPermission();
      if (!askLocationPerm) {
      }
    }

    bool wifiEnabled = await FlutterP2pConnection().checkWifiEnabled();
    if (!wifiEnabled) {
      await FlutterP2pConnection().enableWifiServices();
    }
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flutterP2pConnectionPlugin.unregister();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flutterP2pConnectionPlugin.unregister();
    } else if (state == AppLifecycleState.resumed) {
      _flutterP2pConnectionPlugin.register();
    }
  }

  void _init() async {
    List<DiscoveredPeers> peers = [];

    await _flutterP2pConnectionPlugin
        .initialize()
        .then((value) => {print(value)});
    await _flutterP2pConnectionPlugin
        .register()
        .then((value) => {print(value)});
    _streamWifiInfo =
        _flutterP2pConnectionPlugin.streamWifiP2PInfo().listen((event) {
      print("kurac $event");
    });

    WifiP2PGroupInfo? info = await _flutterP2pConnectionPlugin.groupInfo();
    _streamPeers = _flutterP2pConnectionPlugin.streamPeers().listen((event) {
      print("kurac1 $event");

      setState(() {

        peers = event;
        print("peers $peers");
        String? netName = info?.groupNetworkName;
        List<Client>? clients = info?.clients;
        bool? groupOwner = info?.isGroupOwner;
        String? pass = info?.passPhrase;
        clients?.forEach((element) { print(element.deviceAddress); });

        print("info $info");
        print("netName $netName");
        print("clients $clients");
        print("grown $groupOwner");
        print("pas $pass");

        _flutterP2pConnectionPlugin.discover().then((value) =>
            {
              //_flutterP2pConnectionPlugin.createGroup().then(print),
              print("kita $value")});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return const Text("test");
  }
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  String? _filePath;
  int _currentPage = 0;

  Future<void> _openFilePicker() async {


    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _filePath = result.files.single.path!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_filePath == null)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _openFilePicker,
                    child: Text('Select PDF'),
                  ),
                ],
              ),
            ),
          if (_filePath != null)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SfPdfViewer.file(
                      File(_filePath!),
                      onPageChanged: (PdfPageChangedDetails details) {
                        setState(() {
                          _currentPage = details.newPageNumber;
                        });
                        print('Page changed to: $_currentPage');
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      'Page: $_currentPage',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
