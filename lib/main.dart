import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:device_info/device_info.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(MyApp());
}

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => Home());
    case 'browser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.browser));
    case 'advertiser':
      return MaterialPageRoute(
          builder: (_) => DevicesListScreen(deviceType: DeviceType.advertiser));
    default:
      return MaterialPageRoute(
          builder: (_) => Scaffold(
                body: Center(
                    child: Text('No route defined for ${settings.name}')),
              ));
  }
}

bool client = false;
bool pdfComing = false;
List<String> deviceIds = [];
String? pdfPath;
String _file = "";

Future<void> _openFilePicker() async {
  Map<Permission, PermissionStatus> statuses = await [
  Permission.storage,
    Permission.videos,
    Permission.photos,
    Permission.accessMediaLocation,
    Permission.location,
    Permission.manageExternalStorage,
    Permission.activityRecognition,
    Permission.audio,
    Permission.bluetoothConnect,
    Permission.sensors,
    Permission.bluetoothScan,
    Permission.mediaLibrary,
    Permission.nearbyWifiDevices
  ].request();
  await Permission.manageExternalStorage.request();
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'txt'],
  );

  if (result != null && result.files.isNotEmpty) {
    String filePath = result.files.single.path!;
    File file = File(filePath);

    // Read the file content as bytes
    List<int> bytes = await file.readAsBytes();

    // Encode the bytes as base64
    String base64String = base64Encode(bytes);
    _file = base64String;
    // Now you have the file content encoded as base64 in base64String
    print("Base64 encoded content: $base64String");
    print("SIZEEE ${_file?.length}");
    int size = result.files.single.size!;
    print("File size: $size bytes");
    print("File path: $filePath");
  } else {
    print("No file selected.");
  }
}

Future<void> selectPDF(bool isDownlaoded) async {
  if (isDownlaoded) {
    pdfPath = _file;
  } else {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    pdfPath = result?.files.single.path!;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: generateRoute,
      initialRoute: '/',
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, 'browser');
                client = true;
              },
              child: Container(
                color: Colors.red,
                child: Center(
                    child: Text(
                  'BROWSER',
                  style: TextStyle(color: Colors.white, fontSize: 40),
                )),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                client = false;
                Navigator.pushNamed(context, 'advertiser');
              },
              child: Container(
                color: Colors.green,
                child: Center(
                    child: Text(
                  'ADVERTISER',
                  style: TextStyle(color: Colors.white, fontSize: 40),
                )),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => {_openFilePicker()},
              child: Container(
                color: Colors.red,
                child: Center(
                    child: Text(
                  'DATA',
                  style: TextStyle(color: Colors.white, fontSize: 40),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum DeviceType { advertiser, browser }

class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({required this.deviceType});

  final DeviceType deviceType;

  @override
  _DevicesListScreenState createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen> {
  List<Device> devices = [];
  List<Device> connectedDevices = [];
  late NearbyService nearbyService;
  late StreamSubscription subscription;
  late StreamSubscription receivedDataSubscription;
  String? resolution;
  double height = 0;
  bool isInit = false;
  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    subscription.cancel();
    receivedDataSubscription.cancel();
    nearbyService.stopBrowsingForPeers();
    nearbyService.stopAdvertisingPeer();
    super.dispose();
  }

  late SfPdfViewer viewer;
  late PdfViewerController pdfController;

  void _openPdfViewer() {
    if (pdfPath != null) {
      pdfComing = false;
      pdfController = PdfViewerController();
      viewer = SfPdfViewer.file(
        File(pdfPath!),
        controller: pdfController,
      );
      startStreaming();
      //height = MediaQuery.of(context).size.height;
      FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
      height = view.devicePixelRatio;
      print("height $height");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: viewer,
          ),
        ),
      );
    }
  }

  void jumpTo(double yOffset) {
    pdfController.jumpTo(yOffset: yOffset);
  }

  double? localyOff;

  void startStreaming() {
    localyOff = pdfController.scrollOffset.dy;

    Timer.periodic(const Duration(milliseconds: 1), (timer) {
      print("Vertical Offset: ${pdfController.scrollOffset.dy}");
      if (pdfController.scrollOffset.dy != localyOff) {
        localyOff = pdfController.scrollOffset.dy;
        for (String i in deviceIds) {
          nearbyService.sendMessage(i, "${pdfController.scrollOffset.dy * height}");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.deviceType.toString().substring(11).toUpperCase()),
        ),
        backgroundColor: Colors.white,
        body: ListView.builder(
            itemCount: getItemCount(),
            itemBuilder: (context, index) {
              final device = widget.deviceType == DeviceType.advertiser
                  ? connectedDevices[index]
                  : devices[index];
              return Container(
                margin: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: GestureDetector(
                          onTap: () => _onTabItemListener(device),
                          child: Column(
                            children: [
                              Text(device.deviceName),
                              Text(
                                getStateName(device.state),
                                style: TextStyle(
                                    color: getStateColor(device.state)),
                              ),
                            ],
                            crossAxisAlignment: CrossAxisAlignment.start,
                          ),
                        )),
                        // Request connect
                        GestureDetector(
                          onTap: () => _onButtonClicked(device),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8.0),
                            padding: EdgeInsets.all(8.0),
                            height: 35,
                            width: 100,
                            color: getButtonColor(device.state),
                            child: Center(
                              child: Text(
                                getButtonStateName(device.state),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                    SizedBox(
                      height: 8.0,
                    ),
                    Divider(
                      height: 1,
                      color: Colors.grey,
                    )
                  ],
                ),
              );
            }));
  }

  String getStateName(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return "disconnected";
      case SessionState.connecting:
        return "waiting";
      default:
        return "connected";
    }
  }

  String getButtonStateName(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
      case SessionState.connecting:
        return "Connect";
      default:
        return "Disconnect";
    }
  }

  Color getStateColor(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return Colors.black;
      case SessionState.connecting:
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  Color getButtonColor(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
      case SessionState.connecting:
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  _onTabItemListener(Device device) {
    if (device.state == SessionState.connected) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            final myController = TextEditingController();
            return AlertDialog(
              title: Text("Send message"),
              content: TextField(controller: myController),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("Send"),
                  onPressed: () {
                    int i = 0;
                    deviceIds.add(device.deviceId);
                    nearbyService.sendMessage(device.deviceId, "%PDF COMING");
                    sleep(const Duration(seconds: 1));
                    Timer.periodic(const Duration(milliseconds: 20), (timer) {
                      if (_file.length - (i + 10000) < 0) {
                        print("sent ${_file.length % 10000}");
                        print("SUBSTRING ${_file.substring(i, _file.length)}");
                        nearbyService.sendMessage(
                            device.deviceId, _file.substring(i, _file.length));
                        timer.cancel();
                        return;
                      }
                      nearbyService.sendMessage(
                          device.deviceId, _file.substring(i, i + 10000));
                      i += 10000;
                    });

                    myController.text = '';
                  },
                ),
                TextButton(
                  child: Text("Open PDF"),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await selectPDF(false);
                    _openPdfViewer();
                  },
                ),
              ],
            );
          });
    }
  }

  int getItemCount() {
    if (widget.deviceType == DeviceType.advertiser) {
      return connectedDevices.length;
    } else {
      return devices.length;
    }
  }

  _onButtonClicked(Device device) {
    switch (device.state) {
      case SessionState.notConnected:
        nearbyService.invitePeer(
          deviceID: device.deviceId,
          deviceName: device.deviceName,
        );
        break;
      case SessionState.connected:
        nearbyService.disconnectPeer(deviceID: device.deviceId);
        break;
      case SessionState.connecting:
        break;
    }
  }

  void init() async {
    nearbyService = NearbyService();
    String devInfo = '';
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print("aaaaaaaaaaaaaaaaaaaaaaa $resolution");
      devInfo = androidInfo.model;
    }
    if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      devInfo = iosInfo.localizedModel;
    }
    await nearbyService.init(
        serviceType: 'mpconn',
        deviceName: devInfo,
        strategy: Strategy.P2P_CLUSTER,
        callback: (isRunning) async {
          if (isRunning) {
            if (widget.deviceType == DeviceType.browser) {
              await nearbyService.stopBrowsingForPeers();
              await Future.delayed(Duration(microseconds: 200));
              await nearbyService.startBrowsingForPeers();
            } else {
              await nearbyService.stopAdvertisingPeer();
              await nearbyService.stopBrowsingForPeers();
              await Future.delayed(Duration(microseconds: 200));
              await nearbyService.startAdvertisingPeer();
              await nearbyService.startBrowsingForPeers();
            }
          }
        });
    subscription =
        nearbyService.stateChangedSubscription(callback: (devicesList) {
      devicesList.forEach((element) {
        print(
            " deviceId: ${element.deviceId} | deviceName: ${element.deviceName} | state: ${element.state}");

        if (Platform.isAndroid) {
          if (element.state == SessionState.connected) {
            nearbyService.stopBrowsingForPeers();
          } else {
            nearbyService.startBrowsingForPeers();
          }
        }
      });

      setState(() {
        devices.clear();
        devices.addAll(devicesList);
        connectedDevices.clear();
        connectedDevices.addAll(devicesList
            .where((d) => d.state == SessionState.connected)
            .toList());
      });
    });
    String base64data = "";
    receivedDataSubscription =
        nearbyService.dataReceivedSubscription(callback: (data) async {
      if (pdfComing) {
        base64data += data['message'];
        print(data['message'].length);
        if (data['message'].length < 10000) {
          print("zadnja ${data['message']}");
          print("ogromno $base64data");
          // Decode base64 data back to binary
          List<int> bytes = base64.decode(base64data);

          // Get the external storage directory
          final directory = await getExternalStorageDirectory();

          // Create the directory if it doesn't exist
          final downloadsDirectory = Directory('${directory?.path}/Download');
          if (!downloadsDirectory.existsSync()) {
            downloadsDirectory.createSync(recursive: true);
          }

          // Save binary data to a PDF file in the downloads directory
          final file = File('${downloadsDirectory.path}/received_file.pdf');
          await file.writeAsBytes(bytes);

          print("PDF saved to: ${file.path}");
          if (base64data.length > 100) {
            _file = "${downloadsDirectory.path}/received_file.pdf";
            await selectPDF(true);
            _openPdfViewer();
            print("pdf coming false $pdfComing");
          }
        }
      }
      if (data['message'] == "%PDF COMING") {
        pdfComing = true;
        showToast(data['message'],
            context: context,
            axis: Axis.horizontal,
            alignment: Alignment.center,
            position: StyledToastPosition.bottom);
      }

      if (!pdfComing) {
        print(data['message']);
        print(data['message'].runtimeType);
        double d = double.parse(data['message']);
        jumpTo(d/height);
      }
    });
  }
}
