import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../recipe_card.dart';
import '../../network/recipe_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../colors.dart';
import '../widgets/custom_dropdown.dart';
import 'recipe_details.dart';
import '../../network/recipe_service.dart';

class RecipeList extends StatefulWidget {
  const RecipeList({Key? key}) : super(key: key);

  @override
  _RecipeListState createState() => _RecipeListState();
}

class _RecipeListState extends State<RecipeList> {
  static const String prefSearchKey = 'previousSearches';

  late TextEditingController searchTextController;
  final ScrollController _scrollController = ScrollController();

  List<APIHits> currentSearchList = [];
  int currentCount = 0;
  int currentStartPosition = 0;
  int currentEndPosition = 20;
  int pageCount = 20;
  bool hasMore = false;
  bool loading = false;
  bool inErrorState = false;
  List<String> previousSearches = <String>[];

  @override
  void initState() {
    super.initState();
    getPreviousSearches();
    searchTextController = TextEditingController(text: '');
    _scrollController
      ..addListener(() {
        final triggerFetchMoreSize =
            0.7 * _scrollController.position.maxScrollExtent;

        if (_scrollController.position.pixels > triggerFetchMoreSize) {
          if (hasMore &&
              currentEndPosition < currentCount &&
              !loading &&
              !inErrorState) {
            setState(() {
              loading = true;
              currentStartPosition = currentEndPosition;
              currentEndPosition =
                  min(currentStartPosition + pageCount, currentCount);
            });
          }
        }
      });
  }

  ///The method is asynchronous and returns a Future. It takes a query and the
  ///start and the end positions of the recipe data,
  /// which from and to represent, respectively.
  Future<APIRecipeQuery> getRecipeData(String query, int from, int to) async {
    /// To store the result from RecipeService().getRecipes() after it finishes
    /// it uses the from and to fields from step 1
    final recipeJson = await RecipeService().getRecipes(query, from, to);

    /// The variable [recipeMap] uses Dart's json.decode() to decode the string
    /// into a map of type Map>String, dynamic>
    final recipeMap = json.decode(recipeJson);

    ///
    return APIRecipeQuery.fromJson(recipeMap);
  }

  @override
  void dispose() {
    searchTextController.dispose();
    super.dispose();
  }

  void savePreviousSearches() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(prefSearchKey, previousSearches);
  }

  void getPreviousSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(prefSearchKey)) {
      final searches = prefs.getStringList(prefSearchKey);
      if (searches != null) {
        previousSearches = searches;
      } else {
        previousSearches = <String>[];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _buildSearchCard(),
            _buildRecipeLoader(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 4,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0))),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                startSearch(searchTextController.text);
                final currentFocus = FocusScope.of(context);
                if (!currentFocus.hasPrimaryFocus) {
                  currentFocus.unfocus();
                }
              },
            ),
            const SizedBox(
              width: 6.0,
            ),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                      child: TextField(
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: 'Search'),
                    autofocus: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      if (!previousSearches.contains(value)) {
                        previousSearches.add(value);
                        savePreviousSearches();
                      }
                    },
                    controller: searchTextController,
                  )),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: lightGrey,
                    ),
                    onSelected: (String value) {
                      searchTextController.text = value;
                      startSearch(searchTextController.text);
                    },
                    itemBuilder: (BuildContext context) {
                      return previousSearches
                          .map<CustomDropdownMenuItem<String>>((String value) {
                        return CustomDropdownMenuItem<String>(
                          text: value,
                          value: value,
                          callback: () {
                            setState(() {
                              previousSearches.remove(value);
                              Navigator.pop(context);
                            });
                          },
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void startSearch(String value) {
    setState(() {
      currentSearchList.clear();
      currentCount = 0;
      currentEndPosition = pageCount;
      currentStartPosition = 0;
      hasMore = true;
      value = value.trim();
      if (!previousSearches.contains(value)) {
        previousSearches.add(value);
        savePreviousSearches();
      }
    });
  }

  Widget _buildRecipeLoader(BuildContext context) {
    if (searchTextController.text.length < 3) {
      return Container();
    }
    return FutureBuilder<APIRecipeQuery>(
      future: getRecipeData(searchTextController.text.trim(),
          currentStartPosition, currentEndPosition),

      /// builder it requires, it returns widget
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
                textScaleFactor: 1.3,
              ),
            );
          }

          /// If there’s no error, process the query results and
          ///  add query.hits to currentSearchList.
          loading = false;
          final query = snapshot.data;
          inErrorState = false;
          if (query != null) {
            currentCount = query.count;
            hasMore = query.more;
            currentSearchList.addAll(query.hits);
            if (query.to < currentEndPosition) {
              currentEndPosition = query.to;
            }
          }
          return _buildRecipeList(context, currentSearchList);
          // check that [snapshot.connectionState] is not done
        } else {
          // if the user current count is 0, then show a progress indicator
          if (currentCount == 0) {
            /// Shows a loading indicator while waiting for the recipes
            return const Center(child: CircularProgressIndicator());
          } else {
            /// Otherwise it just shows the current list
            return _buildRecipeList(context, currentSearchList);
          }
        }
      },
    );
  }

  Widget _buildRecipeList(BuildContext recipeListContext, List<APIHits> hits) {
    /// MediaQuery to get the device's screen size, then it sets a fixed item
    // height and create two columns of cards whose width is half device's width
    final size = MediaQuery.of(context).size;
    const itemHeight = 310;
    final itemWidth = size.width / 2;

    /// return a widget that's flexisble in witdh and height
    return Flexible(
      ///[GridView] is similar to [ListView], but it allows for some interesting
      /// combinations of [row]s and [column]s.
      /// In this case we use [GridView.Builder()] because we know the number
      /// of  items and we'll use an [itemBuilder]
      child: GridView.builder(
        /// This delegate has two [column]s and sets the aspect ratio
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: (itemWidth / itemHeight),
        ),

        /// we use scrol controller, created in [initState()]
        /// to detect when scrolling gets to about 70% from the bottom
        controller: _scrollController,

        /// dynamic itemcount of the grid's item depends on the number of items
        /// in the [hits] list
        itemCount: hits.length,

        /// [itemBuilder] uses the [_buildRecipeCard()] to return a card for
        /// each recipe.
        ///  [_buildRecipeCard()] retrieves the recipe from the hits list
        /// by using [hits[index].recipe]
        itemBuilder: (BuildContext context, int index) {
          return _buildRecipeCard(recipeListContext, hits, index);
        },
      ),
    );
  }

  Widget _buildRecipeCard(
      BuildContext topLevelContext, List<APIHits> hits, int index) {
    final recipe = hits[index].recipe;
    return GestureDetector(
      onTap: () {
        Navigator.push(topLevelContext, MaterialPageRoute(
          builder: (context) {
            return const RecipeDetails();
          },
        ));
      },
      child: recipeCard(recipe),
    );
  }
}
