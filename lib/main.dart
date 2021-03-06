import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:html/dom.dart' show Document;

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
        fontFamily: "WorkSans",
        accentColor: Colors.white
      ),
      home: SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  Map<String, List> routesMap = Map();
  List stationsList = List();
  WebViewController controller;

  String getNumber(String routeGroupNumber, String routeName) {
    RegExp reg = RegExp(r"^[0-9]*[A-Z]* ");
    RegExpMatch matches = reg.firstMatch(routeName);
    return matches != null ? (routeGroupNumber + matches.group(0)).trimRight() : routeGroupNumber;
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
                Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: MaterialButton(
                      color: Colors.green,
                      child: Text("Poskusi znova", style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (BuildContext context) => SplashPage()
                        ));
                      }),
                )
              ],
            ),
          );
        }
    );
  }

  void getData(WebViewController controller) async {
    await controller.evaluateJavascript("document.getElementsByClassName('switch type--2')[0].dispatchEvent(new Event('click'))");
    String stationsHtml = await controller.evaluateJavascript("document.getElementById('station-select-list').innerHTML");
    String routesHtml = await controller.evaluateJavascript("document.getElementById('line-select-list').innerHTML");

    Document stations = htmlParser.parse(stationsHtml.replaceAll(r"\u003C", "<").replaceAll(r"\n", "").replaceAll("\\\"", "'"));
    Document routes = htmlParser.parse(routesHtml.replaceAll(r"\u003C", "<").replaceAll(r"\n", "").replaceAll("\\\"", "'"));

    print("ROUTES IS ${routes.body.children}");

    if (routes.body.children.length != 0) {
      for (var route in routes.body.children.sublist(1)) {
        Map routeMap = route.attributes;
        String num = getNumber("", routeMap['value']);
        if (routesMap.containsKey(num)) {
          routesMap[num].add(routeMap);
        } else {
          routesMap[num] = [routeMap];
        }
      }
    } else {
      _showErrDialog(context);
    }

    Map<String, List> stationsMap = Map();
    for (var station in stations.body.children) {
      RegExp reg = RegExp(r"\(\d*\)");
      Map stationMap = station.attributes;
      stationMap["center"] = "";
      RegExpMatch matches = reg.firstMatch(stationMap["value"]);
      stationMap["value"] = stationMap["value"].replaceAll(matches.group(0), "");
      if (stationsMap.containsKey(stationMap["value"])) {
        stationsMap[stationMap["value"]].add(stationMap["data-id"]);
      } else {
        stationsMap[stationMap["value"]] = [stationMap["data-id"]];
      }
      stationsList.add(stationMap);
    }

    stationsMap.forEach((stationName, stationIds) {
      int stationId = stationIds.map((e) => int.parse(e)).reduce(min);
      Map stationToChange = (stationsList.where((station) => station["data-id"] == stationId.toString())).first;
      print(stationToChange);
      stationsList[stationsList.indexOf(stationToChange)]["center"] = "V center";
    });

    print(routes.body.children[1].attributes.toString());
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (BuildContext context) => RouteList(
          routes: routesMap,
          stations: stationsList,
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
          children: <Widget>[
            WebView(
              initialUrl: "https://www.lpp.si",
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController c) {
                controller = c;
              },
              onPageFinished: (_) {
                getData(controller);
              },
            ),
            Container(
              color: Colors.green,
              width: double.infinity,
              height: double.infinity,
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset("assets/bus.png"),
                  CircularProgressIndicator(),
                ],
              ),
            )
          ],
        )
    );
  }
}

class RouteList extends StatelessWidget {
  RouteList({Key key, this.routes, this.stations}) : super(key: key);

  final Map<String, List> routes;
  final List stations;

  String formatString(String routeString) {
    return routeString.split("-").last.replaceAll(")", "");
  }

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
                    delegate: StationSearch(stations));
              },
            )
          ],
        ),
        body: ListView.separated(
            itemCount: routes.length,
            separatorBuilder: (BuildContext context, int index) => Divider(color: Colors.black26, height: 0.0),
            itemBuilder: (BuildContext context, int index) {
              String routeName = routes.keys.toList()[index];
              Color currColor = Colors.green;
              return ExpansionTile(
                backgroundColor: currColor,
                title: Text(routeName),
                children: routes[routeName].map((route) => Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: InkWell(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text("SMER: "),
                              Text(formatString(route["value"]))
                            ],
                          ),
                        ),
                        onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (BuildContext context) => Route(
                                  routeId: route["data-id"],
                                  routeName: route["value"],
                                )
                            ));
                        },
                      ),
                    ),
                  ),
                )).toList(),
              );
            }
        )
    );
  }
}

class Route extends StatelessWidget {
  Route({Key key, this.routeId, this.routeName}) : super(key: key);

  final String routeName;
  final String routeId;

  Future<http.Response> getRoute(id) {
    return http.get("https://www.lpp.si/lpp/ajax/2/$id");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Postaje"),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (BuildContext context) => Route(routeId: routeId, routeName: routeName,)
          ));
        },
        child: FutureBuilder(
          future: getRoute(routeId),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.hasData) {
              List data = jsonDecode(snapshot.data.body);
              return ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (BuildContext context, int index) => Divider(color: Colors.black26),
                  itemBuilder: (BuildContext context, int index) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        Container(
                          margin: EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5.0),
                              border: Border.all(color: Colors.black54)
                          ),
                          child: Padding(padding: EdgeInsets.all(6.0), child: Text("${data[index]["name"]}", style: TextStyle(
                              fontSize: 16.0
                          ))),
                        ),
                        Expanded(
                          child: Wrap(
                            children: data[index]["arrivals"].map<Widget>((arrival) => Card(
                              color: Colors.green,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(arrival["time"], style: TextStyle(fontSize: 16.0, color: Colors.white)),
                              ),
                            )).toList(),
                          ),
                        )
                      ],
                    ),
                  )
              );
            } else {
              return Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green),)
              );
            }
          },
        ),
      )
    );
  }
}

class StationSearch extends SearchDelegate {
  StationSearch(this.stations);
  final List stations;

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
    final results = stations.where((station) => station["value"].toLowerCase()
        == query.toLowerCase());
    return ListView(
      children: results.map((station) => ListTile(
        title: Text(station["value"]),
        trailing: Text(station["data-id"].toString(), style: TextStyle(color: Colors.grey),),
        subtitle: Text(station["center"]),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (BuildContext context) => StationPage(
              station: station,
            ))
          );
        },
      )).toList(),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = stations.where((station) => station["value"].toLowerCase().contains(
        query.toLowerCase()));
    return ListView(
      children: results.map((station) => ListTile(
        title: Text(station["value"]),
        trailing: Text(station["data-id"].toString(), style: TextStyle(color: Colors.grey),),
        subtitle: Text(station["center"]),
        onTap: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (BuildContext context) => StationPage(
                station: station,
              ))
          );
        },
      )).toList(),
    );
  }
}

class StationPage extends StatelessWidget {
  StationPage({Key key, this.station}): super(key: key);
  final Map station;

  Future<http.Response> getArrivalsOnStation(stationId) {
    return http.get("https://www.lpp.si/lpp/ajax/1/$stationId");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(station["value"]),
      ),
      body: FutureBuilder(
        future: getArrivalsOnStation(station["data-id"].toString()),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            List arrivals = jsonDecode(snapshot.data.body);
            Map<String, List> arrivalsMap = Map();
            arrivals.forEach((arrivalGroup) {
              (arrivalGroup as List).forEach((arrival) {
                if (arrivalsMap.keys.contains(arrival["key"].toString())) {
                  arrivalsMap[arrival["key"].toString()].add(arrival["time"]);
                } else {
                  arrivalsMap[arrival["key"].toString()] = [arrival["time"]];
                }
              });
            });
            return arrivals.isNotEmpty ? RefreshIndicator(
                onRefresh: () {
                  return Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (BuildContext context) => StationPage(station: station)
                  ));
                },
                child: ListView.separated(
              itemCount: arrivalsMap.length,
              itemBuilder: (BuildContext context, int index) => Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: 30.0,
                      height: 30.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5.0),
                        border: Border.all(color: Colors.black54)
                      ),
                      child: Center(child: Text(arrivalsMap.keys.toList()[index], textAlign: TextAlign.center)),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      children: arrivalsMap.values.toList()[index].map<Widget>((arrival) => Card(
                        color: Colors.green,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text(arrival.toString(), style: TextStyle(fontSize: 16.0, color: Colors.white)),
                        ),
                      )).toList(),
                    ),
                  )
                ],
              ),
              separatorBuilder: (BuildContext context, int index) => Divider(color: Colors.black26),
            )) : Center(child: Text("Prihodi za dano postajo niso bili najdeni. Linija morda danes ne vozi.",
              textAlign: TextAlign.center));
          } else {
            return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)));
          }
        },
      ),
    );
  }
}