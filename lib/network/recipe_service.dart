import 'package:http/http.dart';

const String apiKey = '66c984d3e0cc4dcc0ef38bdac2783b9a';
const String apiId = '78815d90';
const String apiUrl = 'https://api.edamam.com/search';

class RecipeService {
  Future getData(String url) async {
    print('Calling uri: $url');
    final response = await get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      print(response.statusCode);
    }
  }

  /// we use Future<dynamic> that we don't know which data type it will return
  /// or when it will finish.
  /// The [async] signals that this methods runs asynchronously
  Future<dynamic> getRecipes(String query, int from, int to) async {
    /// [final] to create non changeable variable, we use wait to tell the app
    /// to wait till [getData] returns its result
    final recipeData = await getData(
        '$apiUrl?app_id=$apiId&app_key=$apiKey&q=$query&from=$from&to=$to');

    /// Returs the data retrieved from the API to [getData()]
    print(recipeData);
    return recipeData;
  }
}
