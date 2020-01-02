import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart' as collection;
import 'package:flutter/services.dart';
import 'package:date_format/date_format.dart';
import 'dart:math';

void main() => runApp(MyApp());
List stationList;

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

class SplashPage extends StatefulWidget {
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  Map<String, List> routeGroups = Map();

  Future<http.Response> getRouteGroups() {
    return http.get("http://data.lpp.si/routes/getRouteGroups");
  }

  Future<http.Response> getRoutes(routeNumber) {
    return http.get("http://data.lpp.si/routes/getRoutes?route_name=$routeNumber");
  }

  Future<http.Response> getAllStations() {
    return http.get("http://data.lpp.si/stations/getAllStations");
  }

  // if the app has no internet connection
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
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
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

  // filters out bad routes
  Map routeFilter(Map<String, List> routes) {
    // TODO: obvozi, unique n-routi
    routes.removeWhere((key, value) => value.isEmpty);

    for (String key in routes.keys) {
      List removables = [];

      routes[key].forEach((route) {
        try {
          if (route[1] < route[2]) {
            removables.add(route);
          }
        } catch(_) {
          removables.add(route);
        }
        if(route[3].contains("obvoz") || route[3].contains("GARAŽA")) {
          removables.add(route);
        }
      });

      routes[key].removeWhere((e) => removables.contains(e));
    }

    // find identical routes, TODO: join this with upper code
    Map<String, List> routeMap = Map();
    routes.forEach((routeGroupNumber, routeGroup) {
      routeGroup.forEach((route) {
        if (routeMap.keys.contains(route[0])) {
          routeMap[route[0]].add(route[1]);
        } else {
          routeMap[route[0]] = [route[1]];
        }
      });
    });
    // remove identical routes by descending id
    List removableRoutes = [];
    routeMap.forEach((routeName, routeIds) {
      if (routeIds.length > 1) {
        for (int routeId in routeIds.toList().sublist(1)) {
          routes.forEach((routeGroupNumber, routeGroup) {
            routeGroup.forEach((route) {
              if (route[1] == routeId) {
                removableRoutes.add(route);
              }
            });
          });
        }
      }
    });
    routes.forEach((k, v) {
      v.removeWhere((e) => removableRoutes.contains(e)); // removes identical routes
    });
    routes.removeWhere((k, v) => routes[k].isEmpty);
    return routes;
  }

  @override
  void initState() {
    super.initState();
    getAllStations().then((stations) {
      // once the stations get fetched, the duplicate station names need to be assigned a direction
      Map<String, List<int>> stationMap = Map();
      stationList = jsonDecode(stations.body)["data"];
      for (Map station in stationList) {
        if (stationMap.containsKey(station["name"])) {
          stationMap[station["name"]].add(int.parse(station["ref_id"]));
        } else {
          stationMap[station["name"]] = [int.parse(station["ref_id"])];
        }
      }
      stationMap.removeWhere((stationName, stationIds) => stationIds.length < 2);

      stationMap.forEach((stationName, stationIds) {
        int stationId = stationIds.reduce(min);
        Map stationToChange = (stationList.where((station) => station["ref_id"] == stationId.toString())).first;
        print(stationToChange);
      }
      );

      print(stationMap);
    });
    getData().then((data) {
      if (data == null) {
        _showErrDialog(context);
      } else {
        data.where((e) => jsonDecode(e.body)["data"].length != 0).forEach((e) =>
            jsonDecode(e.body)["data"].forEach((e) =>
                // TODO: change this into a map
                routeGroups[e["group_name"]].add([e["parent_name"], e["int_id"], e["opposite_route_int_id"], e["route_name"]])));
        routeGroups = routeFilter(routeGroups);
        SplayTreeMap routes = SplayTreeMap.from(routeGroups, (a, b) => collection.compareNatural(a, b));
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (BuildContext context) => RouteList(routes: routes)
        ));
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.green,
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

class RouteList extends StatelessWidget {
  RouteList({Key key, this.routes}) : super(key: key);

  final Map routes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Linije"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(
                  context: context,
                  delegate: StationSearch(stationList));
            },
          )
        ],
      ),
      body: ListView.builder(
          itemCount: routes.length,
          itemBuilder: (BuildContext context, int index) {
            String routeGroupNumber = routes.keys.toList()[index];
            List routeNames = routes[routeGroupNumber];
            return ExpansionTile(
              title: Text(routeGroupNumber),
              children: routeNames.map((route) => ListTile(
                leading: Container(
                  width: 30.0,
                  height: 30.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0),
                    color: Colors.green,
                  ),
                  child: Center(child: Text(getNumber(routeGroupNumber, route[0]), style: TextStyle(color: Colors.white), textAlign: TextAlign.center,)),
                ),
                title: Text(route[0]), // route title
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (BuildContext context) => Route(
                      routeId: route[1],
                      oppositeRouteId: route[2],
                      routeGroupNumber: routeGroupNumber,
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
  Route({Key key, this.routeId, this.oppositeRouteId, this.routeGroupNumber}) : super(key: key);

  final int routeId;
  final int oppositeRouteId;
  final String routeGroupNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Postaje"),
      ),
      body: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                child: Row(
                  children: <Widget>[
                    Expanded(child: RouteTitle(id: routeId)),
                    Expanded(child: RouteTitle(id: oppositeRouteId))
                  ],
                ),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(blurRadius: 10.0, spreadRadius: 1.0, offset: Offset(0.0, 2.0), color: Colors.black38)
                  ],
                  color: Colors.green[400]
                ),
              ),
              Expanded(
                  child: Row(
                    children: <Widget>[
                      Flexible(child: RouteDisplay(id: routeId, routeGroupNumber: routeGroupNumber)),
                      Flexible(child: RouteDisplay(id: oppositeRouteId, routeGroupNumber: routeGroupNumber))
                    ],
                  )
              )],
          ),
          VerticalDivider(thickness: 1.0, color: Colors.black38,)
        ],
      )
    );
  }
}

class RouteDisplay extends StatelessWidget {
  RouteDisplay({Key key, this.id, this.routeGroupNumber}) : super(key: key);
  final int id;
  final String routeGroupNumber;

  Future<http.Response> getStations(id) {
    return http.get("http://data.lpp.si/routes/getStationsOnRoute?route_int_id=$id");
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
                    try {
                      if (snapshot.hasData) {
                        List timetable = jsonDecode(snapshot.data[0].body)["data"];
                        //TODO: REMOVE OTHER ROUTES FROM LIVEARRIVALS!!!!
                        List liveArrivals = jsonDecode(snapshot.data[1].body)["data"];
                        liveArrivals.removeWhere((e) => e["route_number"].toString() != routeGroupNumber);

                        // TODO: set time to local
                        for (Map arrival in timetable) {
                          DateTime estimatedDate = DateTime.parse(arrival["arrival_time"]);
                          arrival["arrival_time"] = estimatedDate.toLocal()
                              .subtract(Duration(hours: 1)).toIso8601String();
                        }
                        if (liveArrivals.isNotEmpty) {
                          for (Map arrival in liveArrivals) {
                            List<List> diffs = List();
                            DateTime arrivalDate = DateTime.now().add(Duration(minutes: arrival["eta"]));
                            for (Map date in timetable) {
                              DateTime estimatedDate = DateTime.parse(
                                  date["arrival_time"]);
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
                        return Container(
                          width: double.maxFinite,
                          child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: timetable.length,
                              itemBuilder: (BuildContext context, int index) {
                                Duration dur;

                                // set dur, increase dur by 1 to accommodate for seconds difference
                                dur = DateTime.parse(timetable[index]["arrival_time"])
                                    .add(Duration(minutes: 1))
                                    .difference(DateTime.now());

                                return ListTile(
                                  leading: Text(formatDate(DateTime.parse(timetable[index]["arrival_time"]),
                                      [HH, ':', nn]), overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text("čez ${dur.inHours > 0 ? dur.inHours.toString() + " h in " : ""}"
                                      "${dur.inMinutes - dur.inHours * 60} min", overflow: TextOverflow.ellipsis,),
                                );
                              }
                          ),
                        );
                    } else {
                      return Center(child: CircularProgressIndicator());
                      }
                    } catch(err) {
                      print(err);
                      return Text("Prihodi za dano postajo niso bili najdeni. Linija morda danes ne vozi.");
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

class RouteTitle extends StatelessWidget {
  RouteTitle({Key key, this.id}) : super(key: key);
  final int id;

  Future<http.Response> getRouteDetails(id) {
    return http.get("http://data.lpp.si/routes/getRouteDetails?route_int_id=$id");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getRouteDetails(id),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          Map routeData = jsonDecode(snapshot.data.body)["data"];
          return Container(
            padding: EdgeInsets.all(8.0),
            child: Text(routeData["name"], style: TextStyle(fontSize: 20.0, color: Colors.white),),
            color: Colors.green[400],
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

String getNumber(String routeGroupNumber, String routeName) {
  RegExp reg = RegExp(r"^[A-Z] ");
  RegExpMatch matches = reg.firstMatch(routeName);
  return matches != null ? routeGroupNumber + matches.group(0) : routeGroupNumber;
}

class StationSearch extends SearchDelegate {
  StationSearch(this.stations);
  final List stations;

  Future<http.Response> getStationById() {
    return http.get("data.lpp.si/stations/getStationById");
}

  @override
  String get searchFieldLabel => "Napišite ime postaje";

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = "";
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = stations.where((station) => station["name"].toLowerCase()
        == query.toLowerCase());
    return ListView(
      children: results.map((station) => ListTile(
        title: Text(station.toString()),
      )).toList(),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = stations.where((station) => station["name"].toLowerCase().contains(
        query.toLowerCase()));
    return ListView(
      children: results.map((station) => ListTile(
        title: Text(station.toString()),
      )).toList(),
    );
  }
}