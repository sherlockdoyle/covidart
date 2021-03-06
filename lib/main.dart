import 'dart:html' as html; // currently web only
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:searchable_dropdown/searchable_dropdown.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:table_sticky_headers/table_sticky_headers.dart';

import 'covidAPI.dart';

void main() => runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: CovidApp()));

class CovidApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<_DataWidgetState>();
    return Scaffold(
      appBar: AppBar(
        title: Text('CoviDart'),
        actions: [
          IconButton(
            icon: Icon(Icons.table_chart),
            tooltip: 'Tabular view',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TabularView(key.currentState.selected),
                )),
          ),
          IconButton(
            icon: Icon(Icons.show_chart),
            tooltip: 'Predictions',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PredictionView(key.currentState.selected),
                )),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: 'Just a sample COVID-19 tracker Flutter app. Find the code at '),
                  TextSpan(
                    text: 'https://github.com/sherlockdoyle/covidart',
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const loc = 'https://github.com/sherlockdoyle/covidart';
                        // if (await url.canLaunch(loc)) url.launch(loc);  // TODO: Why no work?
                        html.window.open(loc, 'covidart');
                      },
                  ),
                  TextSpan(text: '.'),
                ],
                style: TextStyle(color: Colors.white),
              ),
            ),
            padding: EdgeInsets.all(10),
          ),
          Expanded(child: Center(child: DataWidget(key))),
        ],
      ),
    );
  }
}

class DataWidget extends StatefulWidget {
  DataWidget(Key key) : super(key: key);
  @override
  State<DataWidget> createState() => _DataWidgetState();
}

class _DataWidgetState extends State<DataWidget> {
  Future<List<Country>> countries;
  Country selected;
  Future<CountryCase> data;

  @override
  void initState() {
    super.initState();
    countries = CovidAPI.getCountries()
      ..then((value) {
        final localCountryCode = Localizations.localeOf(context).countryCode;
        final localCountryIdx = value.indexWhere((element) => element.iso2 == localCountryCode);
        if (localCountryIdx >= 0) {
          selected = value[localCountryIdx];
          updateCountryData();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<List<Country>>(
          future: countries,
          builder: (context, snapshot) {
            if (snapshot.hasData)
              return SearchableDropdown<Country>(
                items: snapshot.data
                    .map((e) => DropdownMenuItem<Country>(
                          value: e,
                          child: Text(e.toString()),
                        ))
                    .toList(),
                onChanged: (e) {
                  selected = e;
                  updateCountryData();
                },
                hint: 'Select country',
                searchHint: 'Search for country',
                value: selected,
              );
            else if (snapshot.hasError) return Text('${snapshot.error}', style: TextStyle(color: Colors.red));
            return CircularProgressIndicator();
          },
        ),
        SizedBox(height: 10),
        FutureBuilder<CountryCase>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.hasData)
              return ChartWidget(snapshot.data);
            else if (snapshot.hasError) return Text('${snapshot.error}', style: TextStyle(color: Colors.red));
            return CircularProgressIndicator();
          },
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  void updateCountryData() => data = CovidAPI.getCasesByCountry(selected)..then((value) => setState(() {}));
}

class ChartWidget extends StatelessWidget {
  final CountryCase data;
  final int numPredictions;
  const ChartWidget(this.data, [this.numPredictions = 0]);

  @override
  Widget build(BuildContext context) {
    final series = <charts.Series<Case, DateTime>>[
      charts.Series(
        id: 'Confirmed',
        data: data.cases,
        domainFn: (datum, index) => datum.date,
        measureFn: (datum, index) => datum.confirmed,
        colorFn: (datum, index) => charts.MaterialPalette.blue.shadeDefault,
      ),
      charts.Series(
        id: 'Deaths',
        data: data.cases,
        domainFn: (datum, index) => datum.date,
        measureFn: (datum, index) => datum.deaths,
        colorFn: (datum, index) => charts.MaterialPalette.red.shadeDefault,
      ),
      charts.Series(
        id: 'Recovered',
        data: data.cases,
        domainFn: (datum, index) => datum.date,
        measureFn: (datum, index) => datum.recovered,
        colorFn: (datum, index) => charts.MaterialPalette.green.shadeDefault,
      ),
      charts.Series(
        id: 'Active',
        data: data.cases,
        domainFn: (datum, index) => datum.date,
        measureFn: (datum, index) => datum.active,
        colorFn: (datum, index) => charts.MaterialPalette.yellow.shadeDefault,
      ),
    ];
    if (numPredictions > 0) {
      int max = data.cases.map((e) => e.confirmed).reduce(math.max);
      series.add(charts.Series(
        id: 'Prediction',
        data: [
          Case(
            date: data.cases[data.cases.length - 1 - numPredictions].date,
            confirmed: max,
          ),
          Case(
            date: data.cases[data.cases.length - 1].date,
            confirmed: max,
          ),
        ],
        domainFn: (datum, index) => datum.date,
        measureFn: (datum, index) => datum.confirmed,
        colorFn: (datum, index) => charts.MaterialPalette.purple.shadeDefault,
      )..setAttribute(charts.rendererIdKey, 'prediction'));
    }
    return Container(
      height: 450,
      padding: EdgeInsets.fromLTRB(10, 0, 0, 10),
      child: charts.TimeSeriesChart(
        series,
        behaviors: [
          charts.SeriesLegend(
            desiredMaxColumns: (MediaQuery.of(context).size.width + 25) ~/ 100, // Legend-ary hack for wrapping
            outsideJustification: charts.OutsideJustification.start,
          ),
        ],
        animate: true,
        customSeriesRenderers: [
          charts.LineRendererConfig(
            customRendererId: 'prediction',
            includeLine: false,
            includeArea: true,
            areaOpacity: 0.25,
          ),
        ],
        primaryMeasureAxis: charts.NumericAxisSpec(
          renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(
              color: charts.MaterialPalette.white,
            ),
            axisLineStyle: charts.LineStyleSpec(
              color: charts.MaterialPalette.gray.shadeDefault,
            ),
          ),
        ),
        domainAxis: charts.DateTimeAxisSpec(
          renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(
              color: charts.MaterialPalette.white,
            ),
          ),
        ),
      ),
    );
  }
}

class TabularView extends StatelessWidget {
  Future<CountryCase> cases;
  final int numPredictions;
  Case predicted;
  TabularView(Country country, [this.numPredictions = 1]) {
    cases = CovidAPI.getCasesByCountry(country);
    try {
      final predictedCases = CovidAPI.getPredictionsForCountry(country).cases;
      predicted = predictedCases[predictedCases.length - 1];
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cases Till Date')),
      body: FutureBuilder<CountryCase>(
        // TODO: Need to center this
        future: cases,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final numRows = snapshot.data.cases.length;
            return StickyHeadersTable(
              rowsLength: numRows,
              columnsLength: 4,
              rowsTitleBuilder: (i) {
                if (i == 0)
                  return predicted == null
                      ? Text('Failed', style: TextStyle(color: Colors.red))
                      : Text(
                          DateFormat.yMMMd().format(predicted.date) + '\n(Predicted)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade200,
                          ),
                        );
                return Text(
                  DateFormat.yMMMd().format(snapshot.data.cases[numRows - i].date),
                  style: TextStyle(fontWeight: FontWeight.bold),
                );
              },
              columnsTitleBuilder: (j) => Text(
                ['Deaths', 'Recovered', 'Active', 'Confirmed'][j],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              contentCellBuilder: (j, i) {
                if (i == 0)
                  return predicted == null
                      ? Text(['to', 'make', 'predictions', '☹'][j], style: TextStyle(color: Colors.red))
                      : Text(
                          [predicted.deaths, predicted.recovered, predicted.active, predicted.confirmed][j].toString(),
                          style: TextStyle(color: Colors.purple.shade200),
                        );
                final casei = snapshot.data.cases[numRows - i];
                return Text([casei.deaths, casei.recovered, casei.active, casei.confirmed][j].toString());
              },
              legendCell: Text(snapshot.data.country.toString()),
            );
          } else if (snapshot.hasError) return Text('${snapshot.error}', style: TextStyle(color: Colors.red));
          return CircularProgressIndicator();
        },
      ),
    );
  }
}

class PredictionView extends StatelessWidget {
  final Country country;
  CountryCase cases;
  Case extra, newest;
  PredictionView(this.country) {
    try {
      cases = CovidAPI.getPredictionsForCountry(country);
      extra = cases.getIncrease(cases.cases.length - 1);
      newest = cases.cases[cases.cases.length - 1];
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Predictions')),
      body: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'Predictions for '),
                    TextSpan(
                      text: country.toString(),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                  style: Theme.of(context).textTheme.bodyText1.copyWith(fontSize: 16),
                ),
              ),
            ),
            cases == null
                ? () {
                    List<Widget> children = [
                      Text(
                        'Failed to make predictions ☹',
                        style: TextStyle(color: Colors.red),
                      ),
                    ];
                    if (country.iso2 == 'GB') {
                      children.add(SizedBox(height: 25));
                      children.add(Text(
                        'You seem to be trying to check the predictions for $country. This is not possible because of the absence of data.',
                        style: Theme.of(context).textTheme.bodyText1,
                        textAlign: TextAlign.center,
                      ));
                      children.add(RaisedButton(
                        child: Text('Read this'),
                        onPressed: () => html.window.open(
                            'https://www.theguardian.com/world/2020/jun/18/health-experts-criticise-uk-failure-track-recovered-covid-19-cases',
                            'Problem'),
                      ));
                    }
                    return Column(children: children);
                  }() //https://www.theguardian.com/world/2020/jun/18/health-experts-criticise-uk-failure-track-recovered-covid-19-cases
                : Column(
                    children: [
                      ChartWidget(cases, 1),
                      Container(
                        padding: EdgeInsets.all(10),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: 'Expected to have '),
                              TextSpan(
                                text: extra.deaths.abs().toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' ${extra.deaths < 0 ? "fewer" : "new"} deaths, '),
                              TextSpan(
                                text: extra.recovered.abs().toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' ${extra.recovered < 0 ? "fewer" : "new"} recoveries, and '),
                              TextSpan(
                                text: extra.active.abs().toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                  text:
                                      ' ${extra.active < 0 ? "fewer" : "new"} active cases for ${DateFormat.yMMMd().format(extra.date)}. This will lead to a total of '),
                              TextSpan(
                                text: newest.deaths.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' deaths, '),
                              TextSpan(
                                text: newest.recovered.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' recoveries, '),
                              TextSpan(
                                text: newest.active.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' active cases, and a total of '),
                              TextSpan(
                                text: newest.confirmed.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                  text:
                                      ' cases. Note that this is just a mathematical estimation and might vary greatly from the actual numbers.'),
                            ],
                            style: Theme.of(context).textTheme.bodyText1.copyWith(height: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
