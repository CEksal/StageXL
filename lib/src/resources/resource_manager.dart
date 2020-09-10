part of stagexl.resources;

class _SoundData {
  String url;
  SoundEngine engine;
}

class ResourceManager {
  final Map<String, ResourceManagerResource> _resourceMap =
      <String, ResourceManagerResource>{};

  final _loaders = <String, _TextureAtlasLoaderFile>{};

  // Key is name
  final _soundDatas = <String, _SoundData>{};

  final _progressEvent = StreamController<num>.broadcast();
  Stream<num> get onProgress => _progressEvent.stream;

  //----------------------------------------------------------------------------

  Future<ResourceManager> load() async {
    var futures = pendingResources.map((r) => r.complete);
    await Future.wait(futures);
    var errors = failedResources.length;
    if (errors > 0) {
      throw StateError('Failed to load $errors resource(s).');
    } else {
      return this;
    }
  }

  void dispose() {
    for (var resource in _resourceMap.values.toList(growable: false)) {
      if (resource.kind == 'BitmapData') {
        removeBitmapData(resource.name, dispose: true);
      } else if (resource.kind == 'TextureAtlas') {
        removeTextureAtlas(resource.name, dispose: true);
      } else if (resource.kind == 'Sound') {
        removeSound(resource.name);
      } else {
        _removeResource(resource.kind, resource.name);
      }
    }
  }

  //----------------------------------------------------------------------------

  List<ResourceManagerResource> get finishedResources =>
      _resourceMap.values.where((r) => r.value != null).toList();

  List<ResourceManagerResource> get pendingResources => _resourceMap.values
      .where((r) => r.value == null && r.error == null)
      .toList();

  List<ResourceManagerResource> get failedResources =>
      _resourceMap.values.where((r) => r.error != null).toList();

  List<ResourceManagerResource> get resources => _resourceMap.values.toList();

  //----------------------------------------------------------------------------

  bool containsBitmapData(String name) {
    return _containsResource('BitmapData', name);
  }

  void addBitmapData(String name, String url, [BitmapDataLoadOptions options]) {
    var loader = BitmapData.load(url, options);
    _addResource('BitmapData', name, url, loader);
  }

  void removeBitmapData(String name, {bool dispose = true}) {
    var resourceManagerResource = _removeResource('BitmapData', name);
    var bitmapData = resourceManagerResource?.value;
    if (bitmapData is BitmapData && dispose) {
      bitmapData.renderTexture.dispose();
    }
  }

  BitmapData getBitmapData(String name) =>
      _getResourceValue('BitmapData', name) as BitmapData;

  //----------------------------------------------------------------------------

  bool containsTextureAtlas(String name) {
    return _containsResource('TextureAtlas', name);
  }

  void addTextureAtlas(String name, String url,
      [TextureAtlasFormat textureAtlasFormat, BitmapDataLoadOptions options]) {

    textureAtlasFormat ??= TextureAtlasFormat.JSONARRAY;

    var tuple = TextureAtlas.load(url, textureAtlasFormat, options);
    _addResource('TextureAtlas', name, url, tuple.atlasFuture);

    _loaders[name] = tuple.loader;
    tuple.atlasFuture
      .then((_) => _loaders.remove(name))
      .catchError((_) => _loaders.remove(name));
  }

  void removeTextureAtlas(String name, {bool dispose = true}) {
    var resourceManagerResource = _removeResource('TextureAtlas', name);
    var textureAtlas = resourceManagerResource?.value;

    if (_loaders.containsKey(name)) {
      print('cancelling loading of $name texture atlas...');
      _loaders[name].cancel();
      _loaders.remove(name);
    }

    if (textureAtlas is TextureAtlas && dispose) {
      for (var textureAtlasFrame in textureAtlas.frames.values) {
        textureAtlasFrame.bitmapData.renderTexture.dispose();
      }
    }
  }

  TextureAtlas getTextureAtlas(String name) {
    return _getResourceValue('TextureAtlas', name) as TextureAtlas;
  }

  //----------------------------------------------------------------------------

  bool containsVideo(String name) {
    return _containsResource('Video', name);
  }

  void addVideo(String name, String url, [VideoLoadOptions options]) {
    var loader = Video.load(url, options);
    _addResource('Video', name, url, loader);
  }

  void removeVideo(String name) {
    _removeResource('Video', name);
  }

  Video getVideo(String name) {
    return _getResourceValue('Video', name) as Video;
  }

  //----------------------------------------------------------------------------

  bool containsSound(String name) {
    return _containsResource('Sound', name);
  }

  void addSound(String name, String url, [SoundLoadOptions options]) {
    var loader = Sound.load(url, options);
    loader.catchError((_) => _soundDatas.remove(name));

    _addResource('Sound', name, url, loader);

    _soundDatas[name] = _SoundData()
      ..url = url
      ..engine = options?.engine ?? Sound.defaultLoadOptions.engine ?? SoundMixer.engine;
  }

  void removeSound(String name) {
    _removeResource('Sound', name);

    if (!_soundDatas.containsKey(name)) return;

    // TODO: Just Web Audio API for now, add support for Audio Element (IE 11)
    final data = _soundDatas[name];
    if (data.engine == SoundEngine.WebAudioApi) {
      WebAudioApiSound.cancel(data.url);
    }

    _soundDatas.remove(name);
  }

  Sound getSound(String name) {
    return _getResourceValue('Sound', name) as Sound;
  }

  //----------------------------------------------------------------------------

  bool containsSoundSprite(String name) {
    return _containsResource('SoundSprite', name);
  }

  void addSoundSprite(String name, String url, [SoundLoadOptions options]) {
    var loader = SoundSprite.load(url, options);
    _addResource('SoundSprite', name, url, loader);
  }

  void removeSoundSprite(String name) {
    _removeResource('SoundSprite', name);
  }

  SoundSprite getSoundSprite(String name) {
    return _getResourceValue('SoundSprite', name) as SoundSprite;
  }

  //----------------------------------------------------------------------------

  bool containsText(String name) {
    return _containsResource('Text', name);
  }

  void addText(String name, String text) {
    _addResource('Text', name, '', Future.value(text));
  }

  void removeText(String name) {
    _removeResource('Text', name);
  }

  String getText(String name) {
    return _getResourceValue('Text', name) as String;
  }

  //----------------------------------------------------------------------------

  bool containsTextFile(String name) {
    return _containsResource('TextFile', name);
  }

  void addTextFile(String name, String url) {
    var loader =
        HttpRequest.getString(getUrlHash(url)).then((text) => text, onError: (error) {
      throw StateError('Failed to load text file.');
    });
    _addResource('TextFile', name, url, loader);
  }

  void removeTextFile(String name) {
    _removeResource('TextFile', name);
  }

  String getTextFile(String name) {
    return _getResourceValue('TextFile', name) as String;
  }

  //----------------------------------------------------------------------------

  bool containsCustomObject(String name) {
    return _containsResource('CustomObject', name);
  }

  void addCustomObject(String name, Future loader) {
    _addResource('CustomObject', name, '', loader);
  }

  void removeCustomObject(String name) {
    _removeResource('CustomObject', name);
  }

  dynamic getCustomObject(String name) {
    return _getResourceValue('CustomObject', name);
  }

  //----------------------------------------------------------------------------

  bool _containsResource(String kind, String name) {
    var key = '$kind.$name';
    return _resourceMap.containsKey(key);
  }

  ResourceManagerResource _removeResource(String kind, String name) {
    var key = '$kind.$name';
    return _resourceMap.remove(key);
  }

  void _addResource(String kind, String name, String url, Future loader) {
    var key = '$kind.$name';
    var resource = ResourceManagerResource(kind, name, url, loader);

    if (_resourceMap.containsKey(key)) {
      throw StateError(
          "ResourceManager already contains a resource called '$name'");
    } else {
      _resourceMap[key] = resource;
    }

    resource.complete.then((_) {
      var finished = finishedResources.length;
      var progress = finished / _resourceMap.length;
      _progressEvent.add(progress);
    });
  }

  dynamic _getResourceValue(String kind, String name) {
    var key = '$kind.$name';
    var resource = _resourceMap[key];
    if (resource == null) {
      throw StateError("Resource '$name' does not exist.");
    } else if (resource.value != null) {
      return resource.value;
    } else if (resource.error != null) {
      throw resource.error;
    } else {
      throw StateError("Resource '$name' has not finished loading yet.");
    }
  }
}
