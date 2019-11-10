import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:beautifulsoup/beautifulsoup.dart';
import 'dart:convert';

void main() => runApp(MyApp());
String url = "https://www.lpp.si/";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String html = "";
  
  Future<http.Response> getRoutesGroups() {
    return http.get("http://data.lpp.si/routes/getRouteGroups");
  }

  Future<http.Response> getRoutes(routeNumber) {
    return http.get("http://data.lpp.si/routes/getRoutes?route_name=$routeNumber");
  }

  Future<http.Response> getRouteStations(routeId) {
    return http.get("http://data.lpp.si/routes/getStationsOnRoute?route_id=$routeId");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder(
            future: getRoutesGroups(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasData) {
                List decodedData = jsonDecode(snapshot.data.body)["data"];
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: decodedData.length,
                  itemBuilder: (BuildContext context, int index) => ExpansionTile(
                    title: Text(decodedData[index].toString()),
                    children: <Widget>[
                      FutureBuilder(
                        future: getRoutes(decodedData[index]["name"]),
                        builder: (BuildContext context, AsyncSnapshot snapshot) {
                          if (snapshot.hasData) {
                            List routesList = jsonDecode(snapshot.data.body)["data"];
                            return ListView.builder(
                                shrinkWrap: true,
                                itemCount: routesList.length,
                                itemBuilder: (BuildContext context, int index) => ListTile(
                                  title: Text(routesList[index]["route_parent_id"]),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (BuildContext context) => Station(routeId: routesList[index]["int_id"])
                                      )
                                    );
                                  },
                                )
                            );
                          } else {
                            return Text("no data");
                          }
                        },
                      )
                    ],
                  ),
                );
              } else {
                return Text("no data");
              }
            }
        ),
      ),
    );
  }
}

class Station extends StatefulWidget {
  Station({Key key, this.routeId, this.reverseRouteId}) : super(key: key);

  int routeId;
  int reverseRouteId;

  @override
  StationState createState() => StationState();
}

class StationState extends State<Station> {

  Future<http.Response> getStations(id) {
    return http.get("http://data.lpp.si/routes/getStationsOnRoute?route_int_id=$id");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: getStations(widget.routeId),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.hasData) {
              //TODO: add sorting
              List stationsList = jsonDecode(snapshot.data.body)["data"];
              print(stationsList.toString());
              return ListView.builder(
                  shrinkWrap: true,
                  itemCount: stationsList.length,
                  itemBuilder: (BuildContext context, int index) => ListTile(
                    title: Text(stationsList[index]["name"]),
                  )
              );
            } else {
              return Text("no data");
            }
          }
      )
    );
  }
}