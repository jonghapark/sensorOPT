import 'package:flutter/material.dart';
import 'package:sensoropt/models/model_bleDevice.dart';
import 'package:sensoropt/models/model_logdata.dart';
import 'package:sensoropt/utils/util.dart';
import '../component/screen_main.dart';
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
import 'dart:io';
import 'package:numberpicker/numberpicker.dart';
import 'package:flutter/services.dart';

// 데이터는 계속
// 전체 데이터 시작부터 종료까지
class EditScreen extends StatefulWidget {
  final BleDeviceItem currentDevice;

  EditScreen({this.currentDevice});

  @override
  _EditScreenState createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  String valueText = '';
  String codeDialog = '';

  StreamSubscription monitoringStreamSubscription;
  StreamSubscription<loc.LocationData> _locationSubscription;
  bool dataFetchEnd = false;
  List<LogData> fetchDatas = [];
  List<LogData> filteredDatas = [];
  int count = 0;
  BleDeviceItem selectedDevice;
  TextEditingController _textFieldController;

  int _minTemp = 4;
  int _maxTemp = 28;
  int _minHumi = 4;
  int _maxHumi = 28;
  bool isSwitchedHumi = true;
  bool isSwitchedTemp = true;
  Future<DeviceInfo> _deviceData;
  Future<List<DeviceInfo>> _allDeviceTemp;

  loc.Location location = new loc.Location();
  loc.LocationData currentLocation;
  String geolocation;
  DateTimeIntervalType currentType = DateTimeIntervalType.hours;
  // _IntegerExample test;

  @override
  void initState() {
    _minTemp = 4;
    _maxTemp = 28;
    _minHumi = 4;
    _maxHumi = 28;
    selectedDevice = widget.currentDevice;
    _deviceData = DBHelper().getDevice(widget.currentDevice.getserialNumber());
    _allDeviceTemp = DBHelper().getAllDevices();
    super.initState();
    // test = _IntegerExample();
  }

  Future<String> deleteDeviceDialog(BuildContext context) async {
    return showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('기기 삭제'),
            content: Text("정말로 삭제 하시겠습니까?"),
            actions: <Widget>[
              TextButton(
                child: Text('취소'),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
              TextButton(
                child: Text('확인'),
                onPressed: () async {
                  await DBHelper()
                      .deleteSavedDevice(selectedDevice.getserialNumber());
                  await DBHelper()
                      .deleteDevice(selectedDevice.getserialNumber());
                  Navigator.pop(context, 'goback');
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
          primaryColor: Color.fromRGBO(100, 137, 254, 1),
          //canvasColor: Colors.transparent,
        ),
        home: Scaffold(
            appBar: AppBar(
              // backgroundColor: Color.fromARGB(22, 27, 32, 1),
              title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'SensorOpt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width / 18,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
            ),
            body: Center(
                child: Container(
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(180, 180, 180, 1),
                        // boxShadow: [customeBoxShadow()],
                        borderRadius: BorderRadius.all(Radius.circular(5))),
                    height: MediaQuery.of(context).size.height * 0.9,
                    width: MediaQuery.of(context).size.width * 1.0,
                    child: Column(children: [
                      Expanded(flex: 6, child: SizedBox()),
                      Expanded(
                          flex: 1,
                          child: Container(
                              margin: EdgeInsets.only(top: 3),
                              padding: EdgeInsets.only(top: 5, left: 12),
                              width: MediaQuery.of(context).size.width * 0.98,
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(71, 71, 71, 1),
                                  //boxShadow: [customeBoxShadow()],
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5))),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Mac Address : ',
                                      style: whiteBoldTextStyle),
                                  Text(selectedDevice.peripheral.identifier,
                                      style: whiteTextStyle)
                                ],
                              ))),
                      Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () async {
                              await deleteDeviceDialog(context).then((value) =>
                                  value == 'goback'
                                      ? Navigator.pop(context,
                                          selectedDevice.peripheral.identifier)
                                      : print(''));
                            },
                            child: Container(
                                margin: EdgeInsets.only(
                                  top: 12,
                                ),
                                padding: EdgeInsets.only(top: 3, left: 12),
                                height: 50,
                                width: MediaQuery.of(context).size.width * 1.0,
                                decoration: BoxDecoration(
                                    color: Color.fromRGBO(0xff, 0x2e, 0x16, 1),
                                    //boxShadow: [customeBoxShadow()],
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5))),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('삭제하기', style: whiteBoldTextStyle),
                                  ],
                                )),
                          )),
                    ])))));
  }

  Widget getbatteryImage(int battery) {
    if (battery >= 75) {
      return Image(
        image: AssetImage('images/battery_100.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
    } else if (battery >= 50) {
      return Image(
        image: AssetImage('images/battery_75.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
    } else if (battery >= 35) {
      return Image(
        image: AssetImage('images/battery_50.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
    } else {
      return Image(
        image: AssetImage('images/battery_25.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
    }
  }
}

TextStyle thinTextStyle = TextStyle(
  fontSize: 20,
  color: Color.fromRGBO(20, 20, 20, 1),
  fontWeight: FontWeight.w200,
);

showMyDialog(BuildContext context) {
  bool manuallyClosed = false;
  return new AlertDialog(
    contentPadding: const EdgeInsets.all(16.0),
    content: new Row(
      children: <Widget>[
        new Expanded(
          child: new TextField(
            autofocus: true,
            decoration: new InputDecoration(
                labelText: 'Full Name', hintText: 'eg. John Smith'),
          ),
        )
      ],
    ),
    actions: <Widget>[
      new TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Text('CANCEL'),
      ),
      new TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Text('CANCEL'),
      )
    ],
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

TextStyle whiteBoldTextStyle = TextStyle(
  fontSize: 18,
  color: Color.fromRGBO(255, 255, 255, 1),
  fontWeight: FontWeight.w700,
);
TextStyle whiteTextStyle = TextStyle(
  fontSize: 16,
  color: Color.fromRGBO(255, 255, 255, 1),
  fontWeight: FontWeight.w700,
);
TextStyle smallWhiteTextStyle = TextStyle(
  fontSize: 14,
  color: Color.fromRGBO(255, 255, 255, 1),
  fontWeight: FontWeight.w500,
);

showMyDialog_Delete(BuildContext context) {
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
        backgroundColor: Color.fromRGBO(0x61, 0xB2, 0xD0, 1),
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
                        Icons.bluetooth,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width / 5,
                      ),
                      Text("기기를 삭제했습니다. !",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18),
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
