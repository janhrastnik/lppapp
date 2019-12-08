import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart' as collection;
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:built_value/serializer.dart';

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
      home: SplashPage()
    );
  }
}

class RouteList extends StatefulWidget {
  RouteList({Key key, this.routes}) : super(key: key);

  final Map routes;

  @override
  RouteListState createState() => RouteListState();
}

class RouteListState extends State<RouteList> {
  
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
          itemCount: widget.routes.length,
          itemBuilder: (BuildContext context, int index) {
            String routeGroup = widget.routes.keys.toList()[index];
            List routeNames = widget.routes[routeGroup];
            return ExpansionTile(
              title: Text(routeGroup),
              children: routeNames.map((route) => ListTile(
                title: Text(route[0]),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (BuildContext context) => Route(
                      routeId: route[1],
                      oppositeRouteId: route[2],
                    )
                  ));
                }
              ),
            ).toList(),
            );
          }
              
      )
    );
  }
}

class Route extends StatefulWidget {
  Route({Key key, this.routeId, this.oppositeRouteId}) : super(key: key);

  int routeId;
  int oppositeRouteId;

  @override
  RouteState createState() => RouteState();
}

class RouteState extends State<Route> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: RouteDisplay(id: widget.routeId)),
        ],
      ),
    );
  }
}

class RouteDisplay extends StatelessWidget {
  RouteDisplay({Key key, this.id}) : super(key: key);
  int id;

  Future<http.Response> getStations(id) {
    return http.get("http://data.lpp.si/routes/getStationsOnRoute?route_int_id=$id");
  }

  Future<http.Response> getRouteDetails(id) {
    return http.get("http://data.lpp.si/routes/getRouteDetails?route_int_id=$id");
  }

  Future<http.Response> getArrivalsOnStation(id) {
    return http.get("http://194.33.12.24/timetables/getArrivalsOnStation?station_int_id=$id");
  }

  void _showDialog(data, context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          var serializers =
          (Serializers().toBuilder()..add(Iso8601DateTimeSerializer())).build();
          print(data.toString());
          return AlertDialog(
            content: ListView.builder(
                itemCount: data.length,
                itemBuilder: (BuildContext context, int index) {
                  DateTime date = serializers.deserialize(data[index]["arrival_time"], specifiedType: const FullType(DateTime));
                  return ListTile(
                    title: Text("${date.hour.toString()}:${date.minute.toString()}"),
                  );
                }
            )
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getStations(id),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            List stationsList = jsonDecode(snapshot.data.body)["data"];
            stationsList.sort((a, b) => a["order_no"].compareTo(b["order_no"]));
            return Column(
              children: <Widget>[
                FutureBuilder(
                  future: getRouteDetails(id),
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    if (snapshot.hasData) {
                      Map routeData = jsonDecode(snapshot.data.body)["data"];
                      return Text(routeData["name"]);
                    } else {
                      return Center(child: CircularProgressIndicator());
                    }
                  },
                ),
                Expanded(
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: stationsList.length,
                      itemBuilder: (BuildContext context, int index) => ListTile(
                        title: Text(stationsList[index]["name"]),
                        onTap: () {
                          getArrivalsOnStation(stationsList[index]["int_id"]).then((data) {
                            Map decoded = jsonDecode(data.body);
                            _showDialog(decoded["data"], context);
                          });
                        },
                      )
                  ),
                )
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        }
    );
  }
}

class SplashPage extends StatefulWidget {
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  Map routeGroups = Map();

  Future<http.Response> getRouteGroups() {
    return http.get("http://data.lpp.si/routes/getRouteGroups");
  }

  Future<http.Response> getRoutes(routeNumber) {
    return http.get("http://data.lpp.si/routes/getRoutes?route_name=$routeNumber");
  }

  Future<List> getData() async {
    http.Response data = await getRouteGroups();
    List routeGroupsList = jsonDecode(data.body)["data"];
    routeGroupsList.forEach((e) => routeGroups[e["name"]] = List());
    return Future.wait(
      routeGroupsList.map((e) => getRoutes(e["name"]))
    );
  }

  Map routeFilter(Map routes) {
    // TODO: obvozi, unique n-routi
    // TODO: ne removat po indexu
    RegExp r1 = RegExp(r"^[A-Z]");
    RegExp r2 = RegExp(r"^[A-Z]");
    routes.removeWhere((key, value) => value.isEmpty);
    for (String key in routes.keys) {
      List removables = [];
      List opposites = [];

      routes[key].forEach((e) {
        try {
          if (e[1] < e[2]) {
            opposites.add(e[2]);
          }
        } catch (e) {}
        if(e[3].contains("obvoz")) {
          removables.add(e);
        }
      });

      routes[key].removeWhere((e) => removables.contains(e) || opposites.contains(e[2]));
    }
    return routes;
  }

  @override
  void initState() {
    super.initState();
    getData().then((data) {
      data.where((e) => jsonDecode(e.body)["data"].length != 0).forEach((e) =>
        jsonDecode(e.body)["data"].forEach((e) =>
        routeGroups[e["group_name"]].add([e["parent_name"], e["int_id"], e["opposite_route_int_id"], e["route_name"]])));
      routeGroups = routeFilter(routeGroups);
      SplayTreeMap routes = SplayTreeMap.from(routeGroups, (a, b) => collection.compareNatural(a, b));
      print(routes);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (BuildContext context) => RouteList(routes: routes)
      ));
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}