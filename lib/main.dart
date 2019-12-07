import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart' as collection;

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
              children: routeNames.map((route) => Text(route[0])).toList(),
            );
          }
              
      )
    );
  }
}

class Route extends StatefulWidget {
  Route({Key key, this.routeId}) : super(key: key);

  int routeId;

  @override
  RouteState createState() => RouteState();
}

class RouteState extends State<Route> {

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
      for (int index = 0; index < routes[key].length; index++) {

        if (routes[key][index][0].contains("obvoz")) {
          print("nice");
          removables.add(routes[key][index]);
        }
      }
      for (var removable in removables) {
        print(removable);
        routes[key].remove(removable);
      }
    }
    return routes;
  }

  @override
  void initState() {
    super.initState();
    getData().then((data) {
      data.where((e) => jsonDecode(e.body)["data"].length != 0).forEach((e) =>
        jsonDecode(e.body)["data"].forEach((e) =>
        routeGroups[e["group_name"]].add([e["route_name"], e["int_id"], e["route_parent_id"]])));
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