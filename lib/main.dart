import 'dart:collection';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hacker_news/src/hn_bloc.dart';
import 'src/article.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';


void main() {
  final hn_bloc = HackerNewsBloc();
  runApp(MyApp(bloc : hn_bloc));
}

class MyApp extends StatelessWidget {
  final HackerNewsBloc bloc;
  MyApp({
    Key key,
    this.bloc,
}) : super(key: key);
  static const primaryColor = Colors.white;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Application',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: primaryColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        canvasColor: Colors.black,
        textTheme: Theme.of(context)
          .textTheme
          .copyWith(caption: TextStyle(color: Colors.white70))
      ),
      home: MyHomePage(title: 'Hacker News', bloc: bloc),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final HackerNewsBloc bloc;
  MyHomePage({Key key, this.title, this.bloc}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    int _currentIndex = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: LoadingInfo(bloc: widget.bloc),
        elevation: 0.0,
        actions: [
          Builder(
              builder: (BuildContext context)=>IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () async {
                    final result = await showSearch(context: context,
                        delegate: ArticleSearch(
                            widget.bloc.articles
                        ));
                    //Scaffold.of(context).showSnackBar(SnackBar(content: Text(result.title),));
                    if(result!=null){
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => HackerNewsWebPage(result.url),
                      ));
                    }
                  }
              ),
            ),
        ],
      ),
      body: StreamBuilder<UnmodifiableListView<Article>>(
        stream: widget.bloc.articles,
        initialData: UnmodifiableListView<Article>([]),
        builder: (context, snapshot) => ListView(
          children: snapshot.data.map(_buildItem).toList(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.arrow_drop_up),
              label:"Top Stories",
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.new_releases),
              label: "New Stories",
          ),
        ],
        onTap: (index){
          if(index==0){
            widget.bloc.storiesType.add(StoriesType.topStories);
          }else{
            widget.bloc.storiesType.add(StoriesType.newStories);
          }
          setState(() {
            _currentIndex=index;
          });
        },
      ),
    );
  }

  Widget _buildItem(Article article) {
    return Padding(
      key : Key(article.title),
      padding: const EdgeInsets.symmetric(vertical : 12.0, horizontal: 4.0),
      child: ExpansionTile(
        title: Text(article.title ?? '[null]', style: TextStyle(fontSize: 18),),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Text('${article.descendants} comments'),
                      SizedBox(width: 16.0,),
                      IconButton(
                          icon: Icon(Icons.launch),
                          onPressed: () async {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (context) => HackerNewsWebPage(article.url),
                            ));
                          }
                      )
                    ]
                ),
                Container(
                  height: 200,
                  child: WebView(
                    initialUrl : article.url,
                    javascriptMode: JavascriptMode.unrestricted,
                    gestureRecognizers: Set()..add(
                      Factory<VerticalDragGestureRecognizer>(
                          ()=>VerticalDragGestureRecognizer())
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}

class LoadingInfo extends StatefulWidget {
  final HackerNewsBloc bloc;

  const LoadingInfo({Key key, this.bloc}) : super(key: key);

  createState() => LoadingInfoState();
}
class LoadingInfoState extends State<LoadingInfo> with TickerProviderStateMixin{
  AnimationController _controller ;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.bloc.isLoading,
      builder: (BuildContext context, AsyncSnapshot<bool >snapshot){
        if(snapshot.hasData && snapshot.data) {
          _controller.forward().then((_){
            _controller.reverse();
          });
          return FadeTransition(
            child: Icon(FontAwesomeIcons.hackerNewsSquare),
            opacity: Tween(begin:0.5,end: 1.0).animate(
              CurvedAnimation(curve: Curves.easeIn, parent: _controller)
            ),
          );
        }
        return Container();
      },
    );
  }
}

class ArticleSearch extends SearchDelegate<Article>{
  final Stream<UnmodifiableListView<Article>> articles;
  ArticleSearch(this.articles);
  @override
  List<Widget> buildActions(BuildContext context) {
    return[
      IconButton(
          icon: Icon(Icons.clear),
          onPressed: (){
            query = '';
          })
    ];
    throw UnimplementedError();
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: (){
          close(context,null);
        });
    throw UnimplementedError();
  }

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<UnmodifiableListView<Article>>(
      stream: articles,
      builder: (BuildContext context, AsyncSnapshot<UnmodifiableListView<Article>>snapshot){
        if(!snapshot.hasData){
          return Center(child: Text("No Data"));
        }
        final result = snapshot.data.where((a)=>a.title.toLowerCase().contains(query));
        return ListView(
          children: result.map<ListTile>((a) =>ListTile(
            title: Text(a.title, style: Theme.of(context).textTheme.headline6,),
            leading: Icon(Icons.book),
            onTap: (){
              close(context,a);
            },
          )).toList(),
        );
      },
    );
    throw UnimplementedError();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return StreamBuilder<UnmodifiableListView<Article>>(
      stream: articles,
      builder: (BuildContext context, AsyncSnapshot<UnmodifiableListView<Article>>snapshot){
        if(!snapshot.hasData){
          return Center(child: Text("No Data"));
        }
        final result = snapshot.data.where((a)=>a.title.toLowerCase().contains(query));
        return ListView(
          children: result.map<ListTile>((a) =>ListTile(
            title: Text(a.title, style: TextStyle(fontSize: 16 ),),
            onTap: (){
              close(context,a);
            },
          )).toList(),
        );
      },
    );
    throw UnimplementedError();
  }

}

class HackerNewsWebPage extends StatelessWidget {
  HackerNewsWebPage( this.url);
  final String url;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Full Article"),),
      body: WebView(
        initialUrl: url,
        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}

