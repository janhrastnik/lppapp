import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      home: MyHomePage(title: ";-;",),
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
  
  Future<http.Response> getRouteGroups() {
    return http.get("http://data.lpp.si/routes/getRouteGroups");
  }

  Future<http.Response> getRoutes(routeNumber) {
    return http.get("http://data.lpp.si/routes/getRoutes?route_name=$routeNumber");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder(
            future: getRouteGroups(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasData) {
                List routeGroupsList = jsonDecode(snapshot.data.body)["data"];
                routeGroupsList.sort((a, b) => int.parse(a["name"], radix: 30).compareTo(int.parse(b["name"], radix: 30)));
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: routeGroupsList.length,
                  itemBuilder: (BuildContext context, int index) => ExpansionTile(
                    title: Text(routeGroupsList[index]["name"].toString()),
                    children: <Widget>[
                      FutureBuilder(
                        future: getRoutes(routeGroupsList[index]["name"]),
                        builder: (BuildContext context, AsyncSnapshot snapshot) {
                          if (snapshot.hasData) {
                            List routesList = jsonDecode(snapshot.data.body)["data"];
                            return ListView.builder(
                                shrinkWrap: true,
                                itemCount: routesList.length,
                                itemBuilder: (BuildContext context, int index) => ListTile(
                                  title: Text(routesList[index]["parent_name"]),
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
              List stationsList = jsonDecode(snapshot.data.body)["data"];
              stationsList.sort((a, b) => a["order_no"].compareTo(b["order_no"]));
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

class StationList extends StatelessWidget {

  Future<http.Response> getAllStations() {
    return http.get("http://data.lpp.si/stations/getAllStations");
  }

  Future<http.Response> getRoutesOnStation(stationId) {
    return http.get("http://data.lpp.si/stations/getRoutesOnStation?station_int_id=$stationId");
  }

  Future<http.Response> getArrivals(stationId) {
    return http.get("194.33.12.24/timetables/getArrivalsOnStation?station_int_id=$stationId");
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder(
            future: getAllStations(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasData) {
                List stationList = jsonDecode(snapshot.data.body)["data"];
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: stationList.length,
                  itemBuilder: (BuildContext context, int index) => ListTile(
                    leading: Text(stationList[index]["name"]),
                    onTap: () {
                      getRoutesOnStation(stationList[index]["int_id"]).then((data) {
                        print(data.body);
                      });
                    },
                  ),
                );
              } else {
                  return CircularProgressIndicator();
              }
            }
        ),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  Map routeGroups;

  Future<http.Response> getRouteGroups() {
    return http.get("http://data.lpp.si/routes/getRouteGroups");
  }

  Future<void> getRoutes(routeNumber) async {
    await http.get("http://data.lpp.si/routes/getRoutes?route_name=$routeNumber");
  }

  Future<List<void>> getData() async {
    http.Response data = await getRouteGroups();
    List routeGroupsList = jsonDecode(data.body)["data"];
    routeGroupsList.forEach((e) => routeGroups[e["name"]] = null);
    return Future.wait(
      routeGroupsList.map((e) => getRoutes(e["name"]))
    );
  }

  @override
  void initState() {
    super.initState();
    getData().then((data) {
      print(data.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return null;
  }
}