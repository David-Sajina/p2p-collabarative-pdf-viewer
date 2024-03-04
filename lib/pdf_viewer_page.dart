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
  WifiP2PInfo? wifiP2PInfo;
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

    final _flutterP2pConnectionPlugin = FlutterP2pConnection();
    WifiP2PInfo? wifiP2PInfo;
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
      wifiP2PInfo = event;
    });

     WifiP2PGroupInfo? info = await _flutterP2pConnectionPlugin.groupInfo();
    // if (info == null) {
    //  connectToSocket();
    //}
    _streamPeers = _flutterP2pConnectionPlugin.streamPeers().listen((event) {
      print("kurac1 $event");

      setState(() {

        peers = event;
        print("peeerrrrrrs $peers");
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


    _streamWifiInfo = _flutterP2pConnectionPlugin.streamWifiP2PInfo().listen((event) {
      // Handle changes in connection
      setState(() {
        wifiP2PInfo = event;
      });
    });
    // void connect() async {
    //   await _flutterP2pConnectionPlugin.connect(peers[0].deviceAddress);
    // }
    // connect();

    _flutterP2pConnectionPlugin.closeSocket();
  }


  Future<void> _openFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null){

      connectToSocket();
    }
    if (result != null) {
        startSocket();
        _filePath = result.files.single.path!;
        String filePath = _filePath ?? "";
        if (_filePath == null) return;
        List<TransferUpdate>? updates =
        await _flutterP2pConnectionPlugin.sendFiletoSocket(

            [
              filePath,
              // "/storage/emulated/0/Download/Likee_7100105253123033459.mp4",
              // "/storage/0E64-4628/Download/Adele-Set-Fire-To-The-Rain-via-Naijafinix.com_.mp3",
              // "/storage/0E64-4628/Flutter SDK/p2p_plugin.apk",
              // "/storage/emulated/0/Download/03 Omah Lay - Godly (NetNaija.com).mp3",
              // "/storage/0E64-4628/Download/Adele-Set-Fire-To-The-Rain-via-Naijafinix.com_.mp3",
            ]);

    }
  }

  // For Host to start file transfer of selected PDF
  Future startSocket() async {
    if (wifiP2PInfo != null) {
      bool started = await _flutterP2pConnectionPlugin.startSocket(
        groupOwnerAddress: wifiP2PInfo!.groupOwnerAddress,
        downloadPath: "/storage/emulated/0/Download/",
        maxConcurrentDownloads: 2,
        deleteOnError: true,
        onConnect: (name, address) {
          print("$name connected to socket with address: $address");
        },
        transferUpdate: (transfer) {
          if (transfer.completed) {
            print(
                "${transfer.failed ? "failed to ${transfer.receiving ? "receive" : "send"}" : transfer.receiving ? "received" : "sent"}: ${transfer.filename}");
          }
          print(
              "ID: ${transfer.id}, FILENAME: ${transfer.filename}, PATH: ${transfer.path}, COUNT: ${transfer.count}, TOTAL: ${transfer.total}, COMPLETED: ${transfer.completed}, FAILED: ${transfer.failed}, RECEIVING: ${transfer.receiving}");
        },
        receiveString: (req) async {
          print(req);
        },
      );
      print("open socket: $started");
      print(wifiP2PInfo!.groupOwnerAddress);
    }
  }
 // For Client to connect
  Future connectToSocket() async {
    print("CONNECT TO SOCKET");
    if (wifiP2PInfo != null) {
      print("wifip2pinfo != null $wifiP2PInfo");
      print("wifiP2PInfo details:");
      print("isConnected: ${wifiP2PInfo?.isConnected}");
      print("isGroupOwner: ${wifiP2PInfo?.isGroupOwner}");
      print("groupFormed: ${wifiP2PInfo?.groupFormed}");
      print("groupOwnerAddress: ${wifiP2PInfo?.groupOwnerAddress}");
      print("clients: ${wifiP2PInfo?.clients}");

      await _flutterP2pConnectionPlugin.connectToSocket(
        groupOwnerAddress: wifiP2PInfo!.groupOwnerAddress,
        downloadPath: "/storage/emulated/0/Download/",
        maxConcurrentDownloads: 3,
        deleteOnError: true,
        onConnect: (address) {
          print("connected to socket: $address");
        },
        transferUpdate: (transfer) {
          // if (transfer.count == 0) transfer.cancelToken?.cancel();
          if (transfer.completed) {
            print(
                "${transfer.failed ? "failed to ${transfer.receiving ? "receive" : "send"}" : transfer.receiving ? "received" : "sent"}: ${transfer.filename}");
          }
          print(
              "ID: ${transfer.id}, FILENAME: ${transfer.filename}, PATH: ${transfer.path}, COUNT: ${transfer.count}, TOTAL: ${transfer.total}, COMPLETED: ${transfer.completed}, FAILED: ${transfer.failed}, RECEIVING: ${transfer.receiving}");
        },
        receiveString: (req) async {
          print(req);
        },
      );
    }
  }

  Future closeSocketConnection() async {
    bool closed = _flutterP2pConnectionPlugin.closeSocket();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "closed: $closed",
        ),
      ),
    );
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


