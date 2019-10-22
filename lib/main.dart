import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:beautifulsoup/beautifulsoup.dart';

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
  List links = List();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: <Widget>[
            RaisedButton(
                child: Text("get lpp site html"),
                onPressed: () {
                  http.read(url + "javni-prevoz/vozni-redi").then((data) {
                    setState(() {
                      html = data;
                      var soup = Beautifulsoup(html);
                      Iterable l = Iterable.empty();

                      l = soup.find_all("tr").map((e) => e.children).where((e) => e.length == 2);
                      for (List i in l) {
                        links.add([i.first.text, i.last.text, i.last.children.first.attributes["href"]]);
                      }

                    });
                  });
                }),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: links.length,
                itemBuilder: (BuildContext context, int index) => ListTile(
                  leading: Text(links[index][0]),
                  title: Text(links[index][1]),
                  onTap: () {
                    print(links[index][2]);
                    Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (BuildContext context) => Postaje(linija: links[index][2])
                        )
                    );
                  },
                ),
                separatorBuilder: (BuildContext context, int index) => Divider(height: 0.0, color: Colors.black54),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class Postaje extends StatefulWidget {
  Postaje({Key key, this.linija}) : super(key: key);

  final String linija;

  @override
  PostajeState createState() => PostajeState();
}

class PostajeState extends State<Postaje> {
  String html = "";
  List linija1 = List();
  List linija2 = List();

  @override
  void initState() {
    super.initState();
    http.read(url + widget.linija).then((data) {
      setState(() {
        html = data;
        var soup = Beautifulsoup(html);
        Iterable divs = Iterable.empty();

        divs = soup.find_all("div").where((e) => e.attributes.containsValue("col-md-6")).map((e) => e.children).toList().sublist(0, 2);

        linija1 = divs.first;
        linija2 = divs.last;

      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
                itemCount: linija1.length,
                itemBuilder: (BuildContext context, int index) => ListTile(
                  title: Text(linija1[index].text),
                ),
            ),
          ),
          Expanded(
              child: ListView.builder(
                  itemCount: linija2.length,
                  itemBuilder: (BuildContext context, int index) => ListTile(
                    title: Text(linija2[index].text),
                  ),
              )
          )
        ],
      )
    );
  }
}