import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_crop/image_crop.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<CropState> cropKey = GlobalKey<CropState>();
  File? _file;
  File? _sample;
  File? _lastCropped;
  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
    _file?.delete();
    _sample?.delete();
    _lastCropped?.delete();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                child: _sample == null ? _buildOpeningImage() : _buildCroppingImage(),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Cropping image...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpeningImage() {
    return Center(child: _buildOpenImage());
  }

  Widget _buildCroppingImage() {
    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            children: [
              // Always keep Crop widget in tree to maintain state
              Crop.file(
                _sample!,
                key: cropKey,
              ),
              // Overlay result view when cropped
              if (_lastCropped != null)
                Positioned.fill(
                  child: _buildCroppedImage(),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 20.0),
          alignment: AlignmentDirectional.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              if (_lastCropped == null)
                TextButton(
                  child: Text(
                    'Crop Image',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  onPressed: () => _cropImage(),
                )
              else
                TextButton(
                  child: Text(
                    'Crop Again',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  onPressed: () => _resetCrop(),
                ),
              _buildOpenImage(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCroppedImage() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Cropped Result',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  _lastCropped!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Tap "Crop Again" to adjust the crop area',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Saved: ${_lastCropped!.path.split('/').last}',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenImage() {
    return TextButton(
      child: Text(
        'Open Image',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
      onPressed: () => _openImage(),
    );
  }

  Future<void> _openImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    final file = File(pickedFile?.path ?? '');
    final sample = await ImageCrop.sampleImage(
      file: file,
      preferredSize: context.size?.longestSide.ceil(),
    );

    _sample?.delete();
    _file?.delete();

    setState(() {
      _sample = sample;
      _file = file;
    });
  }

  Future<void> _cropImage() async {
    final scale = cropKey.currentState?.scale;
    final area = cropKey.currentState?.area;
    if (area == null) {
      // cannot crop, widget is not setup
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // scale up to use maximum possible number of pixels
      // this will sample image in higher resolution to make cropped image larger
      final sample = await ImageCrop.sampleImage(
        file: _file!,
        preferredSize: (2000 / scale!).round(),
      );

      final file = await ImageCrop.cropImage(file: sample, area: area);

      sample.delete();

      _lastCropped?.delete();

      setState(() {
        _lastCropped = file;
        _isLoading = false;
      });

      debugPrint('Cropped image saved to: $file');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error cropping image: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetCrop() {
    _lastCropped?.delete();
    setState(() {
      _lastCropped = null;
    });
  }
}
