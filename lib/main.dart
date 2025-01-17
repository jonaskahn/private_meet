import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:private_meet/enum/actions.dart';
import 'package:private_meet/pages/recognize_page.dart';
import 'package:private_meet/pages/setting_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MDO Meeting",
      theme: ThemeData(primaryColor: Colors.amber),
      home: HomePage(),
      routes: {
        '/analysis/': (context) => AudioRecorderScreen(),
        '/settings/': (context) => SettingScreen()
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Meet Locally",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepOrange,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          actions: [
            PopupMenuButton<HomeAction>(itemBuilder: (context) {
              return [
                const PopupMenuItem<HomeAction>(
                    value: HomeAction.setting, child: Text("Setting"))
              ];
            }, onSelected: (value) async {
              switch (value) {
                case HomeAction.setting:
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => SettingScreen()));
                  break;
              }
            })
          ],
        ),
        body: IntroductionScreen(
          pages: [
            PageViewModel(
              title: "MDO Meeting (Meet Locally™ - alpha)",
              bodyWidget: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                // Set container height to 80% of screen height
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  // Space between elements
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        // Makes the text scrollable if needed
                        child: Column(
                          children: [
                            Text(
                              """Transform your meetings with our revolutionary app that puts privacy first. Running entirely on your device, our app leverages cutting-edge local AI to transcribe conversations in real-time and provide intelligent insights without sending your sensitive data to the cloud. Through advanced voice recognition and language models, it automatically generates comprehensive meeting summaries, analyzes discussion points, and creates polished reports – all while keeping your conversations completely private. Perfect for businesses, teams, and professionals who value both productivity and confidentiality.""",
                              style: TextStyle(
                                  fontSize: 18,
                                  decorationStyle: TextDecorationStyle.dotted),
                            ),
                            SizedBox(height: 20),
                            Text("Copyright: BSSD Vietnam")
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
          showSkipButton: false,
          showNextButton: false,
          showDoneButton: true,
          done: const Text(
            "Ack",
            style: TextStyle(color: Colors.white),
          ),
          baseBtnStyle: TextButton.styleFrom(
              backgroundColor: Colors.deepOrangeAccent,
              textStyle: TextStyle(fontSize: 18, color: Colors.white)),
          onDone: () {
            Navigator.pushNamed(context, "/analysis/");
          },
        ));
  }
}
