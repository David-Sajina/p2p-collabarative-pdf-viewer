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
  String? _filePath;
  int _currentPage = 0;

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
    if (info == null) {
      connectToSocket();
    }
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


  Future<void> _openFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _filePath = result.files.single.path!;
        startSocket();
      });
    }
  }

  // For Host to start file transfer of selected PDF
  Future startSocket() async {
    WifiP2PGroupInfo? wifiP2PInfo = await _flutterP2pConnectionPlugin.groupInfo();
    if (wifiP2PInfo != null && wifiP2PInfo.isGroupOwner && _filePath != null) {
      List<TransferUpdate>? updates = await _flutterP2pConnectionPlugin.sendFiletoSocket([_filePath!]);
      if (updates == null) {
        print('FAILLLLLL');
      } else {
        print('SUCCESSSSSS');
      }
    }
  }
 // For Client to connect
  Future connectToSocket() async {
    WifiP2PGroupInfo? wifiP2PInfo = await _flutterP2pConnectionPlugin.groupInfo();
    // wifiP2PInfo je stalno null sa klijentske strane????????????????
    if (true) {
      print("AAAAAAAAAAAAAAAAAAAAAAAa");
      await _flutterP2pConnectionPlugin.connectToSocket(
        groupOwnerAddress: "/192.167.49.1", // TRYING TO HARDCODE
        // groupOwnerAddress: wifiP2PInfo!.groupOwnerAddress!,

        // downloadPath is the directory where received file will be stored
        downloadPath: "/storage/emulated/0/Download/",
        // the max number of downloads at a time. Default is 2.
        maxConcurrentDownloads: 2,
        // delete incomplete transfered file
        deleteOnError: true,
        // on connected to socket
        onConnect: (address) {
          print("connected to socket: $address");
        },
        // receive transfer updates for both sending and receiving.
        transferUpdate: (transfer) {
          // transfer.count is the amount of bytes transfered
          // transfer.total is the file size in bytes
          // if transfer.receiving is true, you are receiving the file, else you're sending the file.
          // call `transfer.cancelToken?.cancel()` to cancel transfer. This method is only applicable to receiving transfers.
          print(
              "ID: ${transfer.id}, FILENAME: ${transfer.filename}, PATH: ${transfer.path}, COUNT: ${transfer.count}, TOTAL: ${transfer.total}, COMPLETED: ${transfer.completed}, FAILED: ${transfer.failed}, RECEIVING: ${transfer.receiving}");
        },
        // handle string transfer from server
        receiveString: (req) async {
          print(req);
        },
      );
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


