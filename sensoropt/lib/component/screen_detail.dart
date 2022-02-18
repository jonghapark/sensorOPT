import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:sensoropt/models/model_bleDevice.dart';
import 'package:sensoropt/models/model_logdata.dart';
import 'package:sensoropt/utils/util.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'package:geocoder/geocoder.dart';
import 'package:intl/intl.dart';
import 'package:sensoropt/models/model_logdata.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tab_indicator_styler/tab_indicator_styler.dart';

import 'package:downloads_path_provider/downloads_path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:date_time_picker/date_time_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as ex;

class DetailScreen extends StatefulWidget {
  final BleDeviceItem currentDevice;
  final Uint8List startIndex;
  final Uint8List endindex;
  final int duration;

  DetailScreen(
      {this.currentDevice, this.startIndex, this.endindex, this.duration});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  StreamSubscription monitoringStreamSubscription;
  StreamSubscription<loc.LocationData> _locationSubscription;
  ScreenshotController screenshotController = ScreenshotController();
  Uint8List _imageFile;
  pw.Document pdf = pw.Document();

  bool dataFetchEnd = false;
  List<LogData> fetchDatas = [];
  List<LogData> filteredDatas = [];
  int count = 0;
  int unConditionalCount = 0;
  int currentindex = 1;
  double min = 100;
  double max = -100;
  double minTemp = -10;
  double maxTemp = 40;
  int _minTemp = 2;
  int _maxTemp = 8;
  bool isSwitchedHumi = true;
  DateTime startDateTime = DateTime.now().subtract(Duration(hours: 1));
  DateTime endDateTime = DateTime.now();
  // String result = '';

  String log = '데이터 가져오는 중';

  loc.Location location = new loc.Location();
  loc.LocationData currentLocation;
  String geolocation;

  DateTimeIntervalType currentType = DateTimeIntervalType.hours;

  @override
  void initState() {
    super.initState();
    // result = allText();
    // getCurrentLocation();
    fetchLogData();
  }

  @override
  void dispose() {
    super.dispose();
    monitoringStreamSubscription?.cancel();
  }

  void takeScreenshot() async {
    await screenshotController.capture().then((Uint8List image) {
      //Capture Done
      _imageFile = image;
    }).catchError((onError) {
      print(onError);
    });
  }

  refreshFilteredData() {
    List<LogData> temp = [];
    print(filteredDatas.length.toString());
    for (int i = 0; i < fetchDatas.length; i++) {
      if (fetchDatas[i].timestamp.isBefore(endDateTime) &&
          fetchDatas[i].timestamp.isAfter(startDateTime)) {
        temp.add(fetchDatas[i]);
      }
    }
    List<LogData> reversedTemp = List.from(temp.reversed);
    setState(() {
      filteredDatas = reversedTemp;
    });
    // print(filteredDatas[0].timestamp.toString());
    // print(filteredDatas[1].timestamp.toString());
  }

  String innerCondition(int min, int max, double temp) {
    if (temp <= max && temp >= min)
      return 'Good';
    else
      return 'Bad';
  }

  List<List<pw.TableRow>> allRow() {
    List<List<pw.TableRow>> result = [];

    int idx = -1;
    for (int i = 0; i < filteredDatas.length; i++) {
      if (i % 40 == 0) {
        ++idx;
        result.add([]);
        result[idx].add(
          tableRowDatas(["No.  ", "Temperature(°C)", "Time", "Condition  "],
              TextStyle(), filteredDatas[i].temperature),
        );
      }

      result[idx].add(
        tableRowDatas([
          (i + 1).toString(),
          filteredDatas[i].temperature.toString() + '°C',
          DateFormat('yyyy-MM-dd kk:mm')
                  .format(filteredDatas[i].timestamp.toLocal()) +
              '\n',
          //TODO: min , max 변경
          innerCondition(_minTemp, _maxTemp, filteredDatas[i].temperature)
        ], TextStyle(), filteredDatas[i].temperature),
      );
    }

    return result;
  }

  List<List<pw.Text>> allText() {
    List<List<pw.Text>> result = [];
    int listInx = -1;
    for (int i = 0; i < filteredDatas.length; i++) {
      if (i % 50 == 0) {
        result.add([]);
        listInx++;
      }

      if (i > 8) {
        result[listInx].add(pw.Text((i + 1).toString() +
            '. ' +
            filteredDatas[i].temperature.toString() +
            '°C / ' +
            //TODO: 습도 제거
            // filteredDatas[i].humidity.toString() +
            // '% / ' +
            DateFormat('yyyy-MM-dd kk:mm')
                .format(filteredDatas[i].timestamp.toLocal()) +
            '\n'));
      } else {
        result[listInx].add(pw.Text('0' +
            (i + 1).toString() +
            '. ' +
            filteredDatas[i].temperature.toString() +
            '°C / ' +
            //TODO: 습도 제거
            // filteredDatas[i].humidity.toString() +
            // '% /' +
            DateFormat('yyyy-MM-dd kk:mm')
                .format(filteredDatas[i].timestamp.toLocal()) +
            '\n'));
      }
    }

    return result;
  }

  exportCSV() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
    ].request();

    List<List<dynamic>> rows = [];

    List<dynamic> row = [];
    row.add("NO.");
    row.add("Temp");
    row.add("DateTime");
    rows.add(row);
    for (int i = 0; i < filteredDatas.length; i++) {
      List<dynamic> row = [];
      row.add((i + 1).toString());
      row.add(filteredDatas[i].temperature.toString());
      row.add(filteredDatas[i].timestamp.toLocal().toString());
      rows.add(row);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final dir = await getExternalStorageDirectory();

    // print("dir $dir");
    String filepath = dir.path;
    String now = DateTime.now().toString();
    File f = File(filepath + "/result_" + now + ".csv");
    f.writeAsString(csv);

    await Share.file(
            '결과', '/report_' + now + '.csv', await f.readAsBytes(), 'text/csv',
            text: 'SensorOPT 결과 파일입니다.')
        .then((value) => print('csv 공유완료'))
        .onError((error, stackTrace) => print(error));
  }

  void exportxlsx() async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheetObejct = excel['Result'];
    excel.delete('Sheet1');
    sheetObejct.appendRow(['No.', 'Temp', 'DateTime']);
    for (int i = 0; i < filteredDatas.length; i++) {
      sheetObejct.appendRow([
        (i + 1).toString(),
        filteredDatas[i].temperature.toString(),
        filteredDatas[i].timestamp.toLocal().toString()
      ]);
    }
    var fileBytes = excel.save();
    var directory = await getApplicationDocumentsDirectory();

    final dir = await getExternalStorageDirectory();

    // print("dir $dir");
    String filepath = dir.path;
    String now = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    File f = File(filepath + "/result_" + now + ".xlsx");
    f.writeAsBytesSync(fileBytes);

    await Share.file('결과', 'report_' + now + '.xlsx', await f.readAsBytes(),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            text: 'SensorOPT 결과 파일입니다.')
        .then((value) => print('xlsx 공유완료'))
        .onError((error, stackTrace) => print(error));
  }

  void uploadPDF() async {
    // storage permission ask
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    // the downloads folder path
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    var filePath = path;
    pdf = pw.Document();
    await pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
              child: pw.Image(pw.MemoryImage(_imageFile),
                  fit: pw.BoxFit.contain)); //getting error here
        },
      ),
    );

    String now = DateTime.now().toString();
    File pdfFile = File(filePath + '/report_' + now + '.pdf');
    pdfFile.writeAsBytesSync(await pdf.save());

    print('pdf 저장완료');
    await pdfFile.copy(filePath + '/report/' + now + '.pdf');
    await Share.file('결과', '/report_' + now + '.pdf',
            await pdfFile.readAsBytes(), 'application/pdf',
            text: 'SensorOPT 결과 파일입니다.')
        .then((value) => print('pdf 공유완료'))
        .onError((error, stackTrace) => print(error));
  }

  Widget textRow(List<String> titleList, TextStyle textStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: titleList
          .map(
            (e) => Text(
              e,
              style: textStyle,
            ),
          )
          .toList(),
    );
  }

  tableRow(List<String> attributes, TextStyle textStyle) {
    return pw.TableRow(
      children: attributes
          .map(
            (e) => pw.Text(
              "  " + e,
            ),
          )
          .toList(),
    );
  }

  tableRowDatas(List<String> attributes, TextStyle textStyle, double temper) {
    List<pw.Text> temp = [];
    if (attributes[3] == 'Condition  ') {
      return pw.TableRow(
        children: attributes
            .map(
              (e) => pw.Text(
                "  " + e,
              ),
            )
            .toList(),
      );
    } else {
      temp = attributes
          .map(
            (e) => pw.Text(
              "  " + e,
            ),
          )
          .toList();

      if (attributes[3] == 'Good') {
        return pw.TableRow(children: temp);
      } else {
        temp.removeLast();
        temp.add(pw.Text("  " + attributes[3],
            style: pw.TextStyle(color: PdfColors.red)));
        return pw.TableRow(children: temp);
      }
    }
  }

  saveSignature(
      BuildContext context, GlobalKey<SfSignaturePadState> _signaturePadKey) {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
          backgroundColor: Colors.grey[200],
          elevation: 16.0,
          child: Container(
              width: MediaQuery.of(context).size.width / 2,
              height: MediaQuery.of(context).size.height / 3,
              padding: EdgeInsets.all(10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text('서명'),
                        Container(
                          child: SfSignaturePad(
                            minimumStrokeWidth: 2,
                            maximumStrokeWidth: 3,
                            key: _signaturePadKey,
                            backgroundColor: Color.fromRGBO(255, 255, 255, 1),
                          ),
                          height: 200,
                          width: 300,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            RaisedButton(
                                child: Text("저장"),
                                onPressed: () async {
                                  ui.Image image = await _signaturePadKey
                                      .currentState
                                      .toImage(pixelRatio: 3.0);

                                  Navigator.of(context).pop(image);
                                }),
                            RaisedButton(
                                child: Text("다시 그리기"),
                                onPressed: () async {
                                  await _signaturePadKey.currentState.clear();
                                }),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              )),
        );
      },
    );
  }

  void uploadPDF2(ui.Image signatureImage) async {
    // storage permission ask

    var status = await Permission.storage.status;

    if (!status.isGranted) {
      await Permission.storage.request();
    }

    // the downloads folder path
    final directory = await getExternalStorageDirectory();
    final path = directory.path;
    var filePath = path;
    pdf = pw.Document();
    await pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
              child: pw.Image(pw.MemoryImage(_imageFile),
                  fit: pw.BoxFit.contain)); //getting error here
        },
      ),
    );

    ByteData signImage =
        await signatureImage.toByteData(format: ui.ImageByteFormat.png);
    await pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
              child: pw.Image(pw.MemoryImage(signImage.buffer.asUint8List()),
                  fit: pw.BoxFit.contain)); //getting error here
        },
      ),
    );

    String now = DateTime.now().toLocal().toString();
    File pdfFile = File(filePath + '/report_' + now + '.pdf');
    pdfFile.writeAsBytesSync(await pdf.save());
    print('pdf 저장완료');

    await Share.file('의약품 운송 결과', '/report_' + now + '.pdf',
            await pdfFile.readAsBytes(), 'application/pdf',
            text: '결과 보고서 파일입니다.')
        .then((value) => print('pdf 공유완료'))
        .onError((error, stackTrace) => print(error));
  }

  getCurrentLocation() async {
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    loc.LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
    print('lat: ' + _locationData.latitude.toString());
    setState(() {
      currentLocation = _locationData;
    });
  }

  Future<void> _listenLocation() async {
    _locationSubscription =
        location.onLocationChanged.handleError((dynamic err) {
      setState(() {
        // _error = err.code;
      });
      _locationSubscription.cancel();
    }).listen((loc.LocationData currentLocation) async {
      final coordinates =
          new Coordinates(currentLocation.latitude, currentLocation.longitude);
      var addresses =
          await Geocoder.local.findAddressesFromCoordinates(coordinates);
      var first = addresses.first;
      // if (!_isScanning) {
      //   scan();
      // }
      if (this.geolocation != first.addressLine) {
        setState(() {
          // _error = null;
          this.currentLocation = currentLocation;
          this.geolocation = first.addressLine;
        });
      }
    });
  }

  sendFetchData() async {
    for (int i = 0; i < filteredDatas.length; i++) {
      Data sendData = new Data(
        battery: widget.currentDevice.getBattery().toString(),
        deviceName:
            'OP_' + widget.currentDevice.getDeviceId().toString().substring(7),
        humi: filteredDatas[i].humidity.toString(),
        temper: filteredDatas[i].temperature.toString(),
        lat: currentLocation.latitude.toString() ?? '',
        lng: currentLocation.longitude.toString() ?? '',
        time: filteredDatas[i].timestamp.toString(),
        lex: '',
      );
      print(widget.currentDevice.getBattery().toString() +
          'OP_' +
          widget.currentDevice.getDeviceId().toString().substring(7) +
          filteredDatas[i].humidity.toString() +
          filteredDatas[i].temperature.toString() +
          currentLocation.latitude.toString() +
          currentLocation.longitude.toString() +
          filteredDatas[i].timestamp.toString());
      await sendtoServer(sendData);
    }
    print('send Data !!');
  }

  Future<Post> sendtoServer(Data data) async {
    var client = http.Client();
    try {
      var uriResponse =
          await client.post('http://175.126.232.236/_API/saveData.php', body: {
        "isRegularData": "true",
        "tra_datetime": data.time,
        "tra_temp": data.temper,
        "tra_humidity": data.humi,
        "tra_lat": data.lat,
        "tra_lon": data.lng,
        "de_number": data.deviceName,
        "tra_battery": data.battery,
      });

      // print(await client.get(uriResponse.body['uri'].toString()));
    } catch (e) {
      print(e);
      return null;
    } finally {
      print('send !');
      client.close();
    }
  }

  dataFiltering(int index) {
    List<LogData> tmp = [];
    if (index == 0) {
      DateTime oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
      for (int i = fetchDatas.length - 1; i > 0; i--) {
        if (fetchDatas[i].timestamp.isAfter(oneHourAgo))
          tmp.add(fetchDatas[i]);
        else
          break;
      }
      print(tmp.length);
      setState(() {
        filteredDatas = tmp;
      });
    } else if (index == 1) {
      DateTime oneDayAgo = DateTime.now().subtract(Duration(days: 1));
      for (int i = fetchDatas.length - 1; i > 0; i--) {
        if (fetchDatas[i].timestamp.isAfter(oneDayAgo)) {
          if (i % 2 == 0) {
            tmp.add(fetchDatas[i]);
          }
        } else
          break;
      }
      print(tmp.length);
      setState(() {
        filteredDatas = tmp;
      });
    } else if (index == 2) {
      DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 8));
      for (int i = fetchDatas.length - 1; i > 0; i--) {
        if (fetchDatas[i].timestamp.isAfter(oneWeekAgo)) {
          if (i % 15 == 0) {
            tmp.add(fetchDatas[i]);
          }
        } else
          break;
      }
      setState(() {
        filteredDatas = tmp;
      });
    } else if (index == 3) {
      DateTime oneMonthAgo = DateTime.now().subtract(Duration(days: 31));
      for (int i = fetchDatas.length - 1; i > 0; i--) {
        if (fetchDatas[i].timestamp.isAfter(oneMonthAgo)) {
          if (i % 50 == 0) {
            tmp.add(fetchDatas[i]);
          }
        } else
          break;
      }
      setState(() {
        filteredDatas = tmp;
      });
    } else {
      DateTime oneYearAgo = DateTime.now().subtract(Duration(days: 364));
      for (int i = fetchDatas.length - 1; i > 0; i--) {
        if (fetchDatas[i].timestamp.isAfter(oneYearAgo)) {
          if (i % 50 == 0) {
            tmp.add(fetchDatas[i]);
          }
        } else
          break;
      }
      setState(() {
        filteredDatas = tmp;
      });
    }
  }

  DateTimeIntervalType toggleType(int index) {
    dataFiltering(index);
    if (index == 0)
      return DateTimeIntervalType.minutes;
    else if (index == 1)
      return DateTimeIntervalType.hours;
    else if (index == 2)
      return DateTimeIntervalType.days;
    else if (index == 3)
      return DateTimeIntervalType.auto;
    else
      return DateTimeIntervalType.auto;
  }

  getLogTime(Uint8List fetchData) {
    int tmp =
        ByteData.sublistView(fetchData.sublist(12, 16)).getInt32(0, Endian.big);
    DateTime time =
        DateTime.fromMillisecondsSinceEpoch(tmp * 1000, isUtc: true);

    return time;
  }

  getLogHumidity(Uint8List fetchData) {
    int tmp =
        ByteData.sublistView(fetchData.sublist(18, 20)).getInt16(0, Endian.big);

    return tmp / 100;
  }

  getLogTemperature(Uint8List fetchData) {
    int tmp =
        ByteData.sublistView(fetchData.sublist(16, 18)).getInt16(0, Endian.big);

    return tmp / 100;
  }

  fetchLogData() async {
    // DeviceInfo temp =
    //     await DBHelper().getDevice(widget.currentDevice.getserialNumber());
    // isSwitchedHumi = temp.isDesiredConditionOn == 'true' ? true : false;
    List<TempInfo> tempList = await DBHelper().getAllTemps();
    if (tempList.isEmpty) {
      // await DBHelper().initDB();
      minTemp = -10;
      maxTemp = 40;
    } else {
      minTemp = tempList[0].minTemp.toDouble();
      maxTemp = tempList[0].maxTemp.toDouble();
    }

    await monitorCharacteristic(widget.currentDevice.peripheral);
    print('Write Start');
    // print(widget.minmaxStamp.toString());
    // int tmp =
    //     ByteData.sublistView(widget.minmaxStamp.sublist(0, 3)).getInt32(0);
    // print(tmp);
    // int now = DateTime.now().millisecondsSinceEpoch;

    // print(DateTime.now().microsecondsSinceEpoch.toString());
    if (widget.currentDevice.peripheral.name == 'T301') {
      var writeCharacteristics = await widget.currentDevice.peripheral
          .writeCharacteristic(
              '00001000-0000-1000-8000-00805f9b34fb',
              '00001001-0000-1000-8000-00805f9b34fb',
              Uint8List.fromList([0x55, 0xAA, 0x01, 0x05] +
                  widget.currentDevice.getMacAddress() +
                  [0x04, 0x06] +
                  widget.startIndex +
                  widget.endindex),
              true);
    } else if (widget.currentDevice.peripheral.name == 'T306') {
      var writeCharacteristics = await widget.currentDevice.peripheral
          .writeCharacteristic(
              '00001000-0000-1000-8000-00805f9b34fb',
              '00001001-0000-1000-8000-00805f9b34fb',
              Uint8List.fromList([0x55, 0xAA, 0x01, 0x06] +
                  widget.currentDevice.getMacAddress() +
                  [0x04, 0x06] +
                  widget.startIndex +
                  widget.endindex),
              true);
    }
  }

  void _startMonitoringTemperature(
      Stream<Uint8List> characteristicUpdates, Peripheral peripheral) async {
    await monitoringStreamSubscription?.cancel();
    monitoringStreamSubscription = characteristicUpdates.listen(
      (notifyResult) async {
        if (notifyResult[10] == 0x05) {
          //TODO: 데이터 읽어오기
          // print(notifyResult.toString());
          LogData temp = transformData(notifyResult);
          setState(() {
            currentindex += 1;
          });
          if (count % 5 == 0) {
            fetchDatas.add(temp);
          }
          count++;
        }
        // DataFetch End
        else if (notifyResult[10] == 0x06) {
          print('총 몇개? ' + fetchDatas.length.toString());
          print('Read End !');
          if (fetchDatas.length > 500) {
            currentType = DateTimeIntervalType.auto;
            dataFiltering(3);
          } else {
            dataFiltering(1);
          }

          setState(() {
            // filteredDatas = fetchDatas;
            dataFetchEnd = true;
          });
        }
      },
      onError: (error) async {
        print("Error while monitoring characteristic \n$error");
        if (dataFetchEnd == false) {
          await showMyDialog(context);
          // Navigator.of(context).pop();
        }
      },
      cancelOnError: true,
    );
  }

  //Datalog Parsing
  LogData transformData(Uint8List notifyResult) {
    return new LogData(
        temperature: getLogTemperature(notifyResult),
        humidity: getLogHumidity(notifyResult),
        timestamp: getLogTime(notifyResult));
  }

  Future<void> monitorCharacteristic(Peripheral peripheral) async {
    await _runWithErrorHandling(() async {
      Service service = await peripheral.services().then((services) =>
          services.firstWhere((service) =>
              service.uuid == '00001000-0000-1000-8000-00805f9b34fb'));

      List<Characteristic> characteristics = await service.characteristics();
      Characteristic characteristic = characteristics.firstWhere(
          (characteristic) =>
              characteristic.uuid == '00001002-0000-1000-8000-00805f9b34fb');

      _startMonitoringTemperature(
          characteristic.monitor(transactionId: "monitor2"), peripheral);
    });
  }

  //BLE 연결시 예외 처리를 위한 래핑 함수
  _runWithErrorHandling(runFunction) async {
    try {
      await runFunction();
    } on BleError catch (e) {
      print("BleError caught: ${e.errorCode.value} ${e.reason}");
    } catch (e) {
      if (e is Error) {
        debugPrintStack(stackTrace: e.stackTrace);
      }
      print("${e.runtimeType}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey();
    final scaffoldKey = GlobalKey<ScaffoldState>();
    return MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            child: child,
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          );
        },
        debugShowCheckedModeBanner: false,
        title: 'OPTILO',
        theme: ThemeData(
          // primarySwatch: Colors.grey,
          backgroundColor: Color.fromRGBO(0, 66, 166, 1),
          //canvasColor: Colors.transparent,
        ),
        home: Scaffold(
            key: scaffoldKey,
            appBar: AppBar(
              backgroundColor: Color.fromRGBO(0, 66, 166, 1),
              title: Row(
                  // mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: SizedBox()),
                    Expanded(
                      flex: 7,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Image(
                              image: AssetImage('images/background.png'),
                              fit: BoxFit.contain,
                              width: MediaQuery.of(context).size.width * 0.4,
                              // height: MediaQuery.of(context).size.width * 0.1,
                            ),
                          ]),
                    ),
                    Expanded(
                      flex: 4,
                      child: SizedBox(),
                    )
                  ]),
            ),
            body: Screenshot(
                controller: screenshotController,
                child: Container(
                    height: MediaQuery.of(context).size.height * 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(children: [
                          // DefaultTabController(
                          //     length: 4,
                          //     initialIndex: 1,
                          //     child: Center(
                          //         child: Padding(
                          //             padding: const EdgeInsets.symmetric(
                          //                 horizontal: 1),
                          //             child: Column(
                          //                 mainAxisAlignment:
                          //                     MainAxisAlignment.center,
                          //                 children: <Widget>[
                          //                   Material(
                          //                     child: TabBar(
                          //                       onTap: (index) => {
                          //                         setState(() {
                          //                           currentType =
                          //                               toggleType(index);
                          //                         })
                          //                       },
                          //                       indicatorColor: Colors.green,
                          //                       tabs: [
                          //                         Tab(
                          //                           text: "시간",
                          //                         ),
                          //                         Tab(
                          //                           text: "하루",
                          //                         ),
                          //                         Tab(
                          //                           text: "일주일",
                          //                         ),
                          //                         Tab(
                          //                           text: "한달",
                          //                         ),
                          //                         // Tab(
                          //                         //   text: "Year",
                          //                         // ),
                          //                       ],
                          //                       labelColor: Colors.black,
                          //                       indicator: MaterialIndicator(
                          //                         height: 5,
                          //                         topLeftRadius: 8,
                          //                         topRightRadius: 8,
                          //                         horizontalPadding: 5,
                          //                         tabPosition:
                          //                             TabPosition.bottom,
                          //                       ),
                          //                     ),
                          //                   )
                          //                 ])))),
                          fetchDatas.length < 500
                              ? Text(
                                  widget.currentDevice.getserialNumber() +
                                      ' (하루)',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800))
                              : Text(
                                  widget.currentDevice.getserialNumber() +
                                      ' (한달)',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              dataFetchEnd == false
                                  ? Center(
                                      // height:
                                      //     MediaQuery.of(context).size.height * 0.85,
                                      child: Container(
                                      padding: EdgeInsets.all(4),
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.75,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              log,
                                              style: thinTextStyle,
                                            ),
                                            Text(''),
                                            log == '데이터 가져오는 중'
                                                ? CircularProgressIndicator(
                                                    backgroundColor:
                                                        Colors.black26,
                                                  )
                                                : SizedBox(),
                                            log == '데이터 가져오는 중'
                                                ? Text('\n' +
                                                    (currentindex /
                                                            (threeBytesToint(widget
                                                                    .endindex) -
                                                                threeBytesToint(
                                                                    widget
                                                                        .startIndex)) *
                                                            100)
                                                        .toStringAsFixed(0) +
                                                    ' %')
                                                : SizedBox(),
                                          ]),
                                    ))
                                  : Container(
                                      padding: EdgeInsets.all(4),
                                      // height: MediaQuery.of(context).size.height *
                                      //     0.7,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Column(
                                            children: [
                                              SfCartesianChart(
                                                  primaryYAxis: NumericAxis(
                                                      maximum: maxTemp,
                                                      interval: 5,
                                                      minimum: minTemp,
                                                      plotBands: <PlotBand>[
                                                        PlotBand(
                                                          horizontalTextAlignment:
                                                              TextAnchor.end,
                                                          shouldRenderAboveSeries:
                                                              false,
                                                          text: '$_minTemp°C',
                                                          textStyle: TextStyle(
                                                              color: Colors.red,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                          isVisible: true,
                                                          start: _minTemp,
                                                          end: _minTemp,
                                                          borderWidth: 2,
                                                          // color: Colors.red,
                                                          // opacity: 0.3,
                                                          // color: Color.fromRGBO(
                                                          //     255, 255, 255, 1.0),
                                                          borderColor:
                                                              Colors.red,
                                                        ),
                                                        PlotBand(
                                                          horizontalTextAlignment:
                                                              TextAnchor.end,
                                                          shouldRenderAboveSeries:
                                                              false,
                                                          text: '$_maxTemp°C',
                                                          textStyle: TextStyle(
                                                              color: Colors.red,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                          isVisible: true,
                                                          start: _maxTemp,
                                                          end: _maxTemp,
                                                          borderWidth: 2,
                                                          // color: Colors.grey,
                                                          // opacity: 0.3
                                                          // color: Color.fromRGBO(
                                                          //     255, 255, 255, 1.0),
                                                          borderColor:
                                                              Colors.red,
                                                        )
                                                      ]),
                                                  primaryXAxis: DateTimeAxis(
                                                      labelRotation: 5,
                                                      maximumLabels: 5,
                                                      // Set name for x axis in order to use it in the callback event.
                                                      name: 'primaryXAxis',
                                                      intervalType: currentType,
                                                      majorGridLines:
                                                          MajorGridLines(
                                                              width: 1)),

                                                  // Chart title
                                                  title: ChartTitle(
                                                      text: '온도 그래프'),
                                                  // Enable legend
                                                  legend:
                                                      Legend(isVisible: false),
                                                  // Enable tooltip
                                                  tooltipBehavior:
                                                      TooltipBehavior(
                                                          enable: true),
                                                  series: <
                                                      ChartSeries<LogData,
                                                          DateTime>>[
                                                    LineSeries<LogData,
                                                            DateTime>(
                                                        dataSource:
                                                            filteredDatas,
                                                        xValueMapper:
                                                            (LogData data, _) {
                                                          return data.timestamp;
                                                        },
                                                        yValueMapper: (LogData
                                                                    data,
                                                                _) =>
                                                            data.temperature,
                                                        name: '온도',
                                                        // Enable data label
                                                        dataLabelSettings:
                                                            DataLabelSettings(
                                                                isVisible:
                                                                    false))
                                                  ]),
                                              dataFetchEnd == true
                                                  ? Text(filteredDatas[
                                                              filteredDatas
                                                                      .length -
                                                                  1]
                                                          .timestamp
                                                          .toLocal()
                                                          .toString()
                                                          .substring(0, 19) +
                                                      ' ~ ' +
                                                      filteredDatas[0]
                                                          .timestamp
                                                          .toLocal()
                                                          .toString()
                                                          .substring(0, 19))
                                                  : Text(''),
                                              // Text('총 데이터 (1분 단위) : ' +
                                              //     count.toString() +
                                              //     '개'),
                                            ],
                                            // 1분단위 세시간 -> 180개 -> 3분단위 -> 60개 -> 3분단위 100 -> 300 분 5시간 ?
                                          ),
                                        ],
                                      ))
                            ],
                          ),
                          dataFetchEnd == true
                              ? Container(
                                  margin: EdgeInsets.all(8),
                                  padding: EdgeInsets.all(8),
                                  child: DateTimePicker(
                                    type: DateTimePickerType.dateTimeSeparate,
                                    dateMask: 'yyyy/MM/dd',
                                    initialValue: startDateTime.toString(),
                                    firstDate: filteredDatas.last.timestamp,
                                    lastDate: DateTime.now().toLocal(),
                                    icon: Icon(Icons.event,
                                        color: Color.fromRGBO(2, 109, 194, 1)),
                                    dateLabelText: '시작날짜',
                                    timeLabelText: "시간",
                                    selectableDayPredicate: (date) {
                                      // Disable weekend days to select from the calendar

                                      return true;
                                    },
                                    onChanged: (val) => setState(() =>
                                        startDateTime = DateTime.parse(val)),
                                    validator: (val) {
                                      print(val + '12');
                                      return null;
                                    },
                                    onSaved: (val) => print(val + '123'),
                                  ),
                                )
                              : SizedBox(),
                          dataFetchEnd == true
                              ? Container(
                                  margin: EdgeInsets.all(8),
                                  padding: EdgeInsets.all(16),
                                  child: DateTimePicker(
                                    type: DateTimePickerType.dateTimeSeparate,
                                    dateMask: 'yyyy/MM/dd',
                                    initialValue:
                                        endDateTime.toLocal().toString(),
                                    firstDate: startDateTime,
                                    lastDate: DateTime.now().toLocal(),
                                    icon: Icon(Icons.event,
                                        color: Color.fromRGBO(2, 109, 194, 1)),
                                    dateLabelText: '종료날짜',
                                    timeLabelText: "시간",
                                    selectableDayPredicate: (date) {
                                      // Disable weekend days to select from the calendar

                                      return true;
                                    },
                                    onChanged: (val) => setState(() =>
                                        endDateTime = DateTime.parse(val)),
                                    validator: (val) {
                                      print(val + '12');
                                      return null;
                                    },
                                    onSaved: (val) => print(val + '123'),
                                  ),
                                )
                              : SizedBox(),
                          dataFetchEnd == true
                              ? InkWell(
                                  onTap: () {
                                    // 조회 Function
                                    // 1. 시작시간 종료시간 필터링
                                    // 2. 그래프 refresh
                                    if (startDateTime.isBefore(endDateTime)) {
                                      refreshFilteredData();
                                      print(startDateTime.toString());
                                      print(endDateTime.toString());
                                    }
                                  },
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: Color.fromRGBO(2, 109, 194, 1),
                                          boxShadow: [customeBoxShadow()],
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(5))),
                                      margin: EdgeInsets.all(8),
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '조회하기',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      )),
                                )
                              : SizedBox(),
                        ]),
                        dataFetchEnd == true
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                      flex: 1,
                                      child: InkWell(
                                        onTap: () async {
                                          await exportxlsx();
                                        },
                                        child: Container(
                                            decoration: BoxDecoration(
                                                color: Color.fromRGBO(
                                                    170, 170, 170, 1),
                                                boxShadow: [customeBoxShadow()],
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(5))),
                                            margin: EdgeInsets.all(8),
                                            padding: EdgeInsets.all(8),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'EXCEL로 내보내기',
                                                ),
                                              ],
                                            )),
                                      )),
                                  Expanded(
                                      flex: 1,
                                      child: InkWell(
                                        onTap: () async {
                                          await takeScreenshot();
                                          // showUploadDialog(
                                          //     context, filteredDatas.length);
                                          // sendFetchData();
                                          ui.Image result = await saveSignature(
                                              context, _signaturePadKey);
                                          print(result.height.toString());
                                          await uploadPDF2(result);
                                        },
                                        child: Container(
                                            decoration: BoxDecoration(
                                                color: Color.fromRGBO(
                                                    170, 170, 170, 1),
                                                boxShadow: [customeBoxShadow()],
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(5))),
                                            margin: EdgeInsets.all(8),
                                            padding: EdgeInsets.all(8),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'PDF로 내보내기',
                                                ),
                                              ],
                                            )),
                                      )),
                                ],
                              )
                            : SizedBox(),
                      ],
                    )))));
  }
}

BoxShadow customeBoxShadow() {
  return BoxShadow(
      color: Colors.black.withOpacity(0.2),
      offset: Offset(0, 1),
      blurRadius: 6);
}

TextStyle thinTextStyle = TextStyle(
  fontSize: 24,
  color: Color.fromRGBO(20, 20, 20, 1),
  fontWeight: FontWeight.w500,
);

showMyDialog(BuildContext context) {
  bool manuallyClosed = false;
  Future.delayed(Duration(seconds: 2)).then((_) {
    if (!manuallyClosed) {
      Navigator.of(context).pop();
    }
  });
  return showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        backgroundColor: Color.fromRGBO(22, 33, 55, 1),
        elevation: 16.0,
        child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: MediaQuery.of(context).size.height / 4,
            padding: EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width / 5,
                      ),
                      Text("로드 중 에러가 발생",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          textAlign: TextAlign.center),
                      Text("다시시도해주세요",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 13),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            )),
      );
    },
  );
}

showUploadDialog(BuildContext context, int size) {
  bool manuallyClosed = false;
  Future.delayed(Duration(seconds: 2)).then((_) {
    if (!manuallyClosed) {
      Navigator.of(context).pop();
    }
  });
  return showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        backgroundColor: Color.fromRGBO(22, 33, 55, 1),
        elevation: 16.0,
        child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: MediaQuery.of(context).size.height / 4,
            padding: EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width / 5,
                      ),
                      Text('총 ' + size.toString() + '개의 데이터를 전송합니다.',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                              fontSize: 14),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            )),
      );
    },
  );
}

threeBytesToint(Uint8List temp) {
  int r = ((temp[0] & 0xF) << 16) | ((temp[1] & 0xFF) << 8) | (temp[2] & 0xFF);
  return r;
}
