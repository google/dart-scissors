part of scissors.template_extractor;

class _AssetBasedSource extends Source {
  final Asset asset;
  final String stringContent;

  _AssetBasedSource(this.asset, this.stringContent);

  @override
  TimestampedData<String> get contents =>
      new TimestampedData<String>(modificationStamp, stringContent);

  @override
  String get encoding => 'utf-8';

  @override
  bool exists() => true;

  @override
  String get fullName => asset.id.path;

  @override
  bool get isInSystemLibrary => false;

  @override
  int get modificationStamp => 0;

  @override
  Uri resolveRelativeUri(Uri relativeUri) => relativeUri;

  @override
  String get shortName => asset.id.path;

  @override
  Uri get uri => new Uri(scheme: 'package', host: asset.id.package, path: asset.id.path);

  @override
  UriKind get uriKind => UriKind.PACKAGE_URI;
}
