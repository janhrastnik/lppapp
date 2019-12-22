import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart' as collection;
import 'package:flutter/services.dart';
import 'package:duration/duration.dart';
import 'package:date_format/date_format.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([]);
    return MaterialApp(
      title: 'LPP Prihodi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: SplashPage(),
    );
  }
}

class RouteList extends StatelessWidget {
  RouteList({Key key, this.routes}) : super(key: key);

  final Map routes;

  String getNumber(String routeGroup, String routeName) {
    //TODO: add regex for leading numbers
    RegExp reg = RegExp(r"^[A-Z] ");
    RegExpMatch matches = reg.firstMatch(routeName);
    return matches != null ? routeGroup + matches.group(0) : routeGroup;

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Linije"),
      ),
      body: ListView.builder(
          itemCount: routes.length,
          itemBuilder: (BuildContext context, int index) {
            String routeGroup = routes.keys.toList()[index];
            List routeNames = routes[routeGroup];
            return ExpansionTile(
              title: Text(routeGroup),
              children: routeNames.map((route) => ListTile(
                leading: Container(
                  width: 30.0,
                  height: 30.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0),
                    color: Colors.green,
                  ),
                  child: Center(child: Text(getNumber(routeGroup, route[0]), style: TextStyle(color: Colors.white), textAlign: TextAlign.center,)),
                ),
                title: Text(route[0]), // route title
                subtitle: Text(route[3]), // subroute title
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

class Route extends StatelessWidget {
  Route({Key key, this.routeId, this.oppositeRouteId}) : super(key: key);

  final int routeId;
  final int oppositeRouteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Postaje"),
      ),
      body: Row(
        children: <Widget>[
          Expanded(child: RouteDisplay(id: routeId)),
          VerticalDivider(color: Colors.black54,),
          oppositeRouteId != null ? Expanded(child: RouteDisplay(id: oppositeRouteId)) : Container()
        ],
      ),
    );
  }
}

class RouteDisplay extends StatelessWidget {
  RouteDisplay({Key key, this.id}) : super(key: key);
  final int id;

  Future<http.Response> getStations(id) {
    return http.get("http://data.lpp.si/routes/getStationsOnRoute?route_int_id=$id");
  }

  Future<http.Response> getRouteDetails(id) {
    return http.get("http://data.lpp.si/routes/getRouteDetails?route_int_id=$id");
  }

  Future<http.Response> getArrivalsOnStation(stationId, routeId) {
    return http.get("http://data.lpp.si/timetables/getArrivalsOnStation?station_int_id=$stationId&route_int_id=$routeId");
  }

  Future<http.Response> getLiveBusArrival(stationId) {
    return http.get("http://data.lpp.si/timetables/liveBusArrival?station_int_id=$stationId");
  }

  void _showDialog(stationId, routeId, context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text("Prihajajoči prihodi"),
              content: FutureBuilder(
                  future: Future.wait([
                    getArrivalsOnStation(stationId, routeId),
                    getLiveBusArrival(stationId)
                  ]),
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    if (snapshot.hasData) {
                      // vozni red
                      List timetable = jsonDecode(snapshot.data[0].body)["data"];

                      List liveArrivals = jsonDecode(snapshot.data[1].body)["data"];

                      if (liveArrivals.isNotEmpty) {
                        for (var arrival in liveArrivals) {
                          List<List> diffs = List();
                          DateTime arrivalDate = DateTime.now().add(Duration(minutes: arrival["eta"]));
                          for (var date in timetable) {
                            DateTime estimatedDate = DateTime.parse(
                                date["arrival_time"]).toLocal().subtract(Duration(hours: 1));
                            List entry = [timetable.indexOf(date), arrivalDate.difference(estimatedDate)];
                            diffs.add(entry);
                          }
                          diffs.sort((a, b) => a[1].abs().compareTo(b[1].abs()));
                          // first value in diffs is the most probable timetable correlation
                          List valueToChange = diffs.first;
                          timetable[valueToChange[0]]["arrival_time"] = arrivalDate.toIso8601String();
                          // if this is the first live arrival, remove all timetable entries up to the live arrival
                          if (liveArrivals.indexOf(arrival) == 0) {
                            timetable = timetable.sublist(valueToChange[0]);
                          }
                        }
                      } else {
                        timetable.removeWhere((e) => DateTime.now().isAfter(
                          DateTime.parse(e["arrival_time"]).toLocal()
                        ));
                      }
                      return timetable != null && timetable != [] ? ListView.builder(
                          shrinkWrap: true,
                          itemCount: timetable.length,
                          itemBuilder: (BuildContext context, int index) {
                            Duration dur;
                            if (liveArrivals.isNotEmpty) {
                              // TODO: set dur
                            }
                            return Wrap(
                              direction: Axis.vertical,
                              children: <Widget>[
                                Text(formatDate(DateTime.parse(timetable[index]["arrival_time"]),
                                    [HH, ':', nn])
                                ),
                                Text(dur.toString()),
                            ]);
                          }
                      ) : Text("Prihodi za dano postajo niso bili najdeni. Linija morda danes ne vozi.");
                    } else {
                      return Center(child: CircularProgressIndicator(),);
                    }
                  })
          );
        });
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
                      return Container(
                        padding: EdgeInsets.all(8.0),
                        child: Text(routeData["name"], style: TextStyle(fontSize: 20.0),),
                        width: double.infinity,
                      );
                    } else {
                      return Center(child: CircularProgressIndicator());
                    }
                  },
                ),
                Divider(color: Colors.black54,),
                Expanded(
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: stationsList.length,
                      itemBuilder: (BuildContext context, int index) => ListTile(
                        title: Text(stationsList[index]["name"]),
                        onTap: () {
                            _showDialog(stationsList[index]["int_id"], id, context);
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

  void _showErrDialog(context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Povezava ni bila najdena"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text("Aplikacija potrebuje internet za nalaganje podatkov. Vklopite "
                  "povezavo in poskusite znova."),
              MaterialButton(
                  child: Text("Poskusi znova"),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (BuildContext context) => SplashPage()
                    ));
                  })
            ],
          ),
        );
      }
    );
  }

  Future<List> getData() async {
    try {
      http.Response data = await getRouteGroups();
      List routeGroupsList = jsonDecode(data.body)["data"];
      routeGroupsList.forEach((e) => routeGroups[e["name"]] = List());
      return Future.wait(
          routeGroupsList.map((e) => getRoutes(e["name"]))
      );
    } catch (_) {
      print("err");
    }
  }

  Map routeFilter(Map routes) {
    // TODO: obvozi, unique n-routi
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
        if(e[3].contains("obvoz") || e[3].contains("GARAŽA")) {
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
      if (data == null) {
        _showErrDialog(context);
      } else {
        data.where((e) => jsonDecode(e.body)["data"].length != 0).forEach((e) =>
            jsonDecode(e.body)["data"].forEach((e) =>
                routeGroups[e["group_name"]].add([e["parent_name"], e["int_id"], e["opposite_route_int_id"], e["route_name"]])));
        routeGroups = routeFilter(routeGroups);
        SplayTreeMap routes = SplayTreeMap.from(routeGroups, (a, b) => collection.compareNatural(a, b));
        print(routes);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (BuildContext context) => RouteList(routes: routes)
        ));
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF28b463),
      body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset("assets/bus.png"),
          CircularProgressIndicator(backgroundColor: Colors.white)
        ],
      ))
    );
  }
}