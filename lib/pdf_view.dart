import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:native_pdf_renderer/native_pdf_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfViewPage extends StatefulWidget {
  PdfViewPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _PdfViewPageState createState() => _PdfViewPageState();
}

class _PdfViewPageState extends State<PdfViewPage> {
  String displayText = "ファイルを選択";
  String storedPath = '';

  _PdfViewPageState() {
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        storedPath = prefs.getString('my_path') ?? '';
      });
    });
  }


  Future<PdfDocument> _getFileByPicker() async {
    FilePickerResult result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('my_path', result.files.single.path);
      setState(() {
        storedPath = result.files.single.path;
      });
      return _getFileByPath(result.files.single.path);
    }
    throw Exception("ファイルが開けませんでした");
  }

  Future<PdfDocument> _getFileByPath(String path) async {
    if (path != "") {
      final document = await PdfDocument.openFile(path);
      return document;
    }
    throw Exception("ファイルが開けませんでした");
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              onPressed: () async {
                _getFileByPicker().then((pdf) {
                  debugPrint(pdf.toString());
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FullPdfViewerScreen(pdf)),
                  );
                });
              },
              child: Text(displayText),
            ),
            Text(storedPath),
            RaisedButton(
              onPressed: () async {
                _getFileByPath(storedPath).then((pdf) {
                  debugPrint(pdf.toString());
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FullPdfViewerScreen(pdf)),
                  );
                });
              },
              child: Text("前回開いていたファイルを再表示"),
            ),
          ],
        ),
      ),
    );
  }
}

class FullPdfViewerScreen extends StatefulWidget {
  final PdfDocument pdf;

  FullPdfViewerScreen(this.pdf);

  @override
  _FullPdfViewerScreenState createState() => _FullPdfViewerScreenState(pdf);
}

class _FullPdfViewerScreenState extends State<FullPdfViewerScreen> {
  final PdfDocument pdf;
  int _lastPage;
  int _counter = 1;
  bool isLoading = false;

  _FullPdfViewerScreenState(this.pdf) {
    _lastPage = pdf.pagesCount;
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
          _counter = prefs.getInt("last_view:${pdf.sourceName}") ?? 1;
      });
      get();
    });
  }

  void _pageNumberStore() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt("last_view:${pdf.sourceName}", _counter);
    });
  }

  Image image;

  String _nextPage() {
    if (isLoading) {
      return "loading...";
    }
    if (_counter == _lastPage) {
      return "最終ページです";
    }

    setState(() {
      _counter++;
      _pageNumberStore();
    });
    get();
    return "";
  }

  String _beforePage() {
    if (isLoading) {
      return "loading...";
    }
    if (_counter == 1) {
      return "最初のページです";
    }

    setState(() {
      _counter--;
      _pageNumberStore();
    });
    get();

    return "";
  }

  void get() async {
    this.isLoading = true;

    final page = await this.pdf.getPage(_counter);
    final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageFormat.WEBP);
    await page.close();
    setState(() {
      this.image = Image(image: MemoryImage(pageImage.bytes));
      this.isLoading = false;
    });
  }

  double gesturePos = 0.0;

  void _changeSlider(double e) => setState(() {
        _counter = e.toInt();
      });

  void _endSlider(double e) => setState(() {
        _counter = e.toInt();
        get();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Builder(
      builder: (BuildContext context) {
        return Scaffold(
          body: Center(
            child: new Stack(children: <Widget>[
              Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  verticalDirection: VerticalDirection.down,
                  children: <Widget>[
                    Container(
                        color: Colors.blue.withOpacity(0.0),
                      height: (30),
                      width: (10),
                    ),
                    if(image != null) image,
                    Container(
                        width: (MediaQuery.of(context).size.width * 0.8),
                        margin: EdgeInsets.only(bottom: 20),
                        child: Slider(
                          min: 1,
                          max: _lastPage.toDouble(),
                          value: _counter.toDouble(),
                          activeColor: Colors.black45,
                          inactiveColor: Colors.black12,
                          divisions: _lastPage,
                          onChanged: _changeSlider,
                          onChangeEnd: _endSlider,
                          label: _counter.toString(),
                        )),
                  ]),
            Positioned(
                left: 0.0,
                top: 0.0,
                right: 0.0,
                bottom: 80.0,
                child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() => this.gesturePos = details.delta.dx);
                },
                onHorizontalDragEnd: (details) {
                  if (this.gesturePos < 0) {
                    _nextPage();
                  } else {
                    _beforePage();
                  }
                },
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      GestureDetector(
                          onTap: () {
                            _beforePage();
                          },
                          child: Container(
                              color: Colors.red.withOpacity(0.0),
                              width: (MediaQuery.of(context).size.width / 3))),
                      GestureDetector(
                        onTap: () {
                          _nextPage();
                        },
                        child: Container(
                            color: Colors.green.withOpacity(0.0),
                            width: (MediaQuery.of(context).size.width / 3)),
                      )
                    ]),
              )
            )
            ], fit: StackFit.expand),
          ),
        );
      },
    ));
  }
}
