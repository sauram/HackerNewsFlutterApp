import 'dart:async';
import 'dart:collection';
import 'article.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

enum StoriesType{
  topStories,
  newStories,
}

class HackerNewsBloc{
  HashMap<int, Article> _cachedArticles;
  var _articles = <Article> [];
  // static List <int> _topIds = [ 27614381, 27606099, 27613217, 27605052, 27606347];
  // static List <int> _newIds = [ 27579759, 27606008, 27611433, 27612728, 27613536];

  // ignore: close_sinks
  final _storiesTypeController = StreamController<StoriesType>();
  Sink<StoriesType> get storiesType => _storiesTypeController.sink;

  Stream<bool> get isLoading => _isLoadingSubject.stream;
  // ignore: close_sinks
  final _isLoadingSubject = BehaviorSubject<bool>();

  // ignore: close_sinks
  final _articlesSubject = BehaviorSubject<UnmodifiableListView<Article>>();
  HackerNewsBloc(){
    _cachedArticles = HashMap<int, Article>();
    _initializeArticles();
    _storiesTypeController.stream.listen((storiesType) async{
        _getArticlesAndUpdate(await _getIds(storiesType));
    });
  }
  Future<void> _initializeArticles() async{
    _getArticlesAndUpdate(await _getIds(StoriesType.topStories));
  }
  _getArticlesAndUpdate(List<int> Ids) async{
    _isLoadingSubject.add(true);
    await _updateArticles(Ids);
    _articlesSubject.add(UnmodifiableListView(_articles));
    _isLoadingSubject.add(false);
  }

  void close(){
    _storiesTypeController.close();
  }

  Stream<UnmodifiableListView<Article>> get articles => _articlesSubject.stream;

  Future<Null> _updateArticles(List<int> _ids) async{
    final futureArticles = _ids.map((id) =>_getArticle(id));
    final articles = await Future.wait(futureArticles);
    _articles =articles;
  }
  Future<List<int>> _getIds (StoriesType type) async{
    final partUrl = type==StoriesType.topStories? 'top':'new';
    final url = 'https://hacker-news.firebaseio.com/v0/${partUrl}stories.json';
    final response = await http.get(url);
    if(response.statusCode==200) return parseTopStories(response.body).take(10).toList();
    throw HackerNewsApiError("No response of Ids");
  }
  Future<Article> _getArticle(int id) async {
    if (!_cachedArticles.containsKey(id)) {
      final storyUrl = 'https://hacker-news.firebaseio.com/v0/item/$id.json';
      final storyRes = await http.get(storyUrl);
      if (storyRes.statusCode == 200)
        _cachedArticles[id] = parseArticle(storyRes.body);
      else throw HackerNewsApiError("No response");
    }
    return _cachedArticles[id];
  }
}

class HackerNewsApiError{
  final String message;
  HackerNewsApiError(this.message);
}