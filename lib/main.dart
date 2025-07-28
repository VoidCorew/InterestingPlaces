import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(InterestingPlacesApp());
}

class InterestingPlacesApp extends StatelessWidget {
  const InterestingPlacesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  double radiusKm = 0.0;

  final TextStyle font = TextStyle(fontFamily: 'Nunito');

  final FocusNode _cityFocusNode = FocusNode();
  final FocusNode _countryFocusNode = FocusNode();

  static const List<String> _cities = <String>[
    'Köln',
    'Aachen',
    'Bonn',
    'München',
    'Mönchengladbach',
    'Hamburg',
    'Frankfurt am Main',
    'Dresden',
    'Nürnberg',
    'Stuttgart',
    'Augsburg',
    'Trier',
    'Münster',
    'Weimar',
    'Augsburg',
    'Leipzig',
    'Bremen',
    'Lübeck',
    'Rostock',
    'Regensburg',
    'Berlin',
    'Heidelberg',
  ];

  static const List<String> _countries = <String>['Germany'];

  static const String apiKey =
      '5ae2e3f221c38a28845f05b6c6e38808531d76fb6669752be8a12365';

  List<dynamic> places = [];
  bool isLoading = false;
  String? error;

  Future<void> fetchCityCoordinates(String city) async {
    setState(() {
      isLoading = true;
      error = null;
      places = [];
    });

    try {
      final encodedCity = Uri.encodeComponent('$city, Germany');
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedCity&format=json&limit=1&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'InterestingPlacesApp/1.0 (amcxz6092@gmail.com)',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final place = data[0];
          // final lat = place['lat'];
          // final lon = place['lon'];
          final lat = double.tryParse(place['lat'] ?? '');
          final lon = double.tryParse(place['lon'] ?? '');
          debugPrint('Город $city найден: $lat, $lon');
          if (lat != null && lon != null) {
            debugPrint('Город $city найден: $lat, $lon');
            await fetchPlacesNearby(
              lat,
              lon,
              (radiusKm * 1000).toInt(),
              apiKey,
            );
          } else {
            setState(() {
              error = 'Не удалось получить координаты города.';
            });
          }
        } else {
          setState(() {
            error = 'Город не найден';
          });
        }
      } else {
        setState(() {
          error = 'Ошибка запроса: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Ошибка: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchPlacesNearby(
    double lat,
    double lon,
    int radiusMeters,
    String apiKey,
  ) async {
    final url = Uri.parse(
      'https://api.opentripmap.com/0.1/en/places/radius?radius=$radiusMeters&lon=$lon&lat=$lat&limit=20&apikey=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> features = data['features'] ?? [];

      setState(() {
        places = features;
      });
    } else {
      setState(() {
        error = 'Ошибка при загрузке мест: ${response.statusCode}';
      });
    }
  }

  Future<void> openInMaps(double lat, double lon) async {
    // final googleMapsUrl = Uri.encodeFull(
    //   'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    // );
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );
    // if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
    //   await launchUrl(Uri.parse(googleMapsUrl));
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Не удалось открыть карту', style: font)),
    //   );
    // }
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось открыть карту')));
    }
  }

  void copyCoordinates(double lat, double lon) {
    final text = '$lat, $lon';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Координаты скопированы', style: font)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Главная', style: font)),
      body: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Autocomplete<String>(
                // key: const ValueKey('autocomplete-city'),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return _cities.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  _cityController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          label: Text('Город', style: font),
                          hint: Text('Введите название города', style: font),
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
              ),
              const SizedBox(height: 10),
              Autocomplete<String>(
                // key: const ValueKey('autocomplete-country'),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return _countries.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  _countryController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          label: Text('Страна', style: font),
                          hint: Text('Введите название страны', style: font),
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
              ),
              const SizedBox(height: 20),
              Text('Выберите радиус в км', style: font.copyWith(fontSize: 20)),
              Slider(
                min: 0.0,
                max: 20.0,
                value: radiusKm,
                divisions: 20,
                label: radiusKm.toInt().toString(),
                onChanged: (double v) {
                  setState(() {
                    radiusKm = v;
                  });
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          final city = _cityController.text.trim();
                          if (city.isNotEmpty) {
                            fetchCityCoordinates(city);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Введите название города',
                                  style: font,
                                ),
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Найти места', style: font),
                ),
              ),
              const SizedBox(height: 20),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              // Expanded(
              //   child: places.isEmpty
              //       ? const Center(child: Text('Места не найдены'))
              //       : ListView.builder(
              //           itemCount: places.length,
              //           itemBuilder: (context, index) {
              //             final place = places[index];
              //             final name =
              //                 place['properties']['name'] ?? 'Без названия';
              //             final coords = place['geometry']['coordinates'];
              //             final lon = coords[0];
              //             final lat = coords[1];

              //             return ListTile(
              //               title: Text(name),
              //               subtitle: Text('Широта: $lat, Долгота: $lon'),
              //               trailing: Row(
              //                 mainAxisSize: MainAxisSize.min,
              //                 children: [
              //                   IconButton(
              //                     onPressed: () {
              //                       // открыть в google maps
              //                     },
              //                     icon: Icon(Icons.pin_drop_rounded),
              //                   ),
              //                   const SizedBox(width: 10),
              //                   IconButton(
              //                     onPressed: () {
              //                       // скопировать широту и долготу чтобы вставить в google maps
              //                     },
              //                     icon: Icon(Icons.copy),
              //                   ),
              //                 ],
              //               ),
              //             );
              //           },
              //         ),
              // ),
              Expanded(
                child: places.isEmpty
                    ? Center(child: Text('Места не найдены', style: font))
                    : ListView.builder(
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          final place = places[index];
                          final properties = place['properties'] ?? {};
                          final geometry = place['geometry'] ?? {};
                          final name = properties['name'] ?? 'Без названия';

                          final coords =
                              geometry['coordinates'] as List<dynamic>? ?? [];
                          double lon = 0.0, lat = 0.0;
                          if (coords.length >= 2) {
                            lon = coords[0];
                            lat = coords[1];
                          }

                          return ListTile(
                            title: Text(name, style: font),
                            subtitle: Text(
                              'Широта: $lat, Долгота: $lon',
                              style: font,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Открыть в Google Maps',
                                  onPressed: () => openInMaps(lat, lon),
                                  icon: const Icon(Icons.pin_drop_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Скопировать координаты',
                                  onPressed: () => copyCoordinates(lat, lon),
                                  icon: const Icon(Icons.copy),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
