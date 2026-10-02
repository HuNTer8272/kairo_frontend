/// A playable Spotify item (track or podcast episode) as returned by the
/// Web API's `item` field, reduced to what the UI needs.
class SpotifyTrack {
  const SpotifyTrack({
    required this.uri,
    required this.name,
    required this.artists,
    required this.duration,
    this.albumName,
    this.artworkUrl,
    this.thumbnailUrl,
  });

  final String uri;
  final String name;
  final List<String> artists;
  final Duration duration;
  final String? albumName;

  /// Largest available cover image.
  final String? artworkUrl;

  /// Smallest cover image that is still at least 64 px wide.
  final String? thumbnailUrl;

  String get artistLine => artists.join(', ');

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final isEpisode = json['type'] == 'episode';
    final show = json['show'] as Map<String, dynamic>?;
    final album = json['album'] as Map<String, dynamic>?;

    final artists = isEpisode
        ? [if (show?['name'] is String) show!['name'] as String]
        : [
            for (final artist in (json['artists'] as List? ?? const []))
              if (artist is Map && artist['name'] is String)
                artist['name'] as String,
          ];

    final rawImages = (isEpisode
            ? (json['images'] ?? show?['images'])
            : album?['images']) as List? ??
        const [];
    final images = [
      for (final image in rawImages)
        if (image is Map && image['url'] is String)
          (url: image['url'] as String, width: (image['width'] as num?) ?? 0),
    ]..sort((a, b) => b.width.compareTo(a.width));

    String? thumbnail;
    for (final image in images.reversed) {
      if (image.width >= 64) {
        thumbnail = image.url;
        break;
      }
    }

    return SpotifyTrack(
      uri: json['uri'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      artists: artists,
      duration:
          Duration(milliseconds: (json['duration_ms'] as num?)?.toInt() ?? 0),
      albumName: (isEpisode ? show : album)?['name'] as String?,
      artworkUrl: images.isEmpty ? null : images.first.url,
      thumbnailUrl: thumbnail ?? (images.isEmpty ? null : images.last.url),
    );
  }
}
