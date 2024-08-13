import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: SimpleProject(),
    );
  }
}

class SimpleProject extends StatelessWidget {
  const SimpleProject({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 10,
          title: Text(
            "Belal",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Color.fromARGB(255, 23, 1, 70),
          leading: IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.menu,
              size: 33,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.message,
                  size: 20,
                  color: Colors.white,
                )),
            IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.search,
                  size: 28,
                  color: Colors.white,
                ))
          ],
        ),
        body: SingleChildScrollView(scrollDirection: Axis.vertical,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 200,
            width: 412,
            decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
            child: Text(
              "Welcome To My App",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            alignment: Alignment.center,
        ),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(mainAxisAlignment: MainAxisAlignment.start,
            children: [
            Container(
              height: 100,
              width: 120,
              margin: EdgeInsets.fromLTRB(0, 70, 50, 70),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Belal",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              alignment: Alignment.center,
            ),
            Container(
              height: 100,
              width: 120,
              margin: EdgeInsets.fromLTRB(0, 70, 50, 70),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Tamer",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              alignment: Alignment.center,
            ),
             Container(
              height: 100,
              width: 120,
              margin: EdgeInsets.fromLTRB(0, 70, 50, 70),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Youssef",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              alignment: Alignment.center,
            ),
             Container(
              height: 100,
              width: 120,
              margin: EdgeInsets.fromLTRB(0, 70, 0, 70),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Hegab",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              alignment: Alignment.center,
          ),
          ])),
        Container(
            height: 200,
            width: 412,
            decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
            child: Text(
              "Welcome To My App",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            alignment: Alignment.center,
        ),])));
  }
}
